import '../platform/platform_filesystem.dart';

/// 从文件名推断出的曲目元数据。
class TrackMetadata {
  const TrackMetadata({
    required this.title,
    this.artist,
    this.album,
    this.trackNumber,
  });

  final String title;
  final String? artist;
  final String? album;
  final int? trackNumber;
}

/// 曲目元数据提取器接口。
///
/// 默认实现基于文件名 / 目录结构推断；你可以实现该接口（例如接入
/// ID3/FLAC 标签读取库）后注入 [LibraryScanner]，无需改动其他代码。
abstract interface class TrackMetadataExtractor {
  TrackMetadata extract(LocalAudioFile file, {String? folderName});
}

/// 基于文件名的元数据提取器。
///
/// 支持以下常见命名约定：
/// * `01 - 艺术家 - 标题.mp3`
/// * `艺术家 - 标题.mp3`
/// * `标题.mp3`（艺术家取自父目录）
class FilenameMetadataExtractor implements TrackMetadataExtractor {
  const FilenameMetadataExtractor();

  static final RegExp _leadingNumber = RegExp(r'^\s*\d{1,3}[\s.\-–_]*');

  @override
  TrackMetadata extract(LocalAudioFile file, {String? folderName}) {
    var base = _stripExtension(file.name);
    int? trackNumber;
    String? artist;
    var title = base;

    // 去除前导序号。
    final numberMatch = _leadingNumber.firstMatch(base);
    if (numberMatch != null) {
      trackNumber =
          int.tryParse(numberMatch.group(0)!.replaceAll(RegExp(r'\D'), ''));
      base = base.substring(numberMatch.end).trim();
    }

    // 尝试 "艺术家 - 标题" 拆分。
    final parts = base.split(RegExp(r'\s[-–—|]\s'));
    if (parts.length >= 2) {
      artist = parts.first.trim();
      title = parts.sublist(1).join(' - ').trim();
    }

    // 兜底：无有效标题时用完整文件名。
    if (title.isEmpty) title = _stripExtension(file.name);

    return TrackMetadata(
      title: title,
      artist: artist,
      album: folderName,
      trackNumber: trackNumber,
    );
  }

  String _stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }
}
