import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:achero_player/src/core/library/library_catalog.dart';
import 'package:achero_player/src/core/library/music_library.dart';
import 'package:achero_player/src/core/models/track.dart';
import 'package:achero_player/src/core/platform/platform_filesystem.dart';

/// 最小 [PlatformFileSystem] 桩：曲库分类测试不触碰真实磁盘。
class _FakeFs implements PlatformFileSystem {
  @override
  bool get supportsDirectoryScan => false;

  @override
  Future<List<LocalAudioFile>> listAudioFiles(String directory) async => const [];

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<Uint8List?> readBytes(String path) async => null;

  @override
  Future<Uint8List?> readHeadBytes(String path, {int maxBytes = 16}) async => null;

  @override
  Future<List<String>> listFontFiles(String directory) async => const [];

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> ensureDirectory(String path) async {}

  @override
  Future<DateTime?> lastModified(String path) async => null;

  @override
  Future<List<CacheFileInfo>> listFiles(String directory) async => const [];
}

Track _track(
  String id,
  String title, {
  String? artist,
  String? album,
  int? trackNumber,
  String? coverPath,
  TrackOrigin origin = TrackOrigin.local,
}) {
  return Track(
    id: id,
    title: title,
    artist: artist,
    album: album,
    trackNumber: trackNumber,
    source: FileTrackSource('/$id.mp3'),
    coverArtPath: coverPath,
    origin: origin,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<MusicLibrary> makeLibrary() async =>
      MusicLibrary(prefs: await SharedPreferences.getInstance(), fs: _FakeFs());

  test('按专辑 / 艺术家分组，专辑内按曲目号排序', () async {
    final library = await makeLibrary();
    final catalog = LibraryCatalog(library);

    library.addTracks([
      _track('1', '海阔天空', artist: 'Beyond', album: '乐与怒', trackNumber: 2),
      _track('2', '真的爱你', artist: 'Beyond', album: '乐与怒', trackNumber: 1),
      _track('3', '东风破', artist: '周杰伦', album: '叶惠美', trackNumber: 3),
    ]);

    expect(catalog.artistCount, 2);
    expect(catalog.albumCount, 2);
    expect(catalog.artists.map((a) => a.name), containsAll(['Beyond', '周杰伦']));

    final beyond = catalog.albumsOfArtist('Beyond');
    expect(beyond.length, 1);
    expect(beyond.first.name, '乐与怒');
    expect(beyond.first.trackCount, 2);

    final tracks = catalog.tracksOfAlbum(beyond.first.key);
    expect(tracks.map((t) => t.title).toList(), ['真的爱你', '海阔天空']);
  });

  test('缺失艺术家 / 专辑时归入「未知」兜底分组', () async {
    final library = await makeLibrary();
    final catalog = LibraryCatalog(library);

    library.addTracks([
      _track('1', '无元数据', artist: null, album: null),
    ]);

    expect(catalog.artists.single.name, kUnknownArtist);
    expect(catalog.albums.single.name, kUnknownAlbum);
    expect(catalog.tracksOfArtist(kUnknownArtist).single.title, '无元数据');
  });

  test('同名专辑合并为一个分组（不同艺术家）', () async {
    final library = await makeLibrary();
    final catalog = LibraryCatalog(library);

    library.addTracks([
      _track('1', 'A', artist: 'X', album: 'Greatest Hits'),
      _track('2', 'B', artist: 'Y', album: 'Greatest Hits'),
    ]);

    expect(catalog.albumCount, 1);
    final album = catalog.albums.single;
    expect(album.name, 'Greatest Hits');
    expect(album.trackCount, 2);
    expect(album.artist, '多位艺术家');
    expect(album.artistNames, containsAll(['X', 'Y']));
  });

  test('本地与 RPC 相同专辑名合并为一个分组（同艺术家）', () async {
    final library = await makeLibrary();
    final catalog = LibraryCatalog(library);

    library.addTracks([
      _track('local', '本地歌', artist: 'Beyond', album: '乐与怒'),
      _track('rpc', 'RPC 歌', artist: 'Beyond', album: '乐与怒',
          origin: TrackOrigin.rpc),
    ]);

    expect(catalog.albumCount, 1);
    final album = catalog.albums.single;
    expect(album.artist, 'Beyond');
    expect(album.trackCount, 2);
    expect(catalog.tracksOfAlbum(album.key).length, 2);
  });

  test('封面曲目优先取组内首个有封面的曲目', () async {
    final library = await makeLibrary();
    final catalog = LibraryCatalog(library);

    library.addTracks([
      _track('1', '无封面', artist: 'X', album: 'A'),
      _track('2', '有封面', artist: 'X', album: 'A', coverPath: '/cover.jpg'),
    ]);

    final album = catalog.albums.single;
    expect(catalog.coverTrackOf(album.key)?.id, '2');
  });

  test('移除曲目后分组索引同步更新', () async {
    final library = await makeLibrary();
    final catalog = LibraryCatalog(library);

    library.addTracks([
      _track('1', 'A', artist: 'X', album: 'AL'),
      _track('2', 'B', artist: 'X', album: 'AL'),
    ]);
    expect(catalog.albums.single.trackCount, 2);

    library.removeTrack('1');
    expect(catalog.albums.single.trackCount, 1);
    expect(catalog.tracksOfAlbum(catalog.albums.single.key).single.id, '2');
  });
}
