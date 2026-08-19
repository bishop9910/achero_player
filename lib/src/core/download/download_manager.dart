import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cache/cache_manager.dart';
import '../library/music_library.dart';
import '../models/track.dart';
import '../rpc/download.dart';

/// 下载状态。
enum DownloadStatus { queued, downloading, done, failed }

/// 单个下载任务（带进度）。
class DownloadTask {
  DownloadTask({
    required this.trackId,
    required this.title,
    required this.url,
  });

  final String trackId;
  final String title;
  final String url;

  DownloadStatus status = DownloadStatus.queued;
  double progress = 0;
  int receivedBytes = 0;
  int totalBytes = 0;

  bool get active =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;
}

/// 下载管理器：统一处理 RPC / Subsonic 曲目的「下载并缓存」，带进度回报。
///
/// 各音乐服务器插件在加载时把自己的 [CacheManager] 按 [TrackOrigin] 注册进来；
/// 曲库菜单触发 [download]，完成后把曲目来源切换为本地文件（保留 [Track.remoteUrl]
/// 以便本地文件损坏时回退在线播放）。
class DownloadManager extends ChangeNotifier {
  DownloadManager({required this.library});

  final MusicLibrary library;
  final List<DownloadTask> _tasks = [];
  final Map<TrackOrigin, CacheManager> _caches = {};

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  bool get hasActive => _tasks.any((t) => t.active);

  /// 进行中任务的综合进度（0~1）。
  double get overallProgress {
    final active = _tasks.where((t) => t.active).toList();
    if (active.isEmpty) return 0;
    var received = 0;
    var total = 0;
    for (final t in active) {
      received += t.receivedBytes;
      total += t.totalBytes;
    }
    if (total > 0) return (received / total).clamp(0.0, 1.0);
    final sum = active.fold<double>(0, (acc, t) => acc + t.progress);
    return (sum / active.length).clamp(0.0, 1.0);
  }

  /// 注册某个音源类型对应的缓存目录。
  void registerCache(TrackOrigin origin, CacheManager cache) {
    _caches[origin] = cache;
  }

  CacheManager? cacheFor(TrackOrigin origin) => _caches[origin];

  bool isDownloading(String trackId) =>
      _tasks.any((t) => t.trackId == trackId && t.active);

  /// 下载一首曲目（音频 + 封面）并缓存，完成后更新曲库。
  /// 返回是否已开始下载（false 表示缺少缓存、服务器地址或已在下载）。
  Future<bool> download(Track track) async {
    final cache = _caches[track.origin];
    var url = track.remoteUrl;
    if (url == null || url.isEmpty) {
      final source = track.source;
      if (source is UrlTrackSource) url = source.url;
    }
    if (cache == null || url == null || url.isEmpty) return false;
    if (isDownloading(track.id)) return false;

    // 清理同一曲目旧的已完成/失败任务，避免重复条目。
    _tasks.removeWhere((t) => t.trackId == track.id && !t.active);

    final task = DownloadTask(trackId: track.id, title: track.title, url: url);
    _tasks.insert(0, task);
    notifyListeners();

    unawaited(_run(task, track, cache, url));
    return true;
  }

  Future<void> _run(
      DownloadTask task, Track track, CacheManager cache, String url) async {
    try {
      task.status = DownloadStatus.downloading;
      notifyListeners();

      final bytes = await downloadStreamWithProgress(
        Uri.parse(url),
        onProgress: (received, total) {
          task.receivedBytes = received;
          task.totalBytes = total;
          task.progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0;
          notifyListeners();
        },
      );
      if (bytes == null) {
        task.status = DownloadStatus.failed;
        notifyListeners();
        return;
      }

      final ext = _extensionFromUrl(url);
      final path = await cache.putAudio(track.id, ext, bytes);
      final coverPath = await _cacheCover(track, cache);

      // 切换为本地文件来源，保留 remoteUrl 供回退/重下。
      library.upsertTrack(track.copyWith(
        source: FileTrackSource(path),
        coverArtPath: coverPath ?? track.coverArtPath,
      ));
      task.progress = 1;
      task.status = DownloadStatus.done;
    } catch (_) {
      task.status = DownloadStatus.failed;
    }
    notifyListeners();
  }

  /// 移除一个已结束的任务。
  void removeTask(DownloadTask task) {
    if (task.active) return;
    _tasks.remove(task);
    notifyListeners();
  }

  /// 清空所有已结束的任务。
  void clearFinished() {
    _tasks.removeWhere((t) => !t.active);
    notifyListeners();
  }

  Future<String?> _cacheCover(Track track, CacheManager cache) async {
    final coverUrl = track.coverArtUrl;
    if (coverUrl == null || coverUrl.isEmpty) return null;
    try {
      final bytes = await downloadCover(Uri.parse(coverUrl));
      if (bytes == null) return null;
      return await cache.putCover(track.id, bytes);
    } catch (_) {
      return null;
    }
  }

  String _extensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'mp3';
    return path.substring(dot + 1).toLowerCase();
  }
}
