import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../platform/platform_filesystem.dart';

/// 磁盘缓存管理器：缓存音频文件与 JSON 元数据，支持 TTL 过期与整体清理。
///
/// 目录结构：
/// ```
/// <rootDir>/
///   audio/   # 音频文件：<id>.<ext>
///   json/    # 元数据：<key>.json
/// ```
/// 过期判定基于文件**最后写入时间**（绝对 TTL）：`now - mtime > ttl` 即视为过期。
/// 所有磁盘访问经由 [PlatformFileSystem]，因此在 Web 端自然退化为不可用
/// （由调用方按 `supportsDirectoryScan` 决定是否启用）。
class CacheManager {
  CacheManager({
    required PlatformFileSystem fs,
    required String rootDir,
    this.ttl = const Duration(days: 7),
  })  : _fs = fs,
        _rootDir = rootDir;

  final PlatformFileSystem _fs;
  final String _rootDir;

  /// 默认过期时长（`getJson` 与 `cleanup` 的默认值）。可变，便于插件运行时调整。
  Duration ttl;

  String get rootDir => _rootDir;
  String get _audioDir => p.join(_rootDir, 'audio');
  String get _jsonDir => p.join(_rootDir, 'json');

  /// 确保缓存目录存在。
  Future<void> init() async {
    await _fs.ensureDirectory(_audioDir);
    await _fs.ensureDirectory(_jsonDir);
  }

  // ---------------------------------------------------------------------------
  // JSON 元数据
  // ---------------------------------------------------------------------------

  Future<void> putJson(String key, String json) async {
    await _fs.ensureDirectory(_jsonDir);
    await _fs.writeBytes(_jsonPath(key), Uint8List.fromList(utf8.encode(json)));
  }

  /// 读取未过期的 JSON；不存在或已过期返回 null。
  Future<String?> getJson(String key) async {
    final path = _jsonPath(key);
    final mtime = await _fs.lastModified(path);
    if (mtime == null) return null;
    if (DateTime.now().difference(mtime) >= ttl) return null;
    final bytes = await _fs.readBytes(path);
    return bytes == null ? null : utf8.decode(bytes);
  }

  // ---------------------------------------------------------------------------
  // 音频文件
  // ---------------------------------------------------------------------------

  String audioPath(String id, String extension) =>
      p.join(_audioDir, '$id.$extension');

  Future<bool> hasAudio(String id, String extension) =>
      _fs.exists(audioPath(id, extension));

  Future<Uint8List?> getAudio(String id, String extension) async {
    final path = audioPath(id, extension);
    if (!await _fs.exists(path)) return null;
    return _fs.readBytes(path);
  }

  /// 写入音频并返回其绝对路径。
  Future<String> putAudio(String id, String extension, Uint8List bytes) async {
    await _fs.ensureDirectory(_audioDir);
    final path = audioPath(id, extension);
    await _fs.writeBytes(path, bytes);
    return path;
  }

  // ---------------------------------------------------------------------------
  // 清理与统计
  // ---------------------------------------------------------------------------

  /// 删除超过 [maxAge]（默认 [ttl]）未修改的文件，返回删除数量。
  Future<int> cleanup({Duration? maxAge}) async {
    final cutoff = DateTime.now().subtract(maxAge ?? ttl);
    var deleted = 0;
    for (final dir in [_audioDir, _jsonDir]) {
      for (final file in await _fs.listFiles(dir)) {
        if (file.lastModified.isBefore(cutoff)) {
          await _fs.deleteFile(file.path);
          deleted++;
        }
      }
    }
    return deleted;
  }

  /// 清空整个缓存目录，返回删除的文件数。
  Future<int> clearAll() async {
    var deleted = 0;
    for (final dir in [_audioDir, _jsonDir]) {
      for (final file in await _fs.listFiles(dir)) {
        await _fs.deleteFile(file.path);
        deleted++;
      }
    }
    return deleted;
  }

  /// 当前缓存占用的字节总数。
  Future<int> totalSize() async {
    var size = 0;
    for (final dir in [_audioDir, _jsonDir]) {
      for (final file in await _fs.listFiles(dir)) {
        size += file.size;
      }
    }
    return size;
  }

  String _jsonPath(String key) => p.join(_jsonDir, '$key.json');
}
