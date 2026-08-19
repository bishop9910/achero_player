import 'package:flutter/material.dart';

/// 歌词显示位置（相对播放页可用空间）。
enum LyricAlignment {
  center('居中'),
  top('顶部'),
  bottom('底部');

  const LyricAlignment(this.label);
  final String label;
}

/// 循环模式。
enum RepeatMode {
  off('顺序播放', Icons.repeat),
  all('列表循环', Icons.repeat),
  one('单曲循环', Icons.repeat_one);

  const RepeatMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 主题亮度：跟随系统 / 强制浅色 / 强制深色。
enum ThemeBrightness {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const ThemeBrightness(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
        system => ThemeMode.system,
        light => ThemeMode.light,
        dark => ThemeMode.dark,
      };
}

/// 主题设置。
@immutable
class ThemeSettings {
  const ThemeSettings({
    this.seedColor = 0xFF0984E3,
    this.brightness = ThemeBrightness.dark,
    this.contrast = 0.0,
    this.backgroundImagePath,
    this.backgroundDim = 0.55,
  });

  /// 主题种子色（ARGB 32 位整型）。
  final int seedColor;

  final ThemeBrightness brightness;

  /// -1.0 ~ 1.0，用于微调明暗对比（保留扩展位）。
  final double contrast;

  /// 全局背景图片的本地路径；null 表示无背景图。
  final String? backgroundImagePath;

  /// 背景图上叠加的黑色蒙层不透明度（0.0 ~ 1.0），保证文字可读。
  final double backgroundDim;

  Color get seed => Color(seedColor);

  bool get hasBackgroundImage =>
      backgroundImagePath != null && backgroundImagePath!.isNotEmpty;

  ThemeSettings copyWith({
    int? seedColor,
    ThemeBrightness? brightness,
    double? contrast,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
    double? backgroundDim,
  }) =>
      ThemeSettings(
        seedColor: seedColor ?? this.seedColor,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        backgroundImagePath: clearBackgroundImage
            ? null
            : (backgroundImagePath ?? this.backgroundImagePath),
        backgroundDim: backgroundDim ?? this.backgroundDim,
      );

  Map<String, dynamic> toJson() => {
        'seedColor': seedColor,
        'brightness': brightness.name,
        'contrast': contrast,
        'backgroundImagePath': backgroundImagePath,
        'backgroundDim': backgroundDim,
      };

  static ThemeSettings fromJson(Map<String, dynamic> json) => ThemeSettings(
        seedColor: _jsonNum(json['seedColor'])?.toInt() ?? 0xFF0984E3,
        brightness: ThemeBrightness.values.firstWhere(
          (b) => b.name == json['brightness'],
          orElse: () => ThemeBrightness.dark,
        ),
        contrast: _jsonNum(json['contrast'])?.toDouble() ?? 0.0,
        backgroundImagePath: _jsonString(json['backgroundImagePath']),
        backgroundDim: _jsonNum(json['backgroundDim'])?.toDouble() ?? 0.55,
      );
}

/// 字体设置。
@immutable
class FontSettings {
  const FontSettings({
    this.uiFamily = '',
    this.lyricsFamily = '',
    this.uiFallback = const [
      'PingFang SC',
      'Microsoft YaHei',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
    this.lyricsScale = 1.0,
    this.fontFolders = const [],
  });

  /// 界面字体族名。空字符串表示使用平台默认。
  final String uiFamily;

  /// 歌词字体族名。空字符串表示继承 [uiFamily]。
  final String lyricsFamily;

  /// 中文字形回退列表，保证 CJK 文本在自定义西文字体下正常渲染。
  final List<String> uiFallback;

  /// 歌词字号缩放系数。
  final double lyricsScale;

  /// 运行时字体目录（放置 .ttf/.otf，启动时自动加载）。
  final List<String> fontFolders;

  FontSettings copyWith({
    String? uiFamily,
    String? lyricsFamily,
    List<String>? uiFallback,
    double? lyricsScale,
    List<String>? fontFolders,
  }) =>
      FontSettings(
        uiFamily: uiFamily ?? this.uiFamily,
        lyricsFamily: lyricsFamily ?? this.lyricsFamily,
        uiFallback: uiFallback ?? this.uiFallback,
        lyricsScale: lyricsScale ?? this.lyricsScale,
        fontFolders: fontFolders ?? this.fontFolders,
      );

  Map<String, dynamic> toJson() => {
        'uiFamily': uiFamily,
        'lyricsFamily': lyricsFamily,
        'uiFallback': uiFallback,
        'lyricsScale': lyricsScale,
        'fontFolders': fontFolders,
      };

  static FontSettings fromJson(Map<String, dynamic> json) => FontSettings(
        uiFamily: _jsonString(json['uiFamily']) ?? '',
        lyricsFamily: _jsonString(json['lyricsFamily']) ?? '',
        uiFallback: _jsonStringList(json['uiFallback']) ??
            const [
              'PingFang SC',
              'Microsoft YaHei',
              'Noto Sans CJK SC',
              'sans-serif',
            ],
        lyricsScale: _jsonNum(json['lyricsScale'])?.toDouble() ?? 1.0,
        fontFolders: _jsonStringList(json['fontFolders']) ?? const [],
      );
}

/// 歌词设置。
@immutable
class LyricSettings {
  const LyricSettings({
    this.alignment = LyricAlignment.center,
    this.verticalOffset = 0.0,
    this.fontSize = 20.0,
    this.highlightColor,
  });

  /// 歌词显示位置（顶部 / 居中 / 底部）。
  final LyricAlignment alignment;

