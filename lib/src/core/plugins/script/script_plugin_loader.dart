import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../platform/platform_filesystem.dart';
import '../plugin_registry.dart';
import 'script_plugin_adapter.dart';

/// 运行时脚本插件加载器。
///
/// 扫描「插件目录」中的 `.dart` 源文件，逐个编译并注册为宿主插件：
/// * 桌面 / 移动端：`<应用数据目录>/plugins/`（用户可随时增删 `.dart` 文件，
///   重启应用即生效——真正的「运行时加载的独立文件」）。
/// * Web 端：无文件系统，直接加载打包进 assets 的内置脚本。
class ScriptPluginLoader {
  ScriptPluginLoader({required PlatformFileSystem fs}) : _fs = fs;

  final PlatformFileSystem _fs;

  /// 打包进应用的内置示例脚本（首次运行会复制到插件目录供用户修改）。
  static const List<String> bundledAssets = [
    'assets/plugins/statistics_plugin.dart',
    'assets/plugins/theme_presets_plugin.dart',
  ];

  Future<void> loadInto(PluginRegistry registry) async {
    if (_fs.supportsDirectoryScan) {
      final dir = await _pluginsDir();
      await _fs.ensureDirectory(dir);
      await _seedBundled(dir);
      debugPrint('[ScriptPluginLoader] 插件目录：$dir');
      final files = await _fs.listFiles(dir);
      for (final file in files) {
        if (!file.path.toLowerCase().endsWith('.dart')) continue;
        final bytes = await _fs.readBytes(file.path);
        if (bytes == null) continue;
        _register(registry, utf8.decode(bytes), file.path);
      }
    } else {
      for (final asset in bundledAssets) {
        try {
          _register(registry, await rootBundle.loadString(asset), asset);
        } catch (_) {
          // 单个资源加载失败不影响其他脚本。
        }
      }
    }
  }

  Future<String> _pluginsDir() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'plugins');
  }

  /// 把内置脚本复制到插件目录（已存在则跳过），便于用户查看 / 修改 / 删除。
  Future<void> _seedBundled(String dir) async {
    for (final asset in bundledAssets) {
      final name = asset.split('/').last;
      final target = '$dir/$name';
      if (await _fs.exists(target)) continue;
      try {
        await _fs.writeBytes(target, utf8.encode(await rootBundle.loadString(asset)));
      } catch (_) {
        // 忽略复制失败（例如 Web 无此路径）。
      }
    }
  }

  void _register(PluginRegistry registry, String source, String sourceName) {
    try {
      registry.register(ScriptPluginAdapter(source, sourceName: sourceName));
      debugPrint('[ScriptPluginLoader] 已加载脚本：$sourceName');
    } catch (error) {
      debugPrint('[ScriptPluginLoader] 加载脚本 $sourceName 失败：$error');
    }
  }
}
