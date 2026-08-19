import 'package:shared_preferences/shared_preferences.dart';

import 'core/audio/audio_engine.dart';
import 'core/download/download_manager.dart';
import 'core/library/album_overrides.dart';
import 'core/library/library_catalog.dart';
import 'core/library/music_library.dart';
import 'core/platform/platform_filesystem.dart';
import 'core/player/player_controller.dart';
import 'core/plugins/plugin_event_bus.dart';
import 'core/plugins/plugin_registry.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/font_manager.dart';

/// 应用服务容器：持有所有可注入的核心服务。
///
/// 通过 `provider` 注入 widget 树，任何界面通过
/// `context.read<AppServices>().player` 即可访问。
class AppServices {
  const AppServices({
    required this.prefs,
    required this.settings,
    required this.fonts,
    required this.fs,
    required this.library,
    required this.albumOverrides,
    required this.catalog,
    required this.engine,
    required this.player,
    required this.events,
    required this.plugins,
    required this.downloads,
  });

  final SharedPreferences prefs;
  final SettingsController settings;
  final FontManager fonts;
  final PlatformFileSystem fs;
  final MusicLibrary library;
  final AlbumOverrides albumOverrides;
  final LibraryCatalog catalog;
  final AudioEngine engine;
  final PlayerController player;
  final PluginEventBus events;
  final PluginRegistry plugins;
  final DownloadManager downloads;
}
