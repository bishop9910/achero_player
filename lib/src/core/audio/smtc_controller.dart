import 'dart:async';

import 'package:smtc_windows/smtc_windows.dart';

import '../models/track.dart';
import '../player/player_controller.dart';

/// Windows SMTC（System Media Transport Controls）控制器。
///
/// 把 [PlayerController] 的播放状态同步到 Windows 系统媒体条（音量弹层 /
/// 锁屏的「正在播放」），并把系统媒体按键（播放/暂停/上一首/下一首）转发回播放器。
/// Linux 端走 `audio_service_mpris`，不经过本类。
class WindowsSmcController {
  WindowsSmcController(this.player) {
    player.addListener(_onPlayerChanged);
    _buttonSub = _smtc.buttonPressStream.listen(_onButton);
    _onPlayerChanged();
  }

  /// 初始化 smtc_windows 的 Rust 运行时，须在创建本控制器前调用一次。
  static Future<void> initialize() => SMTCWindows.initialize();

  final PlayerController player;
  final SMTCWindows _smtc = SMTCWindows();

  StreamSubscription<PressedButton>? _buttonSub;
  Track? _lastTrack;
  bool _lastPlaying = false;
  Duration _lastPosition = Duration.zero;

  void _onButton(PressedButton button) {
    switch (button) {
      case PressedButton.play:
        if (!player.isPlaying) player.togglePlayPause();
        break;
      case PressedButton.pause:
        if (player.isPlaying) player.togglePlayPause();
        break;
      case PressedButton.next:
        player.next();
        break;
      case PressedButton.previous:
        player.previous();
        break;
      case PressedButton.stop:
        if (player.isPlaying) player.togglePlayPause();
        break;
      default:
        break;
    }
  }

  void _onPlayerChanged() {
    final track = player.currentTrack;
    final playing = player.isPlaying;
    final position = player.position;

    if (!identical(track, _lastTrack)) {
      _lastTrack = track;
      _applyMetadata(track);
      _applyTimeline(track);
      _lastPosition = position;
    } else if (playing != _lastPlaying) {
      _applyTimeline(track);
      _lastPosition = position;
    } else if ((position - _lastPosition).abs() > const Duration(seconds: 2)) {
      // 只有 seek 导致的跳变才刷新进度，避免正常播放的高频更新。
      _applyTimeline(track);
      _lastPosition = position;
    }

    if (playing != _lastPlaying) {
      _lastPlaying = playing;
      _smtc.setPlaybackStatus(
          playing ? PlaybackStatus.playing : PlaybackStatus.paused);
    }
  }

  void _applyMetadata(Track? track) {
    if (track == null) {
      _smtc.clearMetadata();
      return;
    }
    _smtc.updateMetadata(MusicMetadata(
      title: track.title,
      artist: track.artist,
      album: track.album,
      albumArtist: track.artist,
      thumbnail: track.coverArtUrl ?? track.coverArtPath,
    ));
  }

  void _applyTimeline(Track? track) {
    if (track == null) return;
    _smtc.setTimeline(PlaybackTimeline(
      startTimeMs: 0,
      endTimeMs: track.duration.inMilliseconds,
      positionMs: player.position.inMilliseconds,
    ));
  }

  void dispose() {
    player.removeListener(_onPlayerChanged);
    _buttonSub?.cancel();
    _smtc.dispose();
  }
}
