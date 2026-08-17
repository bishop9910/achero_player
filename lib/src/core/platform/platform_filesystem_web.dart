import 'dart:typed_data';

import 'platform_filesystem.dart';

/// Web 端实现：浏览器没有文件系统，无法按目录扫描。
///
/// 文件通过 `file_picker` 直接读入内存（字节），因此这里的磁盘相关
/// 能力均返回「不支持」。UI 层会在 Web 上改用文件选择流程。
class WebPlatformFileSystem implements PlatformFileSystem {
  const WebPlatformFileSystem();

  @override
  bool get supportsDirectoryScan => false;

  @override
  Future<List<LocalAudioFile>> listAudioFiles(String directory) async =>
      throw UnsupportedError('Web 端不支持目录扫描，请使用文件选择器导入音频。');

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<Uint8List?> readBytes(String path) async => null;

  @override
  Future<Uint8List?> readHeadBytes(String path, {int maxBytes = 16}) async =>
      null;

  @override
  Future<List<String>> listFontFiles(String directory) async => const [];

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      throw UnsupportedError('Web 端不支持写入文件');

  @override
  Future<void> deleteFile(String path) async =>
      throw UnsupportedError('Web 端不支持删除文件');

  @override
  Future<void> ensureDirectory(String path) async =>
      throw UnsupportedError('Web 端不支持创建目录');

  @override
  Future<DateTime?> lastModified(String path) async => null;

  @override
  Future<List<CacheFileInfo>> listFiles(String directory) async => const [];
}

PlatformFileSystem createPlatformFileSystem() => const WebPlatformFileSystem();
