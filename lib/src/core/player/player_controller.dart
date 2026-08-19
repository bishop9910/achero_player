import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../library/music_library.dart';
import '../lyrics/lrc_parser.dart';
import '../models/track.dart';
import '../platform/platform_filesystem.dart';
import '../settings/app_settings.dart';
import '../settings/settings_controller.dart';

/// 播放控制器：把音频引擎、队列、歌词与播放设置编排在一起。
///
/// 它是 UI 与音频引擎之间的唯一桥梁，对外暴露简洁的命令（`playPause`、
/// `next`、`seek`…）与响应式状态（当前曲目、进度、歌词）。
class PlayerController extends ChangeNotifier {
  PlayerController({
    required AudioEngine engine,
    required SettingsController settings,
    required PlatformFileSystem fs,
    MusicLibrary? library,
  })  : _engine = engine,
        _settings = settings,
        _fs = fs,
        _library = library,
        _lrcParser = const LrcParser() {
    _shuffle = settings.settings.playback.shuffle;
    _repeatMode = settings.settings.playback.repeatMode;
    _engine.statusStream.listen(_onStatus, onError: _onEngineStreamError);
    _engine.positionStream.listen(_onPosition, onError: _onEngineStreamError);
    _engine.durationStream.listen(_onDuration, onError: _onEngineStreamError);
    _engine.completionStream.listen((_) => _onCompleted(),
        onError: _onEngineStreamError);
    _engine.errorStream.listen(_onEngineError, onError: _onEngineStreamError);
    _engine.setVolume(settings.settings.playback.volume);
  }

  final AudioEngine _engine;
  final SettingsController _settings;
  final PlatformFileSystem _fs;
  final MusicLibrary? _library;
  final LrcParser _lrcParser;
  final Random _random = Random();

  /// 队列原始顺序（未洗牌）。
  List<Track> _baseQueue = const [];

  /// 当前实际播放顺序（洗牌后可能与 [_baseQueue] 不同）。
  final List<Track> _queue = [];
  int _index = -1;

  PlaybackStatus _status = PlaybackStatus.idle;
  Duration _position = Duration.zero;
  Duration? _duration;
  LyricDocument? _lyrics;

  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  double _volume = 1.0;

  /// 加载代次：每次 `_startCurrent` 递增，用于丢弃「已被更新的切换取代」的
  /// 过期加载，避免快速切歌时多个异步 load/play 交错导致状态错乱。
  int _loadGeneration = 0;

  /// 引擎是否已确认加载成功（收到有效时长）。
  ///
  /// 加载阶段 media_kit 会把 libmpv 的非致命 error 级日志转发到 errorStream，
  /// 需据此区分「真错误」与「随后仍能正常播放的日志噪音」。
  bool _mediaLoaded = false;

  /// 加载阶段暂存的引擎错误，延迟判定是否按致命错误处理。
  String? _pendingEngineError;
  Timer? _pendingErrorTimer;

  /// 播放错误提示。UI 监听它弹出提示，弹出后由 UI 置回 null。
  final ValueNotifier<String?> playbackError = ValueNotifier(null);

  // ---------------------------------------------------------------------------
  // 只读状态
  // ---------------------------------------------------------------------------

  PlaybackStatus get status => _status;
  Duration get position => _position;
  Duration? get duration => _duration;
  LyricDocument? get lyrics => _lyrics;

  bool get shuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;
  double get volume => _volume;

  Track? get currentTrack =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;

  List<Track> get queue => List.unmodifiable(_queue);

  bool get hasTrack => currentTrack != null;
  bool get isPlaying => _status.isPlaying;

