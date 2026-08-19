import 'package:flutter/material.dart';

import 'appearance_settings_page.dart';
import 'library_settings_page.dart';
import 'lyrics_settings_page.dart';
import 'plugin_settings_page.dart';

/// 设置首页：分组导航到各设置子页。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('设置',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _NavTile(
          icon: Icons.palette_outlined,
          title: '外观与字体',
          subtitle: '主题色 · 深浅色 · 字体',
          onTap: () => _push(context, const AppearanceSettingsPage()),
        ),
        _NavTile(
          icon: Icons.lyrics_outlined,
          title: '歌词显示',
          subtitle: '显示位置 · 字号 · 颜色',
          onTap: () => _push(context, const LyricsSettingsPage()),
        ),
        _NavTile(
          icon: Icons.folder_outlined,
          title: '音乐库',
          subtitle: '扫描目录 · 重新扫描',
          onTap: () => _push(context, const LibrarySettingsPage()),
        ),
        _NavTile(
          icon: Icons.extension_outlined,
          title: '插件',
          subtitle: '启用 / 禁用插件',
          onTap: () => _push(context, const PluginSettingsPage()),
        ),
        const _AboutTile(),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  /// 作者列表（后续有新开发者加入时追加到这里）。
  static const List<String> authors = ['bishop9910'];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: const CircleAvatar(
          foregroundImage: AssetImage('assets/images/logo.jpg'),
          child: Icon(Icons.music_note),
        ),
        title: const Text('应用介绍'),
        subtitle: const Text('v1.0.3+8 · 关于 · 作者 · 许可'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAbout(context),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const CircleAvatar(
              foregroundImage: AssetImage('assets/images/logo.jpg'),
              child: Icon(Icons.music_note),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Achero Player')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v1.0.3+8', style: Theme.of(context).textTheme.bodySmall),
            Text('2026/8/19', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            const Text('一个可深度自定义、支持插件的跨平台音乐播放器。'),
            const SizedBox(height: 16),
            Text('作者', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final author in authors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    CircleAvatar(
                      foregroundImage: AssetImage('assets/images/$author.jpg'),
                      child: const Icon(Icons.music_note),
                    ),
                    const SizedBox(width: 8),
                    Text(author),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Achero Player',
              applicationVersion: '1.0.3',
              applicationIcon: const Icon(Icons.music_note),
            ),
            child: const Text('查看许可'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
