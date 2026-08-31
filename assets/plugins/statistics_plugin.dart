// 运行时脚本插件示例：播放统计。
// 记录每首曲目的播放次数，并展示「单曲 / 专辑 / 播放列表」三个排行榜。
// 完整协议见 docs/RUNTIME_PLUGINS.md。
import 'dart:convert';

String manifest(Function call) {
  return jsonEncode({
    'id': 'com.achero.statistics',
    'name': '播放统计',
    'version': '1.4.0',
    'description': '记录播放次数并展示单曲、专辑、播放列表排行',
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
  final playlistsRaw = call('listPlaylists', '{}');
  var playlists = [];
  if (playlistsRaw != null) {
    playlists = jsonDecode(playlistsRaw);
  }

  final rows = [];

  // 单曲排行
  final trackRows = [];
  for (final t in tracks) {
    final id = t['id'];
    final n = counts[id] ?? 0;
    if (n > 0) {
      trackRows.add({
        'title': t['title'],
        'subtitle': t['artist'] ?? '',
        'trailing': '$n 次',
        'sortValue': n,
        'trackId': id,
        'coverPath': t['coverPath'],
        'coverUrl': t['coverUrl'],
        'action': 'play:$id',
      });
    }
  }
  if (trackRows.isNotEmpty) {
    rows.add({'header': '单曲排行'});
    for (final r in trackRows) {
      rows.add(r);
    }
  }

  // 专辑排行：把每首歌的播放次数按专辑累加。
  final albumCounts = {};
  for (final t in tracks) {
    final id = t['id'];
    final album = t['album'];
    final n = counts[id] ?? 0;
    if (album != null && n > 0) {
      albumCounts[album] = (albumCounts[album] ?? 0) + n;
    }
  }
  final albumRows = [];
  for (final key in albumCounts.keys) {
    albumRows.add({
      'title': key,
      'trailing': '${albumCounts[key]} 次',
      'sortValue': albumCounts[key],
    });
  }
  if (albumRows.isNotEmpty) {
    rows.add({'header': '专辑排行'});
    for (final r in albumRows) {
      rows.add(r);
    }
  }

  // 播放列表排行：把列表内每首歌的播放次数累加。
  final playlistCounts = {};
  for (final pl in playlists) {
    final name = pl['name'];
    final ids = pl['trackIds'];
    num total = 0;
    if (ids != null) {
      for (final tid in ids) {
        total = total + (counts[tid] ?? 0);
      }
    }
    if (total > 0) {
      playlistCounts[name] = total;
    }
  }
  final playlistRows = [];
  for (final key in playlistCounts.keys) {
    playlistRows.add({
      'title': key,
      'trailing': '${playlistCounts[key]} 次',
      'sortValue': playlistCounts[key],
    });
  }
  if (playlistRows.isNotEmpty) {
    rows.add({'header': '播放列表排行'});
    for (final r in playlistRows) {
      rows.add(r);
    }
  }

  return jsonEncode(rows);
}
