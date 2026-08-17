import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// 设置仓库：负责 [AppSettings] 的加载、持久化与变更通知。
///
/// 它是响应式的（`ChangeNotifier`），UI 通过 `context.watch<SettingsController>()`
/// 订阅；任何设置变更都会即时落盘并刷新依赖它的界面。
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs, this._initial);

  static const String _storageKey = 'achero.settings.v1';

  final SharedPreferences _prefs;
  final AppSettings _initial;

  late AppSettings _settings = _load();
  AppSettings get settings => _settings;

  AppSettings _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return _initial;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (_) {
      return _initial;
    }
  }

  /// 覆盖整个设置快照并持久化。
  void update(AppSettings next) {
    if (next == _settings) return;
    _settings = next;
    _persist();
    notifyListeners();
  }

  void updateTheme(ThemeSettings value) =>
      update(_settings.copyWith(theme: value));

  void updateFont(FontSettings value) => update(_settings.copyWith(font: value));

  void updateLyrics(LyricSettings value) =>
      update(_settings.copyWith(lyrics: value));

  void updatePlayback(PlaybackSettings value) =>
      update(_settings.copyWith(playback: value));

  void updateLibrary(LibrarySettings value) =>
      update(_settings.copyWith(library: value));

  void _persist() {
    _prefs.setString(_storageKey, jsonEncode(_settings.toJson()));
  }
}
