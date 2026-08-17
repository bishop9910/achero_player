import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/platform/platform_capabilities.dart';

const Map<String, String> _mimeByExtension = {
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'mp4': 'audio/mp4',
  'aac': 'audio/aac',
  'flac': 'audio/flac',
  'ogg': 'audio/ogg',
  'opus': 'audio/ogg',
  'wav': 'audio/wav',
  'wma': 'audio/x-ms-wma',
  'aiff': 'audio/aiff',
};

/// 添加音乐：桌面端可选「文件夹 / 文件」，移动端与 Web 端选文件。
Future<void> addMusic(BuildContext context) async {
  final services = context.read<AppServices>();

  if (supportsDirectoryPicker) {
    final choice = await _showImportChoice(context);
    if (choice == null || !context.mounted) return;
    if (choice == _ImportChoice.folder) {
      await _pickFolder(context, services);
    } else {
      await _pickAudioFiles(context, services);
    }
  } else {
    await _pickAudioFiles(context, services);
  }
}

Future<_ImportChoice?> _showImportChoice(BuildContext context) {
  return showModalBottomSheet<_ImportChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('扫描整个文件夹'),
            subtitle: const Text('递归导入目录下的所有音频'),
            onTap: () => Navigator.pop(context, _ImportChoice.folder),
          ),
          ListTile(
            leading: const Icon(Icons.audio_file),
            title: const Text('选择音频文件'),
            subtitle: const Text('导入一个或多个音频文件'),
            onTap: () => Navigator.pop(context, _ImportChoice.files),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pickFolder(BuildContext context, AppServices services) async {
  final dir = await FilePicker.platform.getDirectoryPath();
  if (dir == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(
      content: Text('正在扫描曲库…'),
      duration: Duration(milliseconds: 1500)));
  final settings = services.settings;
  final folders = {...settings.settings.library.folders, dir}.toList();
  settings.updateLibrary(settings.settings.library.copyWith(folders: folders));
  final added = await services.library.scanAndImport(folders);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
      content: Text('扫描完成，新增 $added 首曲目'),
      duration: const Duration(milliseconds: 1500)));
}

Future<void> _pickAudioFiles(BuildContext context, AppServices services) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.audio,
    withData: kIsWeb,
  );
  if (result == null || !context.mounted) return;

  if (kIsWeb) {
    final files = <({String name, Uint8List bytes, String mime})>[];
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      final ext = f.extension?.toLowerCase() ?? '';
      files.add((
        name: f.name,
        bytes: bytes,
        mime: _mimeByExtension[ext] ?? 'application/octet-stream',
      ));
    }
    if (files.isEmpty) return;
    final imported = services.library.importBytes(files);
    _toast(context, '已导入 ${imported.length} 首曲目（仅本次会话有效）');
  } else {
    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .toList(growable: false);
    if (paths.isEmpty) return;
    final added = await services.library.importPaths(paths);
    if (!context.mounted) return;
    _toast(context, '已导入 $added 首曲目');
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 1500),
    ));
}

enum _ImportChoice { folder, files }
