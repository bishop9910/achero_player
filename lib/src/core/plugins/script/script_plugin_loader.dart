import 'dart:convert';

import 'package:crypto/crypto.dart';
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

  /// 把内置脚本同步到插件目录（带哈希自动更新）。
  ///
  /// 策略：记录每个内置脚本上次「播种」的 SHA256。启动时对比：
  /// * 插件目录无此文件 → 复制内置版并记录哈希；
  /// * 文件哈希 == 记录的哈希（用户没改过）→ 若内置版更新了则覆盖；
  /// * 文件哈希 != 记录的哈希（用户改过）→ 保留用户版本。
  Future<void> _seedBundled(String dir) async {
    final meta = await _readMeta(dir);
    var metaChanged = false;

    for (final asset in bundledAssets) {
      final name = asset.split('/').last;
      final target = p.join(dir, name);
      try {
        final bundled = await rootBundle.loadString(asset);
        final bundledHash = _sha256(bundled);

        if (!await _fs.exists(target)) {
          await _fs.writeBytes(target, utf8.encode(bundled));
          meta[name] = bundledHash;
          metaChanged = true;
          continue;
        }

        final existingBytes = await _fs.readBytes(target);
        if (existingBytes == null) {
          await _fs.writeBytes(target, utf8.encode(bundled));
          meta[name] = bundledHash;
          metaChanged = true;
          continue;
        }

        final existingHash = _sha256(utf8.decode(existingBytes));
        final lastSeeded = meta[name];

        if (lastSeeded == null) {
          // 旧版升级而来，无历史哈希：直接采用内置版。
          await _fs.writeBytes(target, utf8.encode(bundled));
          meta[name] = bundledHash;
          metaChanged = true;
        } else if (existingHash == lastSeeded) {
          // 用户未修改：内置版有更新则覆盖。
          if (bundledHash != lastSeeded) {
            await _fs.writeBytes(target, utf8.encode(bundled));
            meta[name] = bundledHash;
            metaChanged = true;
            debugPrint('[ScriptPluginLoader] 已更新内置脚本：$name');
          }
        } else {
          // 用户修改过：保留。
          debugPrint('[ScriptPluginLoader] 保留用户修改的脚本：$name');
        }
      } catch (_) {
        // 忽略单个脚本失败。
      }
    }

    if (metaChanged) await _writeMeta(dir, meta);
  }

  Future<Map<String, String>> _readMeta(String dir) async {
    final path = p.join(dir, '.achero_scripts.json');
    final bytes = await _fs.readBytes(path);
    if (bytes == null) return {};
    try {
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMeta(String dir, Map<String, String> meta) async {
    await _fs.writeBytes(
      p.join(dir, '.achero_scripts.json'),
      utf8.encode(jsonEncode(meta)),
    );
  }

  String _sha256(String source) =>
      sha256.convert(utf8.encode(source)).toString();

  void _register(PluginRegistry registry, String source, String sourceName) {
    try {
      registry.register(ScriptPluginAdapter(source, sourceName: sourceName));
      debugPrint('[ScriptPluginLoader] 已加载脚本：$sourceName');
    } catch (error) {
      debugPrint('[ScriptPluginLoader] 加载脚本 $sourceName 失败：$error');
    }
  }
}
