import 'package:flutter_test/flutter_test.dart';

import 'package:achero_player/src/core/settings/app_settings.dart';

void main() {
  group('AppSettings 序列化', () {
    test('默认设置 round-trip', () {
      final settings = AppSettings.defaults;
      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.theme.seedColor, settings.theme.seedColor);
      expect(restored.theme.brightness, settings.theme.brightness);
      expect(restored.lyrics.alignment, settings.lyrics.alignment);
      expect(restored.lyrics.fontSize, settings.lyrics.fontSize);
      expect(restored.font.uiFallback, settings.font.uiFallback);
      expect(restored.playback.repeatMode, settings.playback.repeatMode);
    });

    test('自定义歌词设置 round-trip', () {
      final settings = AppSettings.defaults.copyWith(
        lyrics: const LyricSettings(
          alignment: LyricAlignment.bottom,
          verticalOffset: -32,
          fontSize: 26,
          highlightColor: 0xFFE84393,
        ),
      );
      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.lyrics.alignment, LyricAlignment.bottom);
      expect(restored.lyrics.verticalOffset, -32);
      expect(restored.lyrics.fontSize, 26);
      expect(restored.lyrics.highlightColor, 0xFFE84393);
    });

    test('损坏的 JSON 回退到默认值', () {
      final restored = AppSettings.fromJson({
        'theme': {'seedColor': 'not-a-number'},
        'lyrics': {'alignment': '不存在的枚举'},
      });
      expect(restored.theme.seedColor, 0xFF0984E3);
      expect(restored.lyrics.alignment, LyricAlignment.center);
    });
  });
}
