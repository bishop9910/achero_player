import 'dart:convert';

/// 插件启用状态清单。
///
/// 记录用户对「默认启用」的覆盖：未出现在清单中的插件按其
/// [AcheroPlugin.enabledByDefault] 决定是否启用。
class PluginManifest {
  PluginManifest([Map<String, bool>? overrides])
      : _overrides = overrides ?? {};

  final Map<String, bool> _overrides;

  bool? overrideFor(String id) => _overrides[id];

  void set(String id, bool enabled) => _overrides[id] = enabled;

  /// 清空所有覆盖，使插件全部回到 [AcheroPlugin.enabledByDefault]。
  void clear() => _overrides.clear();

  Map<String, dynamic> toJson() => _overrides;

  static PluginManifest fromJson(Map<String, dynamic> json) => PluginManifest(
        json.map((k, v) => MapEntry(k, v as bool)),
      );

  String encode() => jsonEncode(toJson());

  static PluginManifest decode(String raw) {
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PluginManifest();
    }
  }
}
