import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'src/achero_app.dart';
import 'src/bootstrap.dart';
import 'src/desktop_lyrics/desktop_lyrics_constants.dart';
import 'src/desktop_lyrics/desktop_lyrics_window.dart';

/// Achero Player 入口。
///
/// 桌面端多窗口：若当前引擎是「桌面歌词」子窗口，则只运行歌词 UI，
/// 否则运行完整应用。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面歌词子窗口不播放音频，绝不能初始化 media_kit/libmpv：
  // 多窗口 = 多 isolate，重复初始化会干扰主窗口的 libmpv，导致播放全部失败。
  if (await _isDesktopLyricsWindow()) {
    runApp(const DesktopLyricsWindowApp());
    return;
  }

  MediaKit.ensureInitialized();
  await _configureMainWindow();
  final services = await bootstrap();
  runApp(AcheroApp(services: services));
}

/// 桌面端给主窗口设置最小尺寸，避免缩太小导致左侧导航栏被切换成底部导航。
Future<void> _configureMainWindow() async {
  if (kIsWeb) return;
  final platform = defaultTargetPlatform;
  if (platform != TargetPlatform.windows &&
      platform != TargetPlatform.linux &&
      platform != TargetPlatform.macOS) {
    return;
  }
  try {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(720, 480));
  } catch (_) {
    // 非桌面端或窗口管理器不可用时忽略。
  }
}

Future<bool> _isDesktopLyricsWindow() async {
  if (kIsWeb) return false;
  final platform = defaultTargetPlatform;
  if (platform != TargetPlatform.windows &&
      platform != TargetPlatform.linux &&
      platform != TargetPlatform.macOS) {
    return false;
  }
  try {
    final controller = await WindowController.fromCurrentEngine();
    return controller.arguments == kDesktopLyricsWindowArg;
  } catch (_) {
    return false;
  }
}
