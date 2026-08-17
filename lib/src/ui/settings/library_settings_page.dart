import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library/music_library.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/settings/settings_controller.dart';
import 'section.dart';

/// 音乐库设置：管理扫描目录与重新扫描。
class LibrarySettingsPage extends StatelessWidget {
  const LibrarySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final library = context.watch<MusicLibrary>();
    final folders = settings.settings.library.folders;
    final canScan = supportsDirectoryPicker;

    return Scaffold(
      appBar: AppBar(title: const Text('音乐库')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsSection(
            title: '曲库概览',
            children: [
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('曲目总数'),
                trailing: Text('${library.trackCount}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          if (canScan)
            SettingsSection(
              title: '扫描目录',
              children: [
                if (folders.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('尚未添加扫描目录'),
                    subtitle: Text('添加后会自动递归导入目录下的音频'),
                  )
                else
                  for (final folder in folders)
                    ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folder,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => settings.updateLibrary(
                          settings.settings.library.copyWith(
                            folders: folders.where((f) => f != folder).toList(),
                          ),
                        ),
                      ),
                    ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('添加扫描目录'),
                  onTap: () async {
                    final dir = await FilePicker.platform.getDirectoryPath();
                    if (dir == null) return;
                    settings.updateLibrary(
                      settings.settings.library.copyWith(
                        folders: [...folders, dir],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('立即重新扫描'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(const SnackBar(
                        content: Text('正在扫描…'),
                        duration: Duration(milliseconds: 1500)));
                    final added =
                        await context.read<MusicLibrary>().scanAndImport(folders);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(SnackBar(
                        content: Text('扫描完成，新增 $added 首曲目'),
                        duration: const Duration(milliseconds: 1500)));
                  },
                ),
              ],
            )
          else
            const SettingsSection(
              title: '扫描目录',
              children: [
                ListTile(
                  leading: Icon(Icons.language),
                  title: Text('当前平台不支持目录扫描'),
                  subtitle: Text('请从曲库页「添加音乐」导入音频文件'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
