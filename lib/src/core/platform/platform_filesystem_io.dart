import 'dart:io';
import 'dart:typed_data';

import 'platform_filesystem.dart';

/// 基于 `dart:io` 的实现，用于 Windows / Linux / Android / macOS / iOS。
class IoPlatformFileSystem implements PlatformFileSystem {
  const IoPlatformFileSystem();

  @override
  bool get supportsDirectoryScan => true;

  @override
  Future<List<LocalAudioFile>> listAudioFiles(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return const [];

    final results = <LocalAudioFile>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : entity.path.split(Platform.pathSeparator).last;
      final file = LocalAudioFile(name: name, path: entity.path);
      if (file.isAudio) results.add(file);
    }
    return results;
  }

  @override
  Future<bool> exists(String path) async => File(path).exists();

  @override
  Future<Uint8List?> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<Uint8List?> readHeadBytes(String path, {int maxBytes = 16}) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final raf = await file.open();
      try {
        final buf = Uint8List(maxBytes);
        final n = await raf.readInto(buf);
        if (n <= 0) return null;
        return buf.sublist(0, n);
      } finally {
        await raf.close();
      }
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<List<String>> listFontFiles(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return const [];

    final results = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : entity.path.split(Platform.pathSeparator).last;
      final dot = name.lastIndexOf('.');
      final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
      if (kFontExtensions.contains(ext)) results.add(entity.path);
    }
    return results;
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> ensureDirectory(String path) async {
    await Directory(path).create(recursive: true);
  }

  @override
  Future<DateTime?> lastModified(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return await file.lastModified();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<List<CacheFileInfo>> listFiles(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return const [];

    final results = <CacheFileInfo>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        results.add(CacheFileInfo(
          path: entity.path,
          lastModified: stat.modified,
          size: stat.size,
        ));
      } on FileSystemException {
        // 跳过无法读取的文件。
      }
    }
    return results;
  }
}

PlatformFileSystem createPlatformFileSystem() => const IoPlatformFileSystem();
