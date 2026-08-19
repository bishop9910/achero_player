import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/download/download_manager.dart';
import '../common/formats.dart';

/// 下载管理页：显示正在下载 / 已完成 / 失败的任务与进度条。
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadManager>();
    final tasks = downloads.tasks;

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('暂无下载任务',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '在曲库 / 歌单里对 RPC 或 Subsonic 曲目点「更多 → 下载」即可',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('下载',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            if (tasks.any((t) => !t.active))
              TextButton(
                onPressed: downloads.clearFinished,
                child: const Text('清除已完成'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final task in tasks) _TaskTile(task: task),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = task.active;
    return Card(
      child: ListTile(
        leading: _leadingIcon(scheme),
        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: task.progress > 0 ? task.progress : null),
              const SizedBox(height: 6),
              Text(_progressText(), style: Theme.of(context).textTheme.bodySmall),
            ] else
              Text(_statusText(), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: active
            ? null
            : IconButton(
                tooltip: '移除',
                icon: const Icon(Icons.close),
                onPressed: () =>
                    context.read<DownloadManager>().removeTask(task),
              ),
      ),
    );
  }

  Widget _leadingIcon(ColorScheme scheme) {
    switch (task.status) {
      case DownloadStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green);
      case DownloadStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.redAccent);
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case DownloadStatus.queued:
        return Icon(Icons.schedule, color: scheme.outline);
    }
  }

  String _progressText() {
    if (task.totalBytes > 0) {
      return '${formatBytes(task.receivedBytes)} / ${formatBytes(task.totalBytes)}';
    }
    return '${formatBytes(task.receivedBytes)} 已下载';
  }

  String _statusText() {
    switch (task.status) {
      case DownloadStatus.done:
        return '已完成';
      case DownloadStatus.failed:
        return '下载失败';
      case DownloadStatus.downloading:
        return '下载中…';
      case DownloadStatus.queued:
        return '排队中…';
    }
  }
}
