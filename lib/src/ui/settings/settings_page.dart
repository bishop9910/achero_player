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

  /// 作者名（要改就在这里改）。
  static const String authorName = 'Bishop9910';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Achero Player',
          applicationVersion: '1.0.3',
          applicationIcon: const CircleAvatar(
            radius: 24,
            foregroundImage: AssetImage('assets/images/bishop9910.png'),
            child: Icon(Icons.music_note),
          ),
          applicationLegalese: '一个可深度自定义、支持插件的跨平台音乐播放器。',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                foregroundImage:
                    const AssetImage('assets/images/bishop9910.jpg'),
                child: const Icon(Icons.person),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('作者',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.primary)),
                    const SizedBox(height: 2),
                    Text(authorName,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('v1.0.3 跨平台 · 可插拔',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
