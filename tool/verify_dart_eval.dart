// ignore_for_file: avoid_print
// 运行时脚本插件引擎的端到端验证（纯 Dart，`dart run tool/verify_dart_eval.dart`）。
// 加载 assets/plugins 下的真实脚本，用 mock 宿主回调跑通「统计」与「主题预设」两个插件。
import 'dart:convert';
import 'dart:io';

import 'package:achero_player/src/core/plugins/script/compiled_script.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';

void main() {
  // ── 统计插件 ────────────────────────────────────────────────────────────
  final statsSource = File('assets/plugins/statistics_plugin.dart').readAsStringSync();
  final statsPrefs = <String, String>{};
  final statsTracks = [
    {'id': 't1', 'title': '海阔天空', 'artist': 'Beyond', 'album': '乐与怒'},
    {'id': 't2', 'title': '光辉岁月', 'artist': 'Beyond', 'album': '命运派对'},
    {'id': 't3', 'title': '喜欢你', 'artist': 'Beyond', 'album': '秘密警察'},
  ];
  final statsPlaylists = [
    {'name': '我的最爱', 'trackIds': ['t1', 't2']},
  ];

  $Value? statsHost(Runtime rt, $Value? target, List<$Value?> args) {
    final method = args[0]!.$reified.toString();
    final params = jsonDecode(args[1]!.$reified.toString()) as Map<String, dynamic>;
    switch (method) {
      case 'prefsGet':
        return statsPrefs.containsKey(params['key']) ? $String(statsPrefs[params['key']]!) : $null();
      case 'prefsSet':
        statsPrefs[params['key'].toString()] = params['value'].toString();
        return $null();
      case 'listTracks':
        return $String(jsonEncode(statsTracks));
      case 'listPlaylists':
        return $String(jsonEncode(statsPlaylists));
      default:
        throw StateError('unexpected method: $method');
    }
  }

  final stats = CompiledScript.compile(statsSource, hostCall: $Closure(statsHost));

  final manifest = jsonDecode(stats.invoke('manifest').toString()) as Map<String, dynamic>;
  assert(manifest['id'] == 'com.achero.statistics');
  assert((manifest['events'] as List).contains('trackStarted'));
  assert((manifest['page'] as Map)['sort'] == true);
  print('[stats] manifest OK: ${manifest['name']}');

  // 模拟两次播放事件
  stats.invoke('onEvent', ['trackStarted', jsonEncode({'id': 't1', 'title': '海阔天空'})]);
  stats.invoke('onEvent', ['trackStarted', jsonEncode({'id': 't1', 'title': '海阔天空'})]);
  stats.invoke('onEvent', ['trackStarted', jsonEncode({'id': 't2', 'title': '光辉岁月'})]);

  // 排序移到宿主侧；脚本返回「分组标题 + 带 sortValue 的行」。
  final rows = (jsonDecode(stats.invoke('pageRows', ['desc']).toString()) as List<dynamic>)
      .cast<Map>();
  assert(rows.length == 8, 'expected 8 rows, got ${rows.length}');
  assert(rows[0]['header'] == '单曲排行');
  assert(rows[1]['title'] == '海阔天空' && rows[1]['sortValue'] == 2);
  assert(rows[1]['trackId'] == 't1' && rows[1]['action'] == 'play:t1');
  assert(rows[3]['header'] == '专辑排行');
  assert(rows[4]['title'] == '乐与怒' && rows[4]['sortValue'] == 2);
  assert(rows[6]['header'] == '播放列表排行');
  assert(rows[7]['title'] == '我的最爱' && rows[7]['sortValue'] == 3);
  print('[stats] pageRows OK (单曲/专辑/播放列表分组): $rows');

  // ── 主题预设插件 ────────────────────────────────────────────────────────
  final presetSource = File('assets/plugins/theme_presets_plugin.dart').readAsStringSync();
  int? appliedSeed;

  $Value? presetHost(Runtime rt, $Value? target, List<$Value?> args) {
    final method = args[0]!.$reified.toString();
    final params = jsonDecode(args[1]!.$reified.toString()) as Map<String, dynamic>;
    switch (method) {
      case 'setSeedColor':
        appliedSeed = (params['argb'] as num).toInt();
        return $null();
      default:
        throw StateError('unexpected method: $method');
    }
  }

  final presets = CompiledScript.compile(presetSource, hostCall: $Closure(presetHost));

  final presetManifest = jsonDecode(presets.invoke('manifest').toString()) as Map<String, dynamic>;
  assert(presetManifest['settings'] != null);
  print('[presets] manifest OK: ${presetManifest['name']}');

  final tiles = jsonDecode(presets.invoke('settingsTiles').toString()) as List<dynamic>;
  assert(tiles.length == 5, 'expected 5 tiles, got ${tiles.length}');
  assert((tiles[0] as Map)['color'] == 0xFF0984E3, 'first tile should carry its color');
  print('[presets] settingsTiles OK (${tiles.length} 项，含颜色)');

  // 点第一个预设（海洋蓝 0xFF0984E3，默认风格）
  final action = (tiles[0] as Map)['action'] as String;
  presets.invoke('onSettingsAction', [action]);
  assert(appliedSeed == 0xFF0984E3, 'expected seed 0xFF0984E3, got $appliedSeed');
  print('[presets] onSettingsAction OK -> seed=0x${appliedSeed!.toRadixString(16)}');

  print('\nALL OK');
}