  /// 播放进度（0.0 ~ 1.0），时长未知时为 0。
  double get progress {
    final d = _duration;
    if (d == null || d.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // 命令
  // ---------------------------------------------------------------------------

  /// 用给定队列开始播放，从 [startIndex] 处开始。
  Future<void> playQueue(List<Track> queue, {int startIndex = 0}) async {
    if (queue.isEmpty) return;
    _baseQueue = List<Track>.of(queue);
    _rebuildQueue(startIndex: startIndex.clamp(0, queue.length - 1));
    await _startCurrent();
  }

  /// 播放单首曲目（清空队列）。
  Future<void> playTrack(Track track) => playQueue([track]);

  Future<void> togglePlayPause() async {
    if (!hasTrack) return;
    switch (_status) {
      case PlaybackStatus.playing:
        await _engine.pause();
        break;
      case PlaybackStatus.paused:
        await _engine.resume();
        break;
      case PlaybackStatus.loading:
        break; // 加载中，忽略
      case PlaybackStatus.idle:
      case PlaybackStatus.completed:
      case PlaybackStatus.error:
        // 出错/空闲/已结束时，重新加载并播放「当前」曲目，而不是恢复旧来源。
        await _startCurrent();
        break;
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _index = (_index + 1) % _queue.length;
    await _startCurrent();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    // 播放超过 3 秒时回退到曲目开头，否则切上一首。
    if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    _index = (_index - 1 + _queue.length) % _queue.length;
    await _startCurrent();
  }

  Future<void> seek(Duration position) => _engine.seek(position);

  /// 设置音量（0.0 ~ 1.0）。
  ///
  /// [persist] 为 false 时仅实时调整引擎、不落盘也不通知（用于拖动音量条
  /// 期间的高频回调，避免每帧都写盘 + 重建页面）；拖动结束再以默认值提交。
  Future<void> setVolume(double volume, {bool persist = true}) async {
    _volume = volume.clamp(0.0, 1.0);
    await _engine.setVolume(_volume);
    if (persist) {
      _settings
          .updatePlayback(_settings.settings.playback.copyWith(volume: _volume));
      notifyListeners();
    }
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _settings
        .updatePlayback(_settings.settings.playback.copyWith(shuffle: _shuffle));
    final currentId = currentTrack?.id;
    final baseIndex =
        currentId == null ? 0 : _baseQueue.indexWhere((t) => t.id == currentId);
    _rebuildQueue(startIndex: baseIndex < 0 ? 0 : baseIndex);
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode =
        RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    _settings.updatePlayback(
        _settings.settings.playback.copyWith(repeatMode: _repeatMode));
    notifyListeners();
  }

  /// 重新加载当前曲目的歌词（异步读取 .lrc 文件并解析）。
  Future<void> refreshLyrics() async {
    final generation = _loadGeneration;
    final track = currentTrack;
    if (track == null) {
      _lyrics = null;
      notifyListeners();
      return;
    }
    LyricDocument? doc;
    try {
      doc = await _loadLyricsFor(track);
    } catch (_) {
      doc = null; // 歌词读取失败不应影响播放。
    }
    if (generation != _loadGeneration) return; // 期间已切歌，丢弃过期歌词
    _lyrics = doc;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  void _rebuildQueue({required int startIndex}) {
    _queue.clear();
    if (_baseQueue.isEmpty) return;
    if (_shuffle) {
      final current = _baseQueue[startIndex];
      final rest = List<Track>.from(_baseQueue)..removeAt(startIndex);
      rest.shuffle(_random);
      _queue
        ..add(current)
        ..addAll(rest);
      _index = 0;
    } else {
      _queue.addAll(_baseQueue);
      _index = startIndex;
    }
  }

  /// 已下载的本地文件缺失/损坏时：删除本地文件并回退到服务器流。
  /// 成功返回 true（曲目已被替换为在线来源），否则 false。
  Future<bool> _fallbackToRemote() async {
    final track = currentTrack;
    if (track == null) return false;
    final source = track.source;
    final remoteUrl = track.remoteUrl;
    if (source is! FileTrackSource) return false;
    if (remoteUrl == null || remoteUrl.isEmpty) return false;

    // 删除缺失/损坏的本地文件；封面会由 CoverArt 回退到网络地址。
    try {
      await _fs.deleteFile(source.path);
    } catch (_) {
      // 删除失败也不阻塞回退。
    }

    final fallback = track.copyWith(source: UrlTrackSource(remoteUrl));
    _replaceInQueues(track.id, fallback);
    _library?.upsertTrack(fallback);
    return true;
  }

  void _replaceInQueues(String id, Track replacement) {
    for (var i = 0; i < _queue.length; i++) {
      if (_queue[i].id == id) _queue[i] = replacement;
    }
    for (var i = 0; i < _baseQueue.length; i++) {
      if (_baseQueue[i].id == id) _baseQueue[i] = replacement;
    }
  }

  Future<void> _startCurrent() async {
    final track = currentTrack;
    if (track == null) return;

    final src = switch (track.source) {
      FileTrackSource() => 'file',
      BytesTrackSource() => 'bytes',
      UrlTrackSource() => 'url',
    };
    debugPrint('[AcheroPlayer] 准备播放「${track.title}」 ext="${track.extension}" src=$src '
        'path=${track.source.displayPath} lrc=${track.lyricsPath != null} '
        'platform=$defaultTargetPlatform web=$kIsWeb');

    // 本次加载的代次；期间若再次切歌，代次会变化，本函数后续步骤作废。
    final generation = ++_loadGeneration;

    _mediaLoaded = false;
    _pendingErrorTimer?.cancel();
    _pendingErrorTimer = null;
    _pendingEngineError = null;

    _position = Duration.zero;
    _duration = track.duration;
    _lyrics = null;
    _status = PlaybackStatus.loading;
    notifyListeners();

    try {
      // 切歌前先停止当前播放，避免新源加载失败时旧曲目还在响。
      await _engine.stop();
      if (generation != _loadGeneration) return;

      // 本地文件预检：文件不存在时回退到服务器流（若有 remoteUrl），否则报错。
      final source = track.source;
      if (source is FileTrackSource) {
        final exists = await _fs.exists(source.path);
        if (generation != _loadGeneration) return;
        if (!exists) {
          if (await _fallbackToRemote()) {
            await _startCurrent();
            return;
          }
          _status = PlaybackStatus.error;
          notifyListeners();
          playbackError.value = '无法播放「${track.title}」：文件不存在或已被移动';
          return;
        }
      }

      await _engine.load(track);
      if (generation != _loadGeneration) return; // 已被更新的切换取代
      await _engine.play();
      if (generation != _loadGeneration) return;
      unawaited(refreshLyrics());
    } catch (error) {
      if (generation == _loadGeneration) {
        // 本地文件损坏时回退到服务器流。
        if (track.source is FileTrackSource &&
            track.remoteUrl != null &&
            track.remoteUrl!.isNotEmpty &&
            await _fallbackToRemote()) {
          await _startCurrent();
          return;
        }
        _status = PlaybackStatus.error;
        notifyListeners();
        playbackError.value = _playbackErrorMessage(track, detail: error.toString());
        // 加载失败兜底：确保旧播放已停止。
        try {
          await _engine.stop();
        } catch (_) {
          // 忽略停止失败。
        }
      }
    }
  }

  String _playbackErrorMessage(Track track, {String? detail}) {
    return '无法播放「${track.title}」：${_classifyError(track, detail)}';
  }

  /// 把引擎底层错误归类为人类可读的原因（网络 / 文件损坏 / 格式 / 缺失等）。
  String _classifyError(Track track, String? detail) {
    final d = (detail ?? '').trim();
    if (d.isNotEmpty) {
      final lower = d.toLowerCase();
      if (_containsAny(lower, [
        'network', 'timeout', 'connection', 'http', 'socket', 'resolve',
        'refused', 'unreachable', 'dns', '404', '403', '500', '502', '503',
      ])) {
        return '网络连接失败：$d';
      }
      if (_containsAny(lower,
          ['corrupt', 'invalid', 'damaged', 'truncated', 'broken'])) {
        return '文件已损坏：$d';
      }
      if (_containsAny(lower,
          ['decode', 'codec', 'demux', 'unsupported', 'format'])) {
        return '格式无法解码：$d';
      }
      if (_containsAny(lower, [
        'not found', 'no such', 'unable to load', 'failed to open', 'missing',
      ])) {
        return '文件不存在或无法读取：$d';
      }
      return d;
    }
    final ext = track.extension.toLowerCase();
    if (ext.isNotEmpty) return '不支持或无法解码 .$ext 格式';
    return '未知原因';
  }

  bool _containsAny(String lower, List<String> keys) => keys.any(lower.contains);

  Future<void> _onCompleted() async {
    if (_repeatMode == RepeatMode.one) {
      // 单曲循环：重新播放当前来源（setSource + resume 会从 0 开始）。
      await _engine.play();
      return;
    }
    if (_repeatMode == RepeatMode.off) {
      // 不循环：播放完当前这一首就停，不自动切下一首。
      _status = PlaybackStatus.completed;
      notifyListeners();
      return;
    }
    // 列表循环（RepeatMode.all）：播完自动切下一首，最后回绕到第一首。
    await next();
  }

  Future<LyricDocument?> _loadLyricsFor(Track track) async {
    // 1) 内联歌词：RPC / 网络来源可能在 metadata 中直接携带 LRC 文本。
    final inline = track.metadata['lyrics'];
    if (inline is String && inline.trim().isNotEmpty) {
      return _parseLyrics(inline);
    }

    // 2) 本地同名 .lrc 文件。
    final path = track.lyricsPath;
    if (path == null) return null;
    final bytes = await _fs.readBytes(path);
    if (bytes == null) return null;
    return _parseLyrics(_decodeLyricsBytes(bytes));
  }

  /// 容错解码歌词字节流。
  ///
  /// 老式中文 `.lrc` 文件常为 GBK 编码而非 UTF-8，直接用 `utf8.decode` 会抛
  /// `FormatException: Unexpected extension byte`，且异常会顺着异步链逃逸成
  /// 「Another exception was thrown」。这里按 UTF-8 → GBK → 容错 UTF-8 的顺序
  /// 回退，保证任何编码都不会把异常抛出去。
  String _decodeLyricsBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      try {
        return gbk.decode(bytes);
      } catch (_) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
  }

  LyricDocument? _parseLyrics(String raw) {
    try {
      final doc = _lrcParser.parse(raw);
      return doc.isEmpty ? null : doc;
    } catch (_) {
      return null;
    }
  }

  void _onStatus(PlaybackStatus status) {
    _status = status;
    notifyListeners();
  }

  void _onPosition(Duration position) {
    _position = position;
    notifyListeners();
  }

  void _onDuration(Duration duration) {
    _duration = duration;
    if (duration > Duration.zero) _mediaLoaded = true;
    notifyListeners();
  }

  /// 事件通道偶发解码失败（如 Windows 引擎在事件流里抛 `FormatException`）时
  /// 吞掉，避免它成为未处理异常刷屏；单个坏事件不应影响播放状态机。
  void _onEngineStreamError(Object error) {
    // 静默忽略。
  }

  /// 播放出错（异步解码失败等）时：标记错误状态并弹出提示。
  ///
  /// media_kit 的 `errorStream` 由 libmpv 的 error 级日志驱动，打开/探测阶段
  /// 常出现非致命错误（如 ffmpeg 探测辅助流），随后仍能正常播放。因此加载阶段
  /// 不立即判死，而是短暂延迟，以「引擎是否已确认加载成功（收到有效时长）」判定：
  /// 已加载成功则忽略该错误，否则才按致命错误处理。
  void _onEngineError(String message) {
    debugPrint('[AcheroPlayer] 引擎错误：$message');
    if (_status == PlaybackStatus.error) return;

    if (_status == PlaybackStatus.loading) {
      _pendingEngineError = message;
      _pendingErrorTimer?.cancel();
      _pendingErrorTimer = Timer(const Duration(milliseconds: 1500), () async {
        _pendingErrorTimer = null;
        final pending = _pendingEngineError;
        _pendingEngineError = null;
        if (pending == null) return;
        // 已真正加载成功：此前的 error 只是日志噪音，忽略。
        if (_mediaLoaded) return;
        // 加载失败：已下载的本地文件（损坏）则回退到服务器流重试。
        if (await _fallbackToRemote()) {
          await _startCurrent();
          return;
        }
        _status = PlaybackStatus.error;
        notifyListeners();
        final track = currentTrack;
        if (track != null) {
          playbackError.value = _playbackErrorMessage(track, detail: pending);
        }
      });
      return;
    }

    _status = PlaybackStatus.error;
    notifyListeners();
    final track = currentTrack;
    if (track != null) {
      playbackError.value = _playbackErrorMessage(track, detail: message);
    }
  }

  @override
  void dispose() {
    _pendingErrorTimer?.cancel();
    _engine.dispose();
    super.dispose();
  }
}
