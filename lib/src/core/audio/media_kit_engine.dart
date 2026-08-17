import 'package:media_kit/media_kit.dart' hide Track;

import '../models/track.dart';
import 'audio_engine.dart';

/// 基于 [media_kit]（libmpv / ffmpeg）的音频引擎实现。
///
/// 相比 audioplayers（Windows 上走 Media Foundation，不支持 OGG/Opus），
/// media_kit 在各平台都用 ffmpeg 解码：Windows / Linux / Android 上原生支持
/// OGG/Vorbis/Opus/FLAC 等格式；Web 端回退到浏览器 HTML5 音频。
///
/// 关键：`load` 只生成 [Media]、不触发原生调用；`play` 用 `open(media, play: true)`
/// 原子地「设置来源并播放」；`resume` 只恢复当前来源（用于暂停后的继续）。
/// 二者分离，避免快速切歌时「设置来源」与「播放」交错、或把旧来源恢复成播放。
class MediaKitEngine implements AudioEngine {
  MediaKitEngine() {
    _player = Player();
  }

  late final Player _player;

  /// 待播放的媒体（[load] 时生成，[play] 时打开）。
  Media? _prepared;

  @override
  Stream<PlaybackStatus> get statusStream => _player.stream.playing
      .map((playing) => playing ? PlaybackStatus.playing : PlaybackStatus.paused);

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<void> get completionStream =>
      _player.stream.completed.where((completed) => completed).map((_) {});

  @override
  Stream<String> get errorStream => _player.stream.error;

  @override
  Future<void> load(Track track) async {
    _prepared = switch (track.source) {
      FileTrackSource(:final path) => Media(Uri.file(path).toString()),
      BytesTrackSource(:final bytes, :final mimeType) =>
        Media(Uri.dataFromBytes(bytes, mimeType: mimeType).toString()),
      UrlTrackSource(:final url) => Media(url),
    };
  }

  @override
  Future<void> play() async {
    final media = _prepared;
    if (media == null) return;
    await _player.open(media, play: true);
  }

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // 尚无媒体时忽略。
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0) * 100.0);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<Duration> get position async => _player.state.position;

  @override
  Future<Duration?> get duration async {
    final d = _player.state.duration;
    return d > Duration.zero ? d : null;
  }

  @override
  Future<void> dispose() => _player.dispose();
}
