import 'dart:async';

import '../audio/audio_engine.dart';
import '../models/track.dart';

/// 插件事件总线：把播放器 / 曲库的关键事件广播给所有插件。
///
/// 事件以具名广播流的形式暴露，插件在 `onLoad` 中订阅，在 `onUnload`
/// 中取消订阅。总线是「单向的」——插件只读，不参与播放决策。
class PluginEventBus {
  final _trackStarted = StreamController<Track>.broadcast();
  final _trackChanged = StreamController<Track>.broadcast();
  final _stateChanged = StreamController<PlaybackStatus>.broadcast();
  final _positionChanged = StreamController<Duration>.broadcast();
  final _libraryChanged = StreamController<int>.broadcast();

  /// 一首曲目开始播放。
  Stream<Track> get onTrackStarted => _trackStarted.stream;

  /// 切换到了新曲目（含自动切歌与手动切歌）。
  Stream<Track> get onTrackChanged => _trackChanged.stream;

  /// 播放状态变化（播放 / 暂停 / 完成…）。
  Stream<PlaybackStatus> get onStateChanged => _stateChanged.stream;

  /// 播放进度（高频，慎用——建议自行节流）。
  Stream<Duration> get onPositionChanged => _positionChanged.stream;

  /// 曲库曲目总数变化。
  Stream<int> get onLibraryChanged => _libraryChanged.stream;

  void emitTrackStarted(Track track) {
    if (!_trackStarted.isClosed) _trackStarted.add(track);
  }

  void emitTrackChanged(Track track) {
    if (!_trackChanged.isClosed) _trackChanged.add(track);
  }

  void emitStateChanged(PlaybackStatus status) {
    if (!_stateChanged.isClosed) _stateChanged.add(status);
  }

  void emitPositionChanged(Duration position) {
    if (!_positionChanged.isClosed) _positionChanged.add(position);
  }

  void emitLibraryChanged(int trackCount) {
    if (!_libraryChanged.isClosed) _libraryChanged.add(trackCount);
  }

  Future<void> dispose() async {
    await Future.wait([
      _trackStarted.close(),
      _trackChanged.close(),
      _stateChanged.close(),
      _positionChanged.close(),
      _libraryChanged.close(),
    ]);
  }
}
