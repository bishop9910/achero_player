// 运行时脚本插件示例：播放统计。
// 这是「独立的 .dart 文件」，在应用启动时被扫描、编译、执行，无需重新编译宿主。
// 完整协议见 docs/RUNTIME_PLUGINS.md。
import 'dart:convert';

String manifest(Function call) {
  return jsonEncode({
    'id': 'com.achero.statistics',
    'name': '播放统计',
    'version': '1.3.2',
    'description': '记录每首曲目的播放次数并展示排行榜',
    'icon': 'bar_chart',
    'page': {'id': 'com.achero.statistics.page', 'title': '播放统计', 'icon': 'bar_chart', 'sort': true},
    'events': ['trackStarted'],
  });
}

void onEvent(Function call, String name, String payloadJson) {
  if (name != 'trackStarted') return;
  final payload = jsonDecode(payloadJson);
  final id = payload['id'];
  if (id == null) return;

  final raw = call('prefsGet', jsonEncode({'key': 'plays'}));
  var counts = {};
  if (raw != null) {
    counts = jsonDecode(raw);
  }
  counts[id] = (counts[id] ?? 0) + 1;
  call('prefsSet', jsonEncode({'key': 'plays', 'value': jsonEncode(counts)}));
}

String pageRows(Function call, String sortDir) {
  final raw = call('prefsGet', jsonEncode({'key': 'plays'}));
  var counts = {};
  if (raw != null) {
    counts = jsonDecode(raw);
  }
  final tracks = jsonDecode(call('listTracks', '{}'));

  final rows = [];
  for (final t in tracks) {
    final id = t['id'];
    final n = counts[id] ?? 0;
    if (n > 0) {
      rows.add({
        'title': t['title'],
        'subtitle': t['artist'] ?? '',
        'trailing': '$n 次',
        'sortValue': n,
      });
    }
  }

  // 排序交给宿主按 sortValue 进行（dart_eval 的 List.sort 对闭包支持不稳）
  return jsonEncode(rows);
}