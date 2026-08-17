import 'dart:typed_data';

/// 支持的音频扩展名（不含点号，小写）。
const Set<String> kSupportedAudioExtensions = {
  'mp3', 'flac', 'wav', 'ogg', 'm4a', 'aac', 'opus', 'wma', 'mp4', 'aiff',
};

/// 支持的歌词扩展名。
const Set<String> kLyricExtensions = {'lrc'};

/// 支持的运行时字体扩展名。
const Set<String> kFontExtensions = {'ttf', 'otf'};

/// 平台文件系统发现的本地音频文件。
class LocalAudioFile {
  const LocalAudioFile({
    required this.name,
    required this.path,
    this.size = 0,
  });

  final String name;
  final String path;
  final int size;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isAudio => kSupportedAudioExtensions.contains(extension);
}

/// 缓存目录中单个文件的元信息（用于过期清理与统计）。
class CacheFileInfo {
  const CacheFileInfo({
    required this.path,
    required this.lastModified,
    required this.size,
  });

  final String path;
  final DateTime lastModified;
  final int size;
}

/// 平台文件系统抽象。
///
/// 桌面 / 移动端提供真实的目录扫描（`dart:io`），Web 端无文件系统，
/// 相应能力返回「不支持」。所有访问本地磁盘的代码都经由该接口，
/// 使曲库扫描、歌词读取、封面读取、字体加载、缓存读写得以跨平台复用。
abstract interface class PlatformFileSystem {
  /// 是否支持按目录递归扫描（也代表「是否有真实可写的文件系统」）。
  bool get supportsDirectoryScan;

  /// 递归列出目录下所有受支持的音频文件。
  Future<List<LocalAudioFile>> listAudioFiles(String directory);

  /// 路径是否存在。
  Future<bool> exists(String path);

  /// 读取文件字节；不存在或不可读返回 null。
  Future<Uint8List?> readBytes(String path);

  /// 读取文件头部若干字节（用于嗅探真实音频格式）；不存在或不可读返回 null。
  Future<Uint8List?> readHeadBytes(String path, {int maxBytes = 16});

  /// 递归列出目录下的字体文件路径。
  Future<List<String>> listFontFiles(String directory);

  /// 写入文件字节（覆盖已存在文件），自动创建父目录。
  Future<void> writeBytes(String path, Uint8List bytes);

  /// 删除文件；不存在则静默忽略。
  Future<void> deleteFile(String path);

  /// 确保目录存在（递归创建）。
  Future<void> ensureDirectory(String path);

  /// 返回文件的最后修改时间；不存在返回 null。
  Future<DateTime?> lastModified(String path);

  /// 列出目录（非递归）下的文件及其元信息。
  Future<List<CacheFileInfo>> listFiles(String directory);
}
