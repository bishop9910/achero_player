import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/plugins/plugin_types.dart';
import '../desktop_lyrics/desktop_lyrics_constants.dart';

/// 内置插件：桌面歌词独立窗口（仅 Windows / Linux / macOS）。
///
/// 用 `desktop_multi_window` 创建独立的无边框、置顶、透明子窗口，用
/// `window_manager` 设置窗口属性，并把歌词行与外观配置实时推送到子窗口。
class DesktopLyricsPlugin extends AcheroPlugin {
  @override
  String get id => 'com.achero.desktopLyrics';

  @override
  String get name => '桌面歌词';

  @override
  String get version => '1.1.0';

  @override
  String get description => '在独立的置顶窗口中显示当前歌词，可自定义外观。';

  @override
  IconData get icon => Icons.subtitles_outlined;

  PluginContext? _context;
  WindowController? _window;
  final ValueNotifier<bool> _enabled = ValueNotifier(false);
  String _lastKey = '';

  bool get _supported {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    _context = context;
    final wasEnabled = context.prefs.getBool('enabled') ?? false;
    _enabled.value = wasEnabled;
    if (wasEnabled && _supported) {
      unawaited(enable());
    }
  }

  @override
  Future<void> onUnload() async {
    await disable();
    _context = null;
  }

  Future<void> enable() async {
    final context = _context;
    if (context == null || _window != null || !_supported) return;
    try {
      final window = await WindowController.create(WindowConfiguration(
        arguments: kDesktopLyricsWindowArg,
        hiddenAtLaunch: true,
      ));
      _window = window;
      await window.show();
      _enabled.value = true;
      await context.prefs.setBool('enabled', true);
      context.player.addListener(_forward);
      pushConfig();
      _forward();
      context.log('桌面歌词窗口已打开');
    } catch (error) {
      _window = null;
      context.log('打开桌面歌词窗口失败：$error');
    }
  }

  Future<void> disable() async {
    final context = _context;
    context?.player.removeListener(_forward);
    final window = _window;
    _window = null;
    _enabled.value = false;
    await context?.prefs.setBool('enabled', false);
    if (window != null) {
      try {
        await window.invokeMethod('close');
      } catch (_) {
        // 窗口可能已被手动关闭。
      }
    }
  }

  /// 读取外观配置并推送到子窗口。
  void pushConfig() {
    final prefs = _context?.prefs;
    _window?.invokeMethod(
      'config',
      jsonEncode({
        'fontSize': prefs?.getDouble('fontSize') ?? 30.0,
        'showNext': prefs?.getBool('showNext') ?? true,
        'opacity': prefs?.getDouble('opacity') ?? 0.87,
        'accent': prefs?.getInt('accent') ?? 0xFF0984E3,
        'clickThrough': prefs?.getBool('clickThrough') ?? false,
        'alwaysOnTop': prefs?.getBool('alwaysOnTop') ?? true,
      }),
    );
  }

  /// 保存一项外观配置并立即推送到子窗口。
  Future<void> setConfigValue(String key, Object value) async {
    final prefs = _context?.prefs;
    if (prefs == null) return;
    if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
    pushConfig();
  }

  /// 当前歌词行变化 / 曲目变化 / 播放状态变化时，推送到子窗口。
  void _forward() {
    final context = _context;
    final window = _window;
    if (context == null || window == null) return;

    final player = context.player;
    final track = player.currentTrack;
    final lyrics = player.lyrics;
    final active = lyrics?.activeIndexAt(player.position) ?? -1;
    final line = (lyrics != null && active >= 0 && active < lyrics.lines.length)
        ? lyrics.lines[active].text
        : '';
    final next =
        (lyrics != null && active >= 0 && active + 1 < lyrics.lines.length)
            ? lyrics.lines[active + 1].text
            : '';

    final key = '${track?.id}|$active|${player.isPlaying}';
    if (key == _lastKey) return;
    _lastKey = key;

    window.invokeMethod(
      'update',
      jsonEncode({
        'title': track?.title ?? '',
        'artist': track?.artist ?? '',
        'line': line,
        'next': next,
        'playing': player.isPlaying,
      }),
    );
  }

