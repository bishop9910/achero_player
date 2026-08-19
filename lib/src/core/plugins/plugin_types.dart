import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../download/download_manager.dart';
import '../library/music_library.dart';
import '../platform/platform_filesystem.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import '../theme/font_manager.dart';
import 'plugin_event_bus.dart';

/// 插件贡献的独立页面（出现在主导航中）。
class PluginPage {
  const PluginPage({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

/// 插件贡献的设置区块（渲染在设置页）。
class PluginSettingsSection {
  const PluginSettingsSection({
    required this.id,
    required this.title,
    required this.builder,
  });

  final String id;
  final String title;

  /// 返回该区块下的设置项 widget 列表。
  final List<Widget> Function(BuildContext context) builder;
}

/// 插件注入到播放页的额外面板（如均衡器、可视化、自定义歌词等）。
class PlayerWidget {
  const PlayerWidget({
    required this.id,
    required this.title,
    required this.builder,
  });

  final String id;
  final String title;
  final Widget Function(BuildContext context) builder;
}

/// 插件对外提供的命令（可被主界面菜单触发）。
class PluginAction {
  const PluginAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onInvoke,
  });

  final String id;
  final String label;
  final IconData icon;
  final Future<void> Function() onInvoke;
}

/// Achero 插件接口。
///
/// 插件是「编译进应用」的 Dart 模块（Flutter AOT 无法在运行时加载任意
/// Dart 代码），通过继承本类并在 `plugin_bootstrap.dart` 注册即可扩展：
/// 独立页面、设置区块、播放页面板与自定义命令。所有贡献点都有默认空实现，
/// 插件只需覆写自己关心的部分。
///
/// 完整开发指南见 `docs/PLUGINS.md`。
abstract class AcheroPlugin {
  /// 全局唯一 id，例如 `com.example.statistics`。
  String get id;

  /// 展示名称。
  String get name;

  /// 语义化版本号。
  String get version;

  /// 一句话描述。
  String get description;

  IconData get icon => Icons.extension;

  /// 是否默认启用。
  bool get enabledByDefault => true;

  /// 插件被启用时调用，可在此订阅事件、读写 [PluginContext.prefs]。
  Future<void> onLoad(PluginContext context) async {}

  /// 插件被禁用或应用退出时调用，用于清理资源。
  Future<void> onUnload() async {}

  /// 贡献的页面。
  List<PluginPage> get pages => const [];

  /// 贡献的设置区块。
  List<PluginSettingsSection> get settingsSections => const [];

  /// 注入到播放页的面板。
  List<PlayerWidget> get playerWidgets => const [];

  /// 贡献的命令（暂未挂载 UI，保留给进阶使用）。
  List<PluginAction> get actions => const [];
}

/// 插件上下文：插件加载时获得的宿主能力集合。
class PluginContext {
  const PluginContext({
    required this.pluginId,
    required this.settings,
    required this.player,
    required this.library,
    required this.fonts,
    required this.fs,
    required this.events,
    required this.downloads,
    required this.prefs,
    required this.log,
  });

  final String pluginId;
  final SettingsController settings;
  final PlayerController player;
  final MusicLibrary library;
  final FontManager fonts;
  final PlatformFileSystem fs;
  final PluginEventBus events;

  /// 下载管理器（插件用于注册自己的缓存目录）。
  final DownloadManager downloads;

  /// 该插件专属的持久化键值存储（自动按插件 id 命名空间隔离）。
  final PluginPrefs prefs;

  /// 日志输出（同时打印到控制台与调试面板）。
  final void Function(String message) log;
}

/// 插件专属的持久化键值存储。
class PluginPrefs {
  PluginPrefs(this._prefs, this._pluginId);

  final SharedPreferences _prefs;
  final String _pluginId;

  String _key(String key) => 'achero.plugin.$_pluginId.$key';

  String? getString(String key) => _prefs.getString(_key(key));
  Future<void> setString(String key, String value) =>
      _prefs.setString(_key(key), value);

  bool? getBool(String key) => _prefs.getBool(_key(key));
  Future<void> setBool(String key, bool value) =>
      _prefs.setBool(_key(key), value);

  int? getInt(String key) => _prefs.getInt(_key(key));
  Future<void> setInt(String key, int value) =>
      _prefs.setInt(_key(key), value);

  double? getDouble(String key) => _prefs.getDouble(_key(key));
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(_key(key), value);

  List<String>? getStringList(String key) => _prefs.getStringList(_key(key));
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(_key(key), value);

  Future<void> remove(String key) => _prefs.remove(_key(key));
}

/// 为某个插件创建上下文的工厂（由启动引导提供）。
typedef PluginContextFactory = PluginContext Function(AcheroPlugin plugin);
