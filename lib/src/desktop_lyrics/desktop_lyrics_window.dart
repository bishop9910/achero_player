import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面歌词子窗口的根应用（独立 Flutter 引擎）。
class DesktopLyricsWindowApp extends StatelessWidget {
  const DesktopLyricsWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DesktopLyricsWindow(),
    );
  }
}

/// 无边框、透明、置顶的歌词条。通过 [WindowController] 接收主窗口推送的
/// 歌词与外观配置；使用原生拖拽（`startDragging`）避免闪烁与低灵敏度。
class DesktopLyricsWindow extends StatefulWidget {
  const DesktopLyricsWindow({super.key});

  @override
  State<DesktopLyricsWindow> createState() => _DesktopLyricsWindowState();
}

class _DesktopLyricsWindowState extends State<DesktopLyricsWindow> {
  String _title = '';
  String _artist = '';
  String _line = '';
  String _next = '';
  bool _playing = false;

  double _fontSize = 30;
  bool _showNext = true;
  double _opacity = 0.87;
  int _accent = 0xFF0984E3;

  @override
  void initState() {
    super.initState();
    _initWindow();
    _setupChannel();
  }

  Future<void> _initWindow() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(620, 210),
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setAlignment(Alignment.bottomCenter);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  Future<void> _setupChannel() async {
    final controller = await WindowController.fromCurrentEngine();
    await controller.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'update':
          final map = jsonDecode(call.arguments as String) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _title = map['title']?.toString() ?? '';
              _artist = map['artist']?.toString() ?? '';
              _line = map['line']?.toString() ?? '';
              _next = map['next']?.toString() ?? '';
              _playing = map['playing'] == true;
            });
          }
          return null;
        case 'config':
          final map = jsonDecode(call.arguments as String) as Map<String, dynamic>;
          final clickThrough = map['clickThrough'] as bool? ?? false;
          final alwaysOnTop = map['alwaysOnTop'] as bool? ?? true;
          if (mounted) {
            setState(() {
              _fontSize = (map['fontSize'] as num?)?.toDouble() ?? 30;
              _showNext = map['showNext'] as bool? ?? true;
              _opacity = (map['opacity'] as num?)?.toDouble() ?? 0.87;
              _accent = (map['accent'] as num?)?.toInt() ?? 0xFF0984E3;
            });
          }
          await windowManager.setIgnoreMouseEvents(clickThrough);
          await windowManager.setAlwaysOnTop(alwaysOnTop);
          return null;
        case 'close':
          await windowManager.close();
          return null;
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_accent);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF14171C).withValues(alpha: _opacity),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Column(
            children: [
              if (_title.isNotEmpty)
                Text(
                  '$_title${_artist.isNotEmpty ? ' · $_artist' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: Text(
                    _line.isEmpty ? '♪ 暂无歌词 ♪' : _line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: _playing ? _fontSize : _fontSize * 0.86,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
              if (_showNext && _next.isNotEmpty)
                Text(
                  _next,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white30, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
