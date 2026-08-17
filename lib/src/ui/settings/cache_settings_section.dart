import 'package:flutter/material.dart';

import '../../core/cache/cache_manager.dart';
import '../common/formats.dart';

/// 可复用的缓存设置区块：路径、保留天数、清理、清空与占用统计。
///
/// 供 Subsonic / RPC 音乐服务器等需要缓存的插件共用。通过回调与「当前值
/// 提供者」解耦，插件在路径变化后重建 [CacheManager] 也能被正确读到。
class CacheSettingsSection extends StatefulWidget {
  const CacheSettingsSection({
    super.key,
    required this.cacheProvider,
    required this.ttlProvider,
    required this.onTtlChanged,
    required this.onPathChanged,
  });

  /// 始终返回「当前」缓存实例（Web 等不支持缓存的平台返回 null）。
  final CacheManager? Function() cacheProvider;

  /// 当前缓存保留天数。
  final int Function() ttlProvider;

  final Future<void> Function(int days) onTtlChanged;
  final Future<void> Function(String path) onPathChanged;

  @override
  State<CacheSettingsSection> createState() => _CacheSettingsSectionState();
}

class _CacheSettingsSectionState extends State<CacheSettingsSection> {
  int _size = -1;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    final cache = widget.cacheProvider();
    if (cache == null) {
      if (mounted) setState(() => _size = -1);
      return;
    }
    final size = await cache.totalSize();
    if (mounted) setState(() => _size = size);
  }

  @override
  Widget build(BuildContext context) {
    final cache = widget.cacheProvider();

    if (cache == null) {
      return const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('当前平台不支持文件缓存'),
        subtitle: Text('将改为在线流式播放'),
      );
    }

    final ttlDays = widget.ttlProvider();
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('缓存目录'),
          subtitle: Text(cache.rootDir, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editPath(context, cache),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('缓存保留天数'),
          subtitle: SizedBox(
            height: 36,
            child: Slider(
              value: ttlDays.toDouble().clamp(1, 90),
              min: 1,
              max: 90,
              divisions: 89,
              label: '$ttlDays 天',
              onChanged: (v) async {
                await widget.onTtlChanged(v.round());
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('清理过期缓存'),
          subtitle: _size >= 0 ? Text('当前占用 ${formatBytes(_size)}') : null,
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final deleted = await cache.cleanup();
            await _refreshSize();
            messenger.showSnackBar(SnackBar(
                content: Text('已删除 $deleted 个过期文件'),
                duration: const Duration(milliseconds: 1500)));
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('清空全部缓存'),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final deleted = await cache.clearAll();
            await _refreshSize();
            messenger.showSnackBar(SnackBar(
                content: Text('已清空 $deleted 个文件'),
                duration: const Duration(milliseconds: 1500)));
          },
        ),
      ],
    );
  }

  Future<void> _editPath(BuildContext context, CacheManager cache) async {
    final controller = TextEditingController(text: cache.rootDir);
    final newPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义缓存目录'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入绝对路径'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newPath == null || newPath.isEmpty || !mounted) return;
    await widget.onPathChanged(newPath);
    await _refreshSize();
    if (mounted) setState(() {});
  }
}
