import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/plugins/plugin_registry.dart';
import 'section.dart';

/// 插件管理：启用/禁用插件，并展示插件贡献的设置区块。
class PluginSettingsPage extends StatelessWidget {
  const PluginSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<PluginRegistry>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('插件'),
        actions: [
          TextButton.icon(
            onPressed: () => registry.resetToDefaults(),
            icon: const Icon(Icons.restart_alt),
            label: const Text('重置为默认'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final plugin in registry.all) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  SwitchListTile(
                    value: registry.isEnabled(plugin.id),
                    onChanged: (v) => registry.setEnabled(plugin.id, v),
                    secondary: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(plugin.icon,
                          color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                    title: Text(plugin.name),
                    subtitle: Text(
                      'v${plugin.version} · ${plugin.description}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (registry.isEnabled(plugin.id) &&
                      plugin.settingsSections.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final section in plugin.settingsSections)
                            SettingsSection(
                              title: section.title,
                              children: section.builder(context),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
