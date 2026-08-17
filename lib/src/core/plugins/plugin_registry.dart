import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plugin_manifest.dart';
import 'plugin_types.dart';

/// 插件注册表：负责插件的注册、启用/禁用与贡献聚合。
///
/// 插件在编译期通过 [register] / [registerAll] 注册（见 `plugin_bootstrap.dart`），
/// 随后 [initialize] 依据清单启用它们，并把每个插件贡献的页面 / 设置 /
/// 播放页面板汇总给 UI 层消费。
class PluginRegistry extends ChangeNotifier {
  PluginRegistry(this._prefs) : _manifest = _loadManifest(_prefs);

  static const String _storageKey = 'achero.plugins.manifest.v1';

  final SharedPreferences _prefs;
  final PluginManifest _manifest;

  final Map<String, AcheroPlugin> _all = {};
  final Map<String, AcheroPlugin> _enabled = {};
  PluginContextFactory? _contextFactory;

  // ---------------------------------------------------------------------------
  // 生命周期
  // ---------------------------------------------------------------------------

  void register(AcheroPlugin plugin) => _all[plugin.id] = plugin;

  void registerAll(Iterable<AcheroPlugin> plugins) {
    for (final plugin in plugins) {
      _all[plugin.id] = plugin;
    }
  }

  /// 按清单启用默认启用的插件。
  Future<void> initialize(PluginContextFactory factory) async {
    _contextFactory = factory;
    for (final plugin in _all.values) {
      final override = _manifest.overrideFor(plugin.id);
      final enabled = override ?? plugin.enabledByDefault;
      debugPrint('[PluginRegistry] ${enabled ? '启用' : '禁用'}插件：'
          '${plugin.id}（default=${plugin.enabledByDefault}, override=$override）');
      if (enabled) {
        await _enable(plugin);
      }
    }
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final plugin = _all[id];
    if (plugin == null) return;
    _manifest.set(id, enabled);
    await _prefs.setString(_storageKey, _manifest.encode());
    if (enabled) {
      await _enable(plugin);
    } else {
      await _disable(plugin);
    }
    notifyListeners();
  }

  /// 清空所有手动覆盖，让每个插件回到 [AcheroPlugin.enabledByDefault]。
  Future<void> resetToDefaults() async {
    _manifest.clear();
    await _prefs.remove(_storageKey);
    for (final plugin in _all.values) {
      if (plugin.enabledByDefault) {
        await _enable(plugin);
      } else {
        await _disable(plugin);
      }
    }
    notifyListeners();
  }

  Future<void> _enable(AcheroPlugin plugin) async {
    if (_enabled.containsKey(plugin.id)) return;
    _enabled[plugin.id] = plugin;
    try {
      await plugin.onLoad(_contextFactory!(plugin));
    } catch (error) {
      // 单个插件加载失败不应拖垮整个应用。
      _enabled.remove(plugin.id);
      debugPrint('[PluginRegistry] 插件 "${plugin.id}" 加载失败: $error');
    }
  }

  Future<void> _disable(AcheroPlugin plugin) async {
    if (_enabled.remove(plugin.id) == null) return;
    try {
      await plugin.onUnload();
    } catch (error) {
      debugPrint('[PluginRegistry] 插件 "${plugin.id}" 卸载失败: $error');
    }
  }

  Future<void> disposeAll() async {
    for (final plugin in _enabled.values.toList()) {
      await _disable(plugin);
    }
  }

  // ---------------------------------------------------------------------------
  // 查询与贡献聚合
  // ---------------------------------------------------------------------------

  List<AcheroPlugin> get all => List.unmodifiable(_all.values);
  List<AcheroPlugin> get enabled => List.unmodifiable(_enabled.values);

  bool isEnabled(String id) => _enabled.containsKey(id);
  bool contains(String id) => _all.containsKey(id);

  List<PluginPage> get pages => [
        for (final plugin in _enabled.values) ...plugin.pages,
      ];

  List<PluginSettingsSection> get settingsSections => [
        for (final plugin in _enabled.values) ...plugin.settingsSections,
      ];

  List<PlayerWidget> get playerWidgets => [
        for (final plugin in _enabled.values) ...plugin.playerWidgets,
      ];

  static PluginManifest _loadManifest(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    return raw == null ? PluginManifest() : PluginManifest.decode(raw);
  }
}
