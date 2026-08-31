import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'core/app_info.dart';
import 'core/download/download_manager.dart';
import 'core/library/album_overrides.dart';
import 'core/library/library_catalog.dart';
import 'core/library/music_library.dart';
import 'core/player/player_controller.dart';
import 'core/plugins/plugin_registry.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/font_manager.dart';
import 'core/theme/theme_factory.dart';
import 'ui/common/version_dialog.dart';
import 'ui/common/wallpaper.dart';
import 'ui/shell/root_shell.dart';

/// 应用根 widget：注入服务并装配主题。
class AcheroApp extends StatelessWidget {
  const AcheroApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<SettingsController>.value(value: services.settings),
        ChangeNotifierProvider<MusicLibrary>.value(value: services.library),
        ChangeNotifierProvider<AlbumOverrides>.value(value: services.albumOverrides),
        ChangeNotifierProvider<LibraryCatalog>.value(value: services.catalog),
        ChangeNotifierProvider<PlayerController>.value(value: services.player),
        ChangeNotifierProvider<PluginRegistry>.value(value: services.plugins),
        ChangeNotifierProvider<FontManager>.value(value: services.fonts),
        ChangeNotifierProvider<DownloadManager>.value(value: services.downloads),
      ],
      child: _AppBuilder(prefs: services.prefs),
    );
  }
}

class _AppBuilder extends StatefulWidget {
  const _AppBuilder({required this.prefs});

  final SharedPreferences prefs;

  @override
  State<_AppBuilder> createState() => _AppBuilderState();
}

class _AppBuilderState extends State<_AppBuilder> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowChangelog());
  }

  /// 首次安装或版本升级后，自动弹出一次当前版本的更新日志；之后不再自动弹出。
  Future<void> _maybeShowChangelog() async {
    if (!mounted || !AppInfo.shouldAutoShow(widget.prefs)) return;
    await AppInfo.markShown(widget.prefs);
    if (!mounted) return;
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext != null && navigatorContext.mounted) {
      await showVersionDialog(navigatorContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final theme = settings.theme;
    final fs = context.read<AppServices>().fs;
    final hasBackground = theme.hasBackgroundImage;

    // 有背景图时让 Scaffold 透明，露出底下的壁纸。
    ThemeData transparentScaffold(ThemeData t) => hasBackground
        ? t.copyWith(scaffoldBackgroundColor: Colors.transparent)
        : t;

    return MaterialApp(
      title: 'Achero Player',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: transparentScaffold(ThemeFactory.light(settings)),
      darkTheme: transparentScaffold(ThemeFactory.dark(settings)),
      themeMode: theme.brightness.themeMode,
      builder: (context, child) {
        if (!hasBackground) return child ?? const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            // RepaintBoundary：把「壁纸 + 蒙层」缓存为独立图层。路由过渡动画时
            // 背景不再每帧重绘，避免上一页短暂停留的卡顿。
            RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WallpaperImage(path: theme.backgroundImagePath!, fs: fs),
                  ColoredBox(
                    color: Colors.black.withValues(alpha: theme.backgroundDim),
                  ),
                ],
              ),
            ),
            child ?? const SizedBox.shrink(),
          ],
        );
      },
      home: const RootShell(),
    );
  }
}
