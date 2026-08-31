import 'package:audio_service/audio_service.dart';

import '../models/track.dart';
import '../player/player_controller.dart';
import 'audio_engine.dart';

/// 把 [PlayerController] 桥接成 audio_service 的 [BaseAudioHandler]。
///
/// 供安卓后台播放使用：前台服务 + 通知栏播放控制 + 耳机/锁屏按键 + 音频焦点。
///
/// 播放逻辑**全部复用主 isolate 的 [PlayerController]**（队列/随机/循环/歌词），
/// 本类只负责把播放状态映射成 audio_service 的 `PlaybackState`/`MediaItem`，
/// 并把通知栏/锁屏发来的命令转发回播放控制器。这样不会复制第二套队列逻辑。
class AcheroAudioHandler extends BaseAudioHandler {
  AcheroAudioHandler(this.player) {
    player.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  final PlayerController player;

  Track? _lastTrack;
  bool _lastPlaying = false;
  Duration _lastPublishedPosition = Duration.zero;

  @override
  Future<void> play() async {
    if (player.hasTrack && !player.isPlaying) {
      await player.togglePlayPause();
    }
  }

  @override
  Future<void> pause() async {
    if (player.isPlaying) {
      await player.togglePlayPause();
    }
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.next();

  @override
  Future<void> skipToPrevious() => player.previous();

  @override
  Future<void> stop() async {
    if (player.isPlaying) {
      await player.togglePlayPause();
    }
    await super.stop();
  }

  void _onPlayerChanged() {
    final track = player.currentTrack;
    final playing = player.isPlaying;
    final position = player.position;

    final trackChanged = !identical(track, _lastTrack);
    final playingChanged = playing != _lastPlaying;
    // 只有「跳跃式」位置变化（如 seek）才刷新通知进度，避免正常播放的
    // 高频 position 更新反复推送给系统通知栏。
    final seekJump =
        (position - _lastPublishedPosition).abs() > const Duration(seconds: 2);

    _lastTrack = track;
    _lastPlaying = playing;

    if (trackChanged) {
      mediaItem.add(track == null ? null : _mediaItemFor(track));
      _lastPublishedPosition = Duration.zero;
    }

    if (trackChanged || playingChanged || seekJump) {
      _lastPublishedPosition = position;
      playbackState.add(_playbackStateFor());
    }
  }

  PlaybackState _playbackStateFor() {
    final playing = player.isPlaying;
    return PlaybackState(
      processingState: _processingState(),
      playing: playing,
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      systemActions: const {MediaAction.seek},
      updatePosition: player.position,
    );
  }

  AudioProcessingState _processingState() {
    if (!player.hasTrack) return AudioProcessingState.idle;
    switch (player.status) {
      case PlaybackStatus.loading:
        return AudioProcessingState.loading;
      case PlaybackStatus.completed:
        return AudioProcessingState.completed;
      case PlaybackStatus.error:
        return AudioProcessingState.error;
      default:
        return AudioProcessingState.ready;
    }
  }

  MediaItem _mediaItemFor(Track track) {
    Uri? artUri;
    final coverPath = track.coverArtPath;
    final coverUrl = track.coverArtUrl;
    if (coverPath != null && coverPath.isNotEmpty) {
      artUri = Uri.file(coverPath);
    } else if (coverUrl != null && coverUrl.isNotEmpty) {
      artUri = Uri.parse(coverUrl);
    }
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      artUri: artUri,
    );
  }
}
