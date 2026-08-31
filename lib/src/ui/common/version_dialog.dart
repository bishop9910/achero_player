import 'package:flutter/material.dart';

import '../../core/app_info.dart';

/// 弹出「版本信息与更新日志」对话框。
///
/// 由两处触发：启动时对每个新版本自动弹出一次（见 [AppInfo.shouldAutoShow]），
/// 以及设置页「更新日志」入口手动查看。
Future<void> showVersionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _VersionDialog(),
  );
}

class _VersionDialog extends StatelessWidget {
  const _VersionDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 头部：logo + 名称 + 版本徽标。
            Container(
              color: scheme.primaryContainer,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.surface,
                    foregroundImage: const AssetImage('assets/images/logo.jpg'),
                    child: const Icon(Icons.music_note),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppInfo.name,
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          kAppReleaseDate,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'v$kAppVersionWithBuild',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 更新日志正文。
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '更新内容',
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final group in AppInfo.changelog) ...[
                      _ChangelogGroupView(group: group),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            // 底部按钮。
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangelogGroupView extends StatelessWidget {
  const _ChangelogGroupView({required this.group});

  final ChangelogGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(group.icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              group.title,
              style: textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final item in group.items)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 3, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 10),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Text(item, style: textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
