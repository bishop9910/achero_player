import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// 由设置快照构建 Material 主题。
///
/// 主题完全由 [ThemeSettings] 与 [FontSettings] 驱动，改动设置即可即时
/// 重绘整个应用：种子色、明暗模式、字体族、歌词字体均在此统一装配。
class ThemeFactory {
  const ThemeFactory._();

  static ThemeData light(AppSettings settings) =>
      _build(settings, Brightness.light);

  static ThemeData dark(AppSettings settings) =>
      _build(settings, Brightness.dark);

  static ThemeData _build(AppSettings settings, Brightness brightness) {
    final theme = settings.theme;
    final font = settings.font;
    final scheme = ColorScheme.fromSeed(
      seedColor: theme.seed,
      brightness: brightness,
    );

    final uiFamily = _familyOrNull(font.uiFamily);
    final fallback = font.uiFallback;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // 轻量页面过渡：默认的缩放过渡（Zoom）在透明背景/壁纸下容易掉帧，
      // 换成「淡入 + 轻微上移」，开销小很多。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = base.textTheme.apply(
      fontFamily: uiFamily,
      fontFamilyFallback: fallback,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
    );
  }

  /// 解析歌词字体：优先歌词专属字体，否则回退到界面字体。
  static TextStyle lyricTextStyle(AppSettings settings, Color color, double size) {
    final font = settings.font;
    final family = font.lyricsFamily.isNotEmpty
        ? font.lyricsFamily
        : (font.uiFamily.isNotEmpty ? font.uiFamily : null);
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: font.uiFallback,
      color: color,
      fontSize: size,
      height: 1.5,
    );
  }

  static String? _familyOrNull(String family) =>
      family.isEmpty ? null : family;
}