  @override
  List<PluginSettingsSection> get settingsSections => [
        PluginSettingsSection(
          id: '$id.settings',
          title: name,
          builder: (context) => [
            if (_supported)
              ValueListenableBuilder<bool>(
                valueListenable: _enabled,
                builder: (context, enabled, _) => SwitchListTile(
                  secondary: const Icon(Icons.subtitles_outlined),
                  title: const Text('桌面歌词独立窗口'),
                  subtitle: Text(enabled ? '已开启（置顶悬浮窗）' : '在屏幕下方显示置顶歌词'),
                  value: enabled,
                  onChanged: (v) => v ? enable() : disable(),
                ),
              )
            else
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('仅桌面端支持'),
                subtitle: Text('桌面歌词独立窗口需要 Windows / Linux / macOS'),
              ),
            if (_supported) _LyricsSettings(plugin: this),
          ],
        ),
      ];
}

/// 外观自定义：字号 / 下一行 / 背景不透明度 / 高亮色 / 穿透 / 置顶。
class _LyricsSettings extends StatefulWidget {
  const _LyricsSettings({required this.plugin});

  final DesktopLyricsPlugin plugin;

  @override
  State<_LyricsSettings> createState() => _LyricsSettingsState();
}

class _LyricsSettingsState extends State<_LyricsSettings> {
  static const List<int> _accents = [
    0xFF0984E3, 0xFF6C5CE7, 0xFF00B894, 0xFFE84393, 0xFFFFFFFF,
  ];

  late double _fontSize;
  late bool _showNext;
  late double _opacity;
  late int _accent;
  late bool _clickThrough;
  late bool _alwaysOnTop;

  @override
  void initState() {
    super.initState();
    final prefs = widget.plugin._context?.prefs;
    _fontSize = prefs?.getDouble('fontSize') ?? 30.0;
    _showNext = prefs?.getBool('showNext') ?? true;
    _opacity = prefs?.getDouble('opacity') ?? 0.87;
    _accent = prefs?.getInt('accent') ?? 0xFF0984E3;
    _clickThrough = prefs?.getBool('clickThrough') ?? false;
    _alwaysOnTop = prefs?.getBool('alwaysOnTop') ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1),
        ListTile(
          title: const Text('歌词字号'),
          subtitle: SizedBox(
            height: 36,
            child: Slider(
              value: _fontSize.clamp(18, 48),
              min: 18,
              max: 48,
              divisions: 30,
              label: _fontSize.round().toString(),
              onChanged: (v) {
                setState(() => _fontSize = v);
                widget.plugin.setConfigValue('fontSize', v);
              },
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          title: const Text('背景不透明度'),
          subtitle: SizedBox(
            height: 36,
            child: Slider(
              value: _opacity.clamp(0.2, 1.0),
              min: 0.2,
              max: 1.0,
              divisions: 16,
              label: '${(_opacity * 100).round()}%',
              onChanged: (v) {
                setState(() => _opacity = v);
                widget.plugin.setConfigValue('opacity', v);
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('高亮颜色'),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final color in _accents)
                    GestureDetector(
                      onTap: () {
                        setState(() => _accent = color);
                        widget.plugin.setConfigValue('accent', color);
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accent == color
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('显示下一行歌词'),
          value: _showNext,
          onChanged: (v) {
            setState(() => _showNext = v);
            widget.plugin.setConfigValue('showNext', v);
          },
        ),
        SwitchListTile(
          title: const Text('鼠标穿透（不挡操作）'),
          subtitle: const Text('开启后歌词窗不响应鼠标，需在设置里关闭'),
          value: _clickThrough,
          onChanged: (v) {
            setState(() => _clickThrough = v);
            widget.plugin.setConfigValue('clickThrough', v);
          },
        ),
        SwitchListTile(
          title: const Text('始终置顶'),
          value: _alwaysOnTop,
          onChanged: (v) {
            setState(() => _alwaysOnTop = v);
            widget.plugin.setConfigValue('alwaysOnTop', v);
          },
        ),
      ],
    );
  }
}
