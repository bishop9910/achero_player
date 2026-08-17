// 运行时脚本插件示例：播放统计。
// 这是「独立的 .dart 文件」，在应用启动时被扫描、编译、执行，无需重新编译宿主。
// 完整协议见 docs/RUNTIME_PLUGINS.md。
import 'dart:convert';

String manifest(Function call) {
  return jsonEncode({
    'id': 'com.achero.statistics',
    'name': '播放统计',
    'version': '1.3.0',
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
        '_count': n,
      });
    }
  }

  // sortDir: 'asc' = 正序（从少到多），'desc' = 倒序（从多到少，默认）
  if (sortDir == 'asc') {
    rows.sort((a, b) => a['_count'].compareTo(b['_count']));
  } else {
    rows.sort((a, b) => b['_count'].compareTo(a['_count']));
  }

  final out = [];
  for (final r in rows) {
    out.add({'title': r['title'], 'subtitle': r['subtitle'], 'trailing': r['trailing']});
  }
  return jsonEncode(out);
}