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
    {'id': 't1', 'title': '海阔天空', 'artist': 'Beyond'},
    {'id': 't2', 'title': '光辉岁月', 'artist': 'Beyond'},
    {'id': 't3', 'title': '喜欢你', 'artist': 'Beyond'},
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

  // 排序已移到宿主侧，脚本只负责返回带 sortValue 的行。
  final rows = jsonDecode(stats.invoke('pageRows', ['desc']).toString()) as List<dynamic>;
  assert(rows.length == 2, 'expected 2 rows, got ${rows.length}');
  assert((rows[0] as Map)['title'] == '海阔天空');
  assert((rows[0] as Map)['sortValue'] == 2);
  assert((rows[1] as Map)['title'] == '光辉岁月');
  assert((rows[1] as Map)['sortValue'] == 1);
  print('[stats] pageRows OK (带 sortValue): $rows');

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
