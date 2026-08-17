import 'package:flutter_test/flutter_test.dart';

import 'package:achero_player/src/core/plugins/plugin_manifest.dart';

void main() {
  group('PluginManifest', () {
    test('encode/decode round-trip', () {
      final manifest = PluginManifest({'a': true, 'b': false});
      final restored = PluginManifest.decode(manifest.encode());

      expect(restored.overrideFor('a'), isTrue);
      expect(restored.overrideFor('b'), isFalse);
      expect(restored.overrideFor('c'), isNull);
    });

    test('损坏输入回退为空清单', () {
      final restored = PluginManifest.decode('{不是合法 JSON');
      expect(restored.overrideFor('a'), isNull);
    });
  });
}
