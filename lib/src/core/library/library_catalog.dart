import 'package:flutter/foundation.dart';

import '../models/track.dart';
import 'music_library.dart';

/// 无艺术家 / 无专辑信息时使用的兜底显示名。
const String kUnknownArtist = '未知艺术家';
const String kUnknownAlbum = '未知专辑';

/// 艺术家分组：曲库中「艺术家」字段相同的曲目集合。
@immutable
class ArtistGroup {
  const ArtistGroup({
    required this.name,
    required this.trackIds,
  });

  /// 艺术家显示名（无信息时为 [kUnknownArtist]）。
  final String name;

  /// 该艺术家下所有曲目的稳定 id（按曲库顺序）。
  final List<String> trackIds;

  int get trackCount => trackIds.length;
}

/// 专辑分组：曲库中「专辑名」相同的曲目集合。
///
/// 按专辑名（而非「专辑 + 艺术家」）分组，因此本地、RPC、Subsonic 来源中
/// 同名专辑会自动合并到同一个分组。
@immutable
class AlbumGroup {
  const AlbumGroup({
    required this.key,
    required this.name,
    required this.artistNames,
    required this.trackIds,
    this.coverTrackId,
  });

  /// 稳定分组键（= 规范化专辑名），用于详情页导航与查找。
  final String key;

  /// 专辑显示名（无信息时为 [kUnknownAlbum]）。
  final String name;

  /// 组内出现的艺术家（去重、按名称排序，不含 [kUnknownArtist]）。
  final List<String> artistNames;

  /// 该专辑下所有曲目的稳定 id。
  final List<String> trackIds;

  /// 组内首个有封面曲目的 id，用于专辑封面展示。
  final String? coverTrackId;

  int get trackCount => trackIds.length;

  /// 用于展示的专辑艺术家：单艺术家直接显示；多位显示「多位艺术家」；
  /// 无信息显示 [kUnknownArtist]。
  String get artist {
    if (artistNames.isEmpty) return kUnknownArtist;
    if (artistNames.length == 1) return artistNames.first;
    return '多位艺术家';
  }
}

/// 曲库分类器：按「专辑 / 艺术家」对 [MusicLibrary] 中的曲目建立索引。
///
/// 这是纯 Dart 核心组件（不依赖 Flutter UI），监听曲库变化并增量重建分组，
/// 供曲库主页与详情页按专辑 / 艺术家浏览。所有曲目——本地、RPC、Subsonic——
/// 只要带有 `artist` / `album` 字段即可参与分类。
class LibraryCatalog extends ChangeNotifier {
  LibraryCatalog(this._library) {
    _library.addListener(_rebuild);
    _rebuild();
  }

  final MusicLibrary _library;

  List<ArtistGroup> _artists = const [];
  List<AlbumGroup> _albums = const [];
  final Map<String, List<String>> _tracksByArtist = {};
  final Map<String, List<String>> _tracksByAlbumKey = {};

  /// 所有艺术家分组（按名称排序）。
  List<ArtistGroup> get artists => _artists;

  /// 所有专辑分组（按艺术家 + 专辑名排序）。
  List<AlbumGroup> get albums => _albums;

  int get artistCount => _artists.length;
  int get albumCount => _albums.length;

  /// 某艺术家名下的曲目（按专辑、曲目号、标题排序）。
  List<Track> tracksOfArtist(String name) {
    final tracks = List.of(_library.tracksByIds(_tracksByArtist[name] ?? const []));
    tracks.sort(_byArtistTrack);
    return tracks;
  }

  /// 按分组键查找专辑；不存在返回 null。
  AlbumGroup? albumByKey(String key) {
    for (final album in _albums) {
      if (album.key == key) return album;
    }
    return null;
  }

  /// 某专辑（按分组键）下的曲目（按曲目号、标题排序）。
  List<Track> tracksOfAlbum(String key) {
    final tracks =
        List.of(_library.tracksByIds(_tracksByAlbumKey[key] ?? const []));
    tracks.sort(_byAlbumTrack);
    return tracks;
  }

  /// 某艺术家的全部专辑（用于艺术家详情页）。
  List<AlbumGroup> albumsOfArtist(String name) =>
      _albums.where((a) => a.artistNames.contains(name)).toList(growable: false);

  /// 某专辑（按分组键）的封面曲目；没有封面返回 null。
  Track? coverTrackOf(String albumKey) {
    final id = albumByKey(albumKey)?.coverTrackId;
    return id == null ? null : _library.trackById(id);
  }

  @override
  void dispose() {
    _library.removeListener(_rebuild);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 分组构建
  // ---------------------------------------------------------------------------

  void _rebuild() {
    final artistAcc = <String, List<String>>{};
    final albumAcc = <String, List<String>>{};
    final albumMeta =
        <String, ({Set<String> artistNames, String? coverTrackId})>{};

    for (final track in _library.tracks) {
      final artistName = _norm(track.artist);
      final artistKey = artistName.isEmpty ? kUnknownArtist : artistName;
      (artistAcc[artistKey] ??= []).add(track.id);

      final albumName = _norm(track.album);
      final albumKey = albumName.isEmpty ? kUnknownAlbum : albumName;
      (albumAcc[albumKey] ??= []).add(track.id);

      final existing = albumMeta[albumKey];
      if (existing == null) {
        albumMeta[albumKey] = (
          artistNames: {if (artistName.isNotEmpty) artistKey},
          coverTrackId: _hasCover(track) ? track.id : null,
        );
      } else {
        final artistNames = {...existing.artistNames};
        if (artistName.isNotEmpty) artistNames.add(artistKey);
        albumMeta[albumKey] = (
          artistNames: artistNames,
          coverTrackId:
              existing.coverTrackId ?? (_hasCover(track) ? track.id : null),
        );
      }
    }

    _tracksByArtist
      ..clear()
      ..addAll(artistAcc);
    _tracksByAlbumKey
      ..clear()
      ..addAll(albumAcc);

    final artists = artistAcc.entries
        .map((e) => ArtistGroup(name: e.key, trackIds: List.unmodifiable(e.value)))
        .toList();
    artists.sort((a, b) => _collate(a.name, b.name));

    final albums = albumAcc.entries.map((e) {
      final meta = albumMeta[e.key]!;
      final artistNames = meta.artistNames.toList()..sort(_collate);
      return AlbumGroup(
        key: e.key,
        name: e.key,
        artistNames: List.unmodifiable(artistNames),
        trackIds: List.unmodifiable(e.value),
        coverTrackId: meta.coverTrackId,
      );
    }).toList();
    albums.sort((a, b) => _collate(a.name, b.name));

    _artists = artists;
    _albums = albums;
    notifyListeners();
  }

  int _byAlbumTrack(Track a, Track b) {
    final an = a.trackNumber ?? 0;
    final bn = b.trackNumber ?? 0;
    if (an != bn) return an.compareTo(bn);
    return _collate(a.title, b.title);
  }

  int _byArtistTrack(Track a, Track b) {
    final byAlbum = _collate(a.album ?? '', b.album ?? '');
    if (byAlbum != 0) return byAlbum;
    return _byAlbumTrack(a, b);
  }

  static String _norm(String? value) => value?.trim() ?? '';

  static bool _hasCover(Track track) =>
      (track.coverArtUrl != null && track.coverArtUrl!.isNotEmpty) ||
      (track.coverArtPath != null && track.coverArtPath!.isNotEmpty);

  static int _collate(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());
}
