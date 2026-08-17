import 'package:path/path.dart' as p;

import '../models/track.dart';
import '../platform/platform_filesystem.dart';
import '../util/stable_id.dart';
import 'metadata_extractor.dart';

/// 曲库扫描器：把磁盘目录转换为 [Track] 列表。
class LibraryScanner {
  const LibraryScanner(
    this.fs, {
    this.extractor = const FilenameMetadataExtractor(),
  });

  final PlatformFileSystem fs;
  final TrackMetadataExtractor extractor;

  /// 扫描若干目录，返回去重后的曲目列表。
  Future<List<Track>> scanFolders(List<String> folders) async {
    if (folders.isEmpty) return const [];

    final files = <LocalAudioFile>[];
    for (final folder in folders) {
      files.addAll(await fs.listAudioFiles(folder));
    }

    // 以路径去重（同一文件可能命中多个扫描目录）。
    final seen = <String>{};
    final tracks = <Track>[];
    for (final file in files) {
      if (!seen.add(file.path)) continue;
      final folderName = p.basename(p.dirname(file.path));
      final meta = extractor.extract(file, folderName: folderName);
      tracks.add(Track(
        id: stableId(file.path, prefix: 'track'),
        title: meta.title,
        artist: meta.artist,
        album: meta.album,
        trackNumber: meta.trackNumber,
        source: FileTrackSource(file.path),
        lyricsPath: await _findLyrics(file.path),
      ));
    }
    return tracks;
  }

  /// 由单个音频文件路径构建曲目（供「导入单个文件」使用）。
  Future<Track> trackFromPath(String path) async {
    final name = p.basename(path);
    final file = LocalAudioFile(name: name, path: path);
    final folderName = p.basename(p.dirname(path));
    final meta = extractor.extract(file, folderName: folderName);
    return Track(
      id: stableId(path, prefix: 'track'),
      title: meta.title,
      artist: meta.artist,
      album: meta.album,
      trackNumber: meta.trackNumber,
      source: FileTrackSource(path),
      lyricsPath: await _findLyrics(path),
    );
  }

  /// 若同名 `.lrc` 文件存在则返回其路径（供后续异步加载）。
  Future<String?> _findLyrics(String audioPath) async {
    final withoutExt = p.withoutExtension(audioPath);
    final lrcPath = '$withoutExt.lrc';
    return await fs.exists(lrcPath) ? lrcPath : null;
  }
}
