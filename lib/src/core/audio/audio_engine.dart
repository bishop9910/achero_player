import '../models/track.dart';

/// 播放器状态机。
enum PlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  completed,
  error;

  bool get isPlaying => this == PlaybackStatus.playing;
  bool get isActive => this == PlaybackStatus.playing || this == PlaybackStatus.paused;
}

/// 音频引擎抽象接口。
///
/// 把「播放一首曲目」这件事从具体实现中解耦：当前实现为
/// [MediaKitEngine]，上层播放控制器与 UI 无需感知底层差异。
abstract interface class AudioEngine {
  Stream<PlaybackStatus> get statusStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;

  /// 每次一首曲目自然播放完成时发出一个事件。
  Stream<void> get completionStream;

  /// 播放出错（如解码失败、加载失败）时发出错误描述。
  Stream<String> get errorStream;

  /// 加载并准备播放一首曲目（不自动开始）。
  Future<void> load(Track track);

  /// 播放已 [load] 的新曲目（原子地「设置来源并播放」）。
  Future<void> play();

  /// 恢复当前曲目（从暂停状态继续，不重新加载来源）。
  Future<void> resume();

  Future<void> pause();
  Future<void> stop();

  /// 跳转到指定位置。
  Future<void> seek(Duration position);

  /// 设置音量，范围 0.0 ~ 1.0。
  Future<void> setVolume(double volume);

  /// 设置播放速率（变速，不影响音调，取决于底层实现）。
  Future<void> setRate(double rate);

  Future<Duration> get position;
  Future<Duration?> get duration;

  Future<void> dispose();
}