  /// 相对对齐锚点的垂直偏移（像素，正值下移）。
  final double verticalOffset;

  /// 歌词基准字号。
  final double fontSize;

  /// 高亮行颜色（null 表示使用主题色）。
  final int? highlightColor;

  LyricSettings copyWith({
    LyricAlignment? alignment,
    double? verticalOffset,
    double? fontSize,
    int? highlightColor,
    bool clearHighlight = false,
  }) =>
      LyricSettings(
        alignment: alignment ?? this.alignment,
        verticalOffset: verticalOffset ?? this.verticalOffset,
        fontSize: fontSize ?? this.fontSize,
        highlightColor:
            clearHighlight ? null : (highlightColor ?? this.highlightColor),
      );

  Map<String, dynamic> toJson() => {
        'alignment': alignment.name,
        'verticalOffset': verticalOffset,
        'fontSize': fontSize,
        'highlightColor': highlightColor,
      };

  static LyricSettings fromJson(Map<String, dynamic> json) => LyricSettings(
        alignment: LyricAlignment.values.firstWhere(
          (a) => a.name == json['alignment'],
          orElse: () => LyricAlignment.center,
        ),
        verticalOffset: _jsonNum(json['verticalOffset'])?.toDouble() ?? 0.0,
        fontSize: _jsonNum(json['fontSize'])?.toDouble() ?? 20.0,
        highlightColor: _jsonNum(json['highlightColor'])?.toInt(),
      );
}

/// 播放行为设置。
@immutable
class PlaybackSettings {
  const PlaybackSettings({
    this.repeatMode = RepeatMode.all,
    this.shuffle = false,
    this.volume = 1.0,
    this.autoPlayNext = true,
  });

  final RepeatMode repeatMode;
  final bool shuffle;
  final double volume;
  final bool autoPlayNext;

  PlaybackSettings copyWith({
    RepeatMode? repeatMode,
    bool? shuffle,
    double? volume,
    bool? autoPlayNext,
  }) =>
      PlaybackSettings(
        repeatMode: repeatMode ?? this.repeatMode,
        shuffle: shuffle ?? this.shuffle,
        volume: volume ?? this.volume,
        autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      );

  Map<String, dynamic> toJson() => {
        'repeatMode': repeatMode.name,
        'shuffle': shuffle,
        'volume': volume,
        'autoPlayNext': autoPlayNext,
      };

  static PlaybackSettings fromJson(Map<String, dynamic> json) => PlaybackSettings(
        repeatMode: RepeatMode.values.firstWhere(
          (r) => r.name == json['repeatMode'],
          orElse: () => RepeatMode.all,
        ),
        shuffle: _jsonBool(json['shuffle']) ?? false,
        volume: _jsonNum(json['volume'])?.toDouble() ?? 1.0,
        autoPlayNext: _jsonBool(json['autoPlayNext']) ?? true,
      );
}

/// 曲库设置。
@immutable
class LibrarySettings {
  const LibrarySettings({this.folders = const []});

  /// 需要扫描的音乐目录（绝对路径）。
  final List<String> folders;

  LibrarySettings copyWith({List<String>? folders}) =>
      LibrarySettings(folders: folders ?? this.folders);

  Map<String, dynamic> toJson() => {'folders': folders};

  static LibrarySettings fromJson(Map<String, dynamic> json) => LibrarySettings(
        folders: _jsonStringList(json['folders']) ?? const [],
      );
}

/// 应用整体设置的不可变快照。
@immutable
class AppSettings {
  const AppSettings({
    this.theme = const ThemeSettings(),
    this.font = const FontSettings(),
    this.lyrics = const LyricSettings(),
    this.playback = const PlaybackSettings(),
    this.library = const LibrarySettings(),
  });

  final ThemeSettings theme;
  final FontSettings font;
  final LyricSettings lyrics;
  final PlaybackSettings playback;
  final LibrarySettings library;

  static const defaults = AppSettings();

  AppSettings copyWith({
    ThemeSettings? theme,
    FontSettings? font,
    LyricSettings? lyrics,
    PlaybackSettings? playback,
    LibrarySettings? library,
  }) =>
      AppSettings(
        theme: theme ?? this.theme,
        font: font ?? this.font,
        lyrics: lyrics ?? this.lyrics,
        playback: playback ?? this.playback,
        library: library ?? this.library,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme.toJson(),
        'font': font.toJson(),
        'lyrics': lyrics.toJson(),
        'playback': playback.toJson(),
        'library': library.toJson(),
      };

  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
        theme: ThemeSettings.fromJson(_jsonMap(json['theme']) ?? const {}),
        font: FontSettings.fromJson(_jsonMap(json['font']) ?? const {}),
        lyrics: LyricSettings.fromJson(_jsonMap(json['lyrics']) ?? const {}),
        playback:
            PlaybackSettings.fromJson(_jsonMap(json['playback']) ?? const {}),
        library:
            LibrarySettings.fromJson(_jsonMap(json['library']) ?? const {}),
      );
}

// ---------------------------------------------------------------------------
// 容错解析辅助：损坏 / 类型不符的 JSON 字段回退到默认值，而非抛异常。
// ---------------------------------------------------------------------------

num? _jsonNum(dynamic value) => value is num ? value : null;

String? _jsonString(dynamic value) => value is String ? value : null;

bool? _jsonBool(dynamic value) => value is bool ? value : null;

/// 把 JSON 列表安全转为字符串列表；非字符串元素被丢弃，非列表返回 null。
List<String>? _jsonStringList(dynamic value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : null;

Map<String, dynamic>? _jsonMap(dynamic value) =>
    value is Map<String, dynamic> ? value : null;
