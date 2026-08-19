import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/download/download_manager.dart';
import 'downloads_page.dart';

/// 右下角悬浮的下载小图标。
///
/// 有下载任务时，图标由下往上「水位填充」主题色表示进度；
/// 点击打开非全屏的下载管理页（底部弹层）。
class DownloadFab extends StatelessWidget {
  const DownloadFab({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadManager>();
    final scheme = Theme.of(context).colorScheme;
    final progress = downloads.overallProgress;
    final hasActive = downloads.hasActive;

    return Material(
      shape: const CircleBorder(),
      color: scheme.surfaceContainerHighest,
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _open(context),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 主题色水位填充动画（由下往上）。
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => ClipOval(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: value.clamp(0.0, 1.0),
                      child: ColoredBox(color: scheme.primary),
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  hasActive ? Icons.downloading : Icons.download_outlined,
                  size: 22,
                  color: progress > 0.35 ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.72,
        child: DownloadsPage(),
      ),
    );
  }
}
