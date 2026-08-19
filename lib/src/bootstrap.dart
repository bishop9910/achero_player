import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'core/audio/audio_engine.dart';
import 'core/audio/media_kit_engine.dart';
import 'core/download/download_manager.dart';
import 'core/library/music_library.dart';
import 'core/models/track.dart';
import 'core/platform/platform_fs_factory.dart';
import 'core/player/player_controller.dart';
import 'core/plugins/plugin_event_bus.dart';
import 'core/plugins/plugin_registry.dart';
import 'core/plugins/plugin_types.dart';
import 'core/plugins/script/script_plugin_loader.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/font_manager.dart';
import 'plugin_bootstrap.dart';

/// 启动引导：按依赖顺序构建所有服务并接线。
///
/// 这是应用唯一的「组装根」（composition root），所有对象在这里创建，
/// 通过 [AppServices] 暴露给 UI 与插件，避免散落各处的隐式单例。
Future<AppServices> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final fs = createPlatformFileSystem();
  final settings = SettingsController(prefs, AppSettings.defaults);
  final fonts = FontManager(fs);
  final library = MusicLibrary(prefs: prefs, fs: fs);
  final downloads = DownloadManager(library: library);
  final engine = MediaKitEngine();
  final player = PlayerController(
    engine: engine,
    settings: settings,
    fs: fs,
    library: library,
  );
  final events = PluginEventBus();
  final plugins = PluginRegistry(prefs);

  final services = AppServices(
    prefs: prefs,
    settings: settings,
    fonts: fonts,
    fs: fs,
    library: library,
    engine: engine,
    player: player,
    events: events,
    plugins: plugins,
    downloads: downloads,
  );

  // 运行时字体：默认数据目录 + 用户配置目录。
  final defaultFontDir = await _defaultFontDirectory();
  await fonts.loadFromDirectories([
    ?defaultFontDir,
    ...settings.settings.font.fontFolders,
  ]);

  // 注册并启用插件：编译侧插件（plugin_bootstrap.dart）+ 运行时脚本插件。
  registerAllPlugins(plugins);
  await ScriptPluginLoader(fs: fs).loadInto(plugins);
  await plugins.initialize((plugin) => _contextFor(plugin, services));

  // 把核心控制器的变化桥接为插件事件。
  _wireEvents(services);

  return services;
}

PluginContext _contextFor(AcheroPlugin plugin, AppServices services) {
  return PluginContext(
    pluginId: plugin.id,
    settings: services.settings,
    player: services.player,
    library: services.library,
    fonts: services.fonts,
    fs: services.fs,
    events: services.events,
    downloads: services.downloads,
    prefs: PluginPrefs(services.prefs, plugin.id),
    log: (message) => debugPrint('[${plugin.id}] $message'),
  );
}

Future<String?> _defaultFontDirectory() async {
  if (kIsWeb) return null;
  try {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'fonts');
  } catch (_) {
    return null;
  }
}

/// 把 [PlayerController] / [MusicLibrary] 的变化桥接为插件事件。
void _wireEvents(AppServices services) {
  final player = services.player;
  final events = services.events;

  Track? lastTrack;
  PlaybackStatus? lastStatus;
  Duration lastPosition = Duration.zero;

  player.addListener(() {
    final track = player.currentTrack;
    if (track != null && !identical(track, lastTrack)) {
      lastTrack = track;
      events.emitTrackChanged(track);
    }
    if (player.status != lastStatus) {
      lastStatus = player.status;
      events.emitStateChanged(player.status);
      if (player.status.isPlaying && track != null) {
        events.emitTrackStarted(track);
      }
    }
    if (player.position != lastPosition) {
      lastPosition = player.position;
      events.emitPositionChanged(player.position);
    }
  });

  services.library
      .addListener(() => events.emitLibraryChanged(services.library.trackCount));
}
