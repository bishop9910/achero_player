import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/playlist.dart';
import '../models/track.dart';
import '../platform/platform_filesystem.dart';
import '../util/stable_id.dart';
import 'library_scanner.dart';

/// 音乐库：曲目与播放列表的单一事实来源。
///
/// 响应式（`ChangeNotifier`），持有曲目索引与播放列表，并负责持久化。
/// 扫描目录、导入文件、增删播放列表均通过本类完成。
class MusicLibrary extends ChangeNotifier {
  MusicLibrary({
    required SharedPreferences prefs,
    required PlatformFileSystem fs,
  })  : _prefs = prefs,
        _scanner = LibraryScanner(fs) {
    _restore();
  }

  static const String _tracksKey = 'achero.library.tracks.v1';
  static const String _playlistsKey = 'achero.library.playlists.v1';

  final SharedPreferences _prefs;
  final LibraryScanner _scanner;

  final Map<String, Track> _byId = {};
  final List<Playlist> _playlists = [];

  /// 所有曲目（插入序）。
  List<Track> get tracks => List.unmodifiable(_byId.values);

  int get trackCount => _byId.length;

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Playlist get favorites => _playlists.firstWhere(
        (pl) => pl.isFavorite,
        orElse: () => _createFavoritePlaylist(),
      );

  Track? trackById(String id) => _byId[id];

  Playlist? playlistById(String id) {
    for (final playlist in _playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  List<Track> tracksByIds(Iterable<String> ids) =>
      ids.map((id) => _byId[id]).whereType<Track>().toList(growable: false);

  // ---------------------------------------------------------------------------
  // 导入
  // ---------------------------------------------------------------------------

  /// 扫描目录并合并入库，返回新增曲目数。
  Future<int> scanAndImport(List<String> folders) async {
    final scanned = await _scanner.scanFolders(folders);
    return _merge(scanned);
  }

  /// 从单个音频文件路径导入（桌面 / 移动端）。
  Future<int> importPaths(List<String> paths) async {
    final tracks = <Track>[];
    for (final path in paths) {
      tracks.add(await _scanner.trackFromPath(path));
    }
    return _merge(tracks);
  }

  /// 从内存字节导入（Web 文件选择）。
  List<Track> importBytes(List<({String name, Uint8List bytes, String mime})> files) {
    final imported = <Track>[];
    for (final f in files) {
      final id = stableId('bytes:${f.name}', prefix: 'track');
      final track = Track(
        id: id,
        title: _titleFromName(f.name),
        source: BytesTrackSource(
          fileName: f.name,
          bytes: f.bytes,
          mimeType: f.mime,
        ),
      );
      _byId[id] = track;
      imported.add(track);
    }
    if (imported.isNotEmpty) {
      _persist();
      notifyListeners();
    }
    return imported;
  }

  void removeTrack(String id) {
    if (_byId.remove(id) == null) return;
    for (var i = 0; i < _playlists.length; i++) {
      if (_playlists[i].trackIds.contains(id)) {
        _playlists[i] = _playlists[i].removeTrack(id);
      }
    }
    _persist();
    notifyListeners();
  }

  /// 直接合并一批曲目（供插件 / RPC 来源导入），返回新增数量。
  ///
  /// 以 [Track.id] 去重；已存在的曲目保留原时长等运行期信息。
  int addTracks(Iterable<Track> tracks) => _merge(tracks.toList(growable: false));

  int _merge(List<Track> incoming) {
    var added = 0;
    for (final track in incoming) {
      if (_byId.containsKey(track.id)) {
        // 保留已存在的时长等运行期信息。
        continue;
      }
      _byId[track.id] = track;
      added++;
    }
    if (added > 0) {
      _persist();
      notifyListeners();
    }
    return added;
  }

  // ---------------------------------------------------------------------------
  // 播放列表
  // ---------------------------------------------------------------------------

  Playlist createPlaylist(String name, {String? description}) {
    final playlist = Playlist(
      id: stableId('pl:$name:${DateTime.now().microsecondsSinceEpoch}',
          prefix: 'pl'),
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
    _playlists.add(playlist);
    _persist();
    notifyListeners();
    return playlist;
  }

  void deletePlaylist(String id) {
    final before = _playlists.length;
    _playlists.removeWhere((pl) => pl.id == id);
    if (_playlists.length != before) {
      _persist();
      notifyListeners();
    }
  }

  void renamePlaylist(String id, String name) {
    final index = _playlists.indexWhere((pl) => pl.id == id);
    if (index < 0) return;
    _playlists[index] = _playlists[index].copyWith(name: name);
    _persist();
    notifyListeners();
  }

  void addToPlaylist(String playlistId, String trackId) {
    final index = _playlists.indexWhere((pl) => pl.id == playlistId);
    if (index < 0 || _byId[trackId] == null) return;
    final next = _playlists[index].addTrack(trackId);
    if (identical(next, _playlists[index])) return;
    _playlists[index] = next;
    _persist();
    notifyListeners();
  }

  void removeFromPlaylist(String playlistId, String trackId) {
    final index = _playlists.indexWhere((pl) => pl.id == playlistId);
    if (index < 0) return;
    _playlists[index] = _playlists[index].removeTrack(trackId);
    _persist();
    notifyListeners();
  }

  bool isFavorite(String trackId) => favorites.trackIds.contains(trackId);

  void toggleFavorite(String trackId) {
    if (_byId[trackId] == null) return;
    final fav = favorites;
    if (fav.trackIds.contains(trackId)) {
      removeFromPlaylist(fav.id, trackId);
    } else {
      addToPlaylist(fav.id, trackId);
    }
  }

  // ---------------------------------------------------------------------------
  // 持久化
  // ---------------------------------------------------------------------------

  void _restore() {
    final tracksRaw = _prefs.getString(_tracksKey);
    if (tracksRaw != null) {
      try {
        final list = (jsonDecode(tracksRaw) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (final item in list) {
          final track = Track.fromJson(item);
          _byId[track.id] = track;
        }
      } catch (_) {
        // 忽略损坏的缓存。
      }
    }

    final playlistsRaw = _prefs.getString(_playlistsKey);
    if (playlistsRaw != null) {
      try {
        final list = (jsonDecode(playlistsRaw) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        _playlists
          ..clear()
          ..addAll(list.map(Playlist.fromJson));
      } catch (_) {
        // 忽略损坏的缓存。
      }
    }
    if (!_playlists.any((pl) => pl.isFavorite)) {
      _playlists.add(_createFavoritePlaylist());
    }
  }

  Playlist _createFavoritePlaylist() => const Playlist(
        id: 'favorites',
        name: '我最喜爱',
        isFavorite: true,
      );

  void _persist() {
    final persistable = _byId.values
        .where((t) => t.source.isPersistable)
        .map((t) => t.toJson())
        .toList(growable: false);
    _prefs.setString(_tracksKey, jsonEncode(persistable));
    _prefs.setString(
        _playlistsKey, jsonEncode(_playlists.map((p) => p.toJson()).toList()));
  }

  String _titleFromName(String name) {
    final dot = name.lastIndexOf('.');
    final base = dot < 0 ? name : name.substring(0, dot);
    return base.trim().isEmpty ? name : base;
  }
}
