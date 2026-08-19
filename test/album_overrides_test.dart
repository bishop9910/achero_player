import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:achero_player/src/core/library/album_overrides.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> prefs() async => SharedPreferences.getInstance();

  test('设置 / 清除覆盖并持久化 round-trip', () async {
    final p = await prefs();
    final overrides = AlbumOverrides(p);

    expect(overrides.isEmpty, isTrue);
    await overrides.setOverride('t1', '新专辑');
    await overrides.setOverride('t2', '另一张');
    expect(overrides.overrideFor('t1'), '新专辑');
    expect(overrides.overrideFor('t2'), '另一张');
    expect(overrides.count, 2);

    final reloaded = AlbumOverrides(p);
    expect(reloaded.overrideFor('t1'), '新专辑');
    expect(reloaded.overrideFor('t2'), '另一张');
    expect(reloaded.count, 2);

    await reloaded.setOverride('t1', null);
    expect(reloaded.overrideFor('t1'), isNull);
    expect(reloaded.count, 1);
  });

  test('设置相同值不重复通知', () async {
    final p = await prefs();
    final overrides = AlbumOverrides(p);
    var notified = 0;
    overrides.addListener(() => notified++);

    await overrides.setOverride('t1', 'A');
    await overrides.setOverride('t1', 'A'); // no-op
    expect(notified, 1);
  });

  test('assignToAlbum 批量归类与清除', () async {
    final p = await prefs();
    final overrides = AlbumOverrides(p);

    await overrides.assignToAlbum(['a', 'b', 'c'], '合集');
    expect(overrides.overrideFor('a'), '合集');
    expect(overrides.overrideFor('b'), '合集');
    expect(overrides.overrideFor('c'), '合集');
    expect(overrides.count, 3);

    await overrides.assignToAlbum(['a', 'b'], null);
    expect(overrides.overrideFor('a'), isNull);
    expect(overrides.overrideFor('b'), isNull);
    expect(overrides.overrideFor('c'), '合集');
  });
}
