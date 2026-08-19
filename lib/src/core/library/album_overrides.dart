import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 专辑归类的用户手动覆盖：`trackId -> 专辑名`。
///
/// 默认（无覆盖时）按曲目自带的 `album` 字段自动归类；当曲库中出现真正
/// 重名的专辑被合并到同一组时，用户可在此为某些曲目指定新的专辑名，从而
/// 把它们拆分 / 归并到想要的专辑。数据以 JSON 持久化到 SharedPreferences，
/// 键值仅记录「被改动过」的曲目——未改动的曲目始终回退到自动识别。
class AlbumOverrides extends ChangeNotifier {
  AlbumOverrides(this._prefs) {
    _restore();
  }

  static const String _key = 'achero.library.albumOverrides.v1';

  final SharedPreferences _prefs;
  final Map<String, String> _byTrackId = {};

  /// 某曲目的专辑覆盖名；无覆盖返回 null（即自动归类）。
  String? overrideFor(String trackId) => _byTrackId[trackId];

  /// 是否存在覆盖。
  bool get isEmpty => _byTrackId.isEmpty;

  int get count => _byTrackId.length;

  /// 为曲目设置专辑覆盖名；[album] 为空 / null 表示清除覆盖，回到自动归类。
  Future<void> setOverride(String trackId, String? album) async {
    final name = album?.trim() ?? '';
    if (name.isEmpty) {
      if (_byTrackId.remove(trackId) == null) return;
    } else {
      if (_byTrackId[trackId] == name) return;
      _byTrackId[trackId] = name;
    }
    await _persist();
    notifyListeners();
  }

  /// 批量把若干曲目归到同一专辑名；[album] 为空 / null 表示清除覆盖。
  Future<void> assignToAlbum(Iterable<String> trackIds, String? album) async {
    final name = album?.trim() ?? '';
    var changed = false;
    for (final id in trackIds) {
      if (name.isEmpty) {
        if (_byTrackId.remove(id) != null) changed = true;
      } else {
        if (_byTrackId[id] != name) {
          _byTrackId[id] = name;
          changed = true;
        }
      }
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _byTrackId
        ..clear()
        ..addEntries(decoded.entries
            .map((e) => MapEntry(e.key, e.value.toString())));
    } catch (_) {
      // 忽略损坏的覆盖数据。
    }
  }

  Future<void> _persist() => _prefs.setString(_key, jsonEncode(_byTrackId));
}
