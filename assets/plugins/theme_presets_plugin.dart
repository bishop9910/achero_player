// 运行时脚本插件示例：主题预设。
// 完整协议见 docs/RUNTIME_PLUGINS.md。
import 'dart:convert';

String manifest(Function call) {
  return jsonEncode({
    'id': 'com.achero.themePresets',
    'name': '主题预设',
    'version': '1.2.0',
    'description': '一键套用配色方案',
    'icon': 'palette',
    'settings': {'id': 'com.achero.themePresets.settings', 'title': '主题预设'},
  });
}

String settingsTiles(Function call) {
  final presets = [
    {'title': '海洋蓝', 'subtitle': '默认风格', 'color': 0xFF0984E3},
    {'title': '赛博紫', 'subtitle': '深邃经典', 'color': 0xFF6C5CE7},
    {'title': '森林绿', 'subtitle': '自然护眼', 'color': 0xFF00B894},
    {'title': '琥珀金', 'subtitle': '温暖复古', 'color': 0xFFE17055},
    {'title': '玫瑰红', 'subtitle': '浪漫热烈', 'color': 0xFFE84393},
  ];
  final tiles = [];
  for (final p in presets) {
    tiles.add({
      'title': p['title'],
      'subtitle': p['subtitle'],
      'color': p['color'],
      'action': p['color'].toString(),
    });
  }
  return jsonEncode(tiles);
}

void onSettingsAction(Function call, String action) {
  call('setSeedColor', jsonEncode({'argb': int.parse(action)}));
}
