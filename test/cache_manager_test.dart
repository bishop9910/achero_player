import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:achero_player/src/core/cache/cache_manager.dart';
import 'package:achero_player/src/core/platform/platform_filesystem.dart';

/// 内存版 [PlatformFileSystem]，用于测试缓存逻辑而不触碰真实磁盘。
class _FakeFs implements PlatformFileSystem {
  final Map<String, Uint8List> files = {};
  final Map<String, DateTime> mtimes = {};

  @override
  bool get supportsDirectoryScan => true;

  @override
  Future<List<LocalAudioFile>> listAudioFiles(String directory) async => const [];

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<Uint8List?> readBytes(String path) async => files[path];

  @override
  Future<Uint8List?> readHeadBytes(String path, {int maxBytes = 16}) async {
    final b = files[path];
    if (b == null) return null;
    final n = b.length < maxBytes ? b.length : maxBytes;
    return b.sublist(0, n);
  }

  @override
  Future<List<String>> listFontFiles(String directory) async => const [];

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    files[path] = Uint8List.fromList(bytes);
    mtimes[path] = DateTime.now();
  }

  @override
  Future<void> deleteFile(String path) async {
    files.remove(path);
    mtimes.remove(path);
  }

  @override
  Future<void> ensureDirectory(String path) async {}

  @override
  Future<DateTime?> lastModified(String path) async => mtimes[path];

  @override
  Future<List<CacheFileInfo>> listFiles(String directory) async {
    final fwd = directory.endsWith('/') ? directory : '$directory/';
    final back = directory.endsWith('\\') ? directory : '$directory\\';
    return files.keys
        .where((p) => p.startsWith(fwd) || p.startsWith(back))
        .map((p) => CacheFileInfo(
              path: p,
              lastModified: mtimes[p] ?? DateTime.now(),
              size: files[p]!.length,
            ))
        .toList(growable: false);
  }

  /// 把某个文件的时间拨到 [age] 之前（用于模拟过期）。
  void age(String nameContains, Duration age) {
    final path = files.keys.firstWhere((p) => p.contains(nameContains));
    mtimes[path] = DateTime.now().subtract(age);
  }
}

void main() {
  group('CacheManager', () {
    test('JSON 元数据读写与 TTL 过期', () async {
      final fs = _FakeFs();
      final cache = CacheManager(fs: fs, rootDir: 'cache', ttl: const Duration(days: 7));
      await cache.init();

      await cache.putJson('album-1', '{"name":"x"}');
      expect(await cache.getJson('album-1'), '{"name":"x"}');

      fs.age('album-1', const Duration(days: 8));
      expect(await cache.getJson('album-1'), isNull);
    });

    test('音频缓存写入与读取', () async {
      final fs = _FakeFs();
      final cache = CacheManager(fs: fs, rootDir: 'cache');
      await cache.init();

      final bytes = Uint8List.fromList([1, 2, 3]);
      final path = await cache.putAudio('s1', 'mp3', bytes);

      expect(await cache.hasAudio('s1', 'mp3'), isTrue);
      expect(await cache.getAudio('s1', 'mp3'), [1, 2, 3]);
      expect(path, endsWith('.mp3'));
    });

    test('cleanup 删除过期文件、保留新鲜文件', () async {
      final fs = _FakeFs();
      final cache = CacheManager(fs: fs, rootDir: 'cache', ttl: const Duration(days: 7));
      await cache.init();

      await cache.putJson('old', '1');
      await cache.putJson('fresh', '2');
      await cache.putAudio('old-a', 'mp3', Uint8List.fromList([1]));

      fs.age('old', const Duration(days: 30));
      fs.age('old-a', const Duration(days: 30));

      final deleted = await cache.cleanup();
      expect(deleted, 2);
      expect(await cache.getJson('fresh'), '2');
      expect(await cache.hasAudio('old-a', 'mp3'), isFalse);
    });

    test('clearAll 清空所有缓存', () async {
      final fs = _FakeFs();
      final cache = CacheManager(fs: fs, rootDir: 'cache');
      await cache.init();

      await cache.putJson('a', '1');
      await cache.putAudio('b', 'mp3', Uint8List.fromList([1]));

      final deleted = await cache.clearAll();
      expect(deleted, 2);
      expect(fs.files, isEmpty);
    });

    test('totalSize 统计缓存大小', () async {
      final fs = _FakeFs();
      final cache = CacheManager(fs: fs, rootDir: 'cache');
      await cache.init();

      await cache.putAudio('a', 'mp3', Uint8List.fromList([1, 2, 3, 4]));
      await cache.putJson('b', '12345');

      expect(await cache.totalSize(), 9); // 4 字节音频 + 5 字节 JSON
    });
  });
}
