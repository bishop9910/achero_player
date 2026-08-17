import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Subsonic/OpenSubsonic API 调用失败。
class SubsonicException implements Exception {
  const SubsonicException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => 'SubsonicException($code): $message';
}

/// 歌曲元数据（对应 Subsonic `song` 节点）。
class SubsonicSong {
  const SubsonicSong({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.contentType,
    this.suffix,
    this.coverArt,
    this.durationSec,
    this.track,
    this.size,
  });

  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? contentType;
  final String? suffix;
  final String? coverArt;
  final int? durationSec;
  final int? track;
  final int? size;

  factory SubsonicSong.fromJson(Map<String, dynamic> json) => SubsonicSong(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        contentType: json['contentType'] as String?,
        suffix: json['suffix'] as String?,
        coverArt: json['coverArt'] as String?,
        durationSec: (json['duration'] as num?)?.toInt(),
        track: (json['track'] as num?)?.toInt(),
        size: (json['size'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'contentType': contentType,
        'suffix': suffix,
        'coverArt': coverArt,
        'duration': durationSec,
        'track': track,
        'size': size,
      };
}

/// 专辑元数据（对应 Subsonic `album` 节点）。
class SubsonicAlbum {
  const SubsonicAlbum({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.coverArt,
    this.songCount,
    this.year,
  });

  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? coverArt;
  final int? songCount;
  final int? year;

  factory SubsonicAlbum.fromJson(Map<String, dynamic> json) => SubsonicAlbum(
        id: json['id'] as String,
        name: json['name'] as String,
        artist: json['artist'] as String?,
        artistId: json['artistId'] as String?,
        coverArt: json['coverArt'] as String?,
        songCount: (json['songCount'] as num?)?.toInt(),
        year: (json['year'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artist': artist,
        'artistId': artistId,
        'coverArt': coverArt,
        'songCount': songCount,
        'year': year,
      };
}

/// 艺术家元数据（对应 Subsonic `artist` 节点）。
class SubsonicArtist {
  const SubsonicArtist({required this.id, required this.name, this.albumCount});

  final String id;
  final String name;
  final int? albumCount;

  factory SubsonicArtist.fromJson(Map<String, dynamic> json) => SubsonicArtist(
        id: json['id'] as String,
        name: json['name'] as String,
        albumCount: (json['albumCount'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'albumCount': albumCount};
}

/// `search3` 的聚合结果。
class SubsonicSearchResults {
  const SubsonicSearchResults({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
  });

  final List<SubsonicArtist> artists;
  final List<SubsonicAlbum> albums;
  final List<SubsonicSong> songs;

  bool get isEmpty => artists.isEmpty && albums.isEmpty && songs.isEmpty;
}

/// Subsonic / OpenSubsonic API 客户端（纯 Dart）。
///
/// 覆盖 Navidrome、Airsonic(-Advanced)、Gonic 等主流自托管音乐服务器。
/// 鉴权采用 token 模式：`t = md5(password + salt)`，每个请求附带随机 `salt`。
/// 音频流通过 [streamUri] 返回的 URL 直接拉取（用于在线播放或缓存）。
class SubsonicClient {
  SubsonicClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    http.Client? client,
    this.apiVersion = '1.16.1',
    this.clientName = 'achero',
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// 服务器地址，例如 `http://192.168.1.10:4533`（可含子路径前缀）。
  final String baseUrl;
  final String username;
  final String password;
  final String apiVersion;
  final String clientName;

  final http.Client _client;
  final bool _ownsClient;
  static const Duration _timeout = Duration(seconds: 20);

  // ---------------------------------------------------------------------------
  // 元数据方法
  // ---------------------------------------------------------------------------

  Future<void> ping() => _call('ping', const {}).then((_) {});

  /// 专辑列表（`getAlbumList2`），[type] 常见值：newest / random / frequent。
  Future<List<SubsonicAlbum>> getAlbumList({
    String type = 'newest',
    int size = 100,
    int offset = 0,
  }) async {
    final sr = await _call('getAlbumList2', {
      'type': type,
      'size': '$size',
      'offset': '$offset',
    });
    return _parseAlbums(_child(sr['albumList2'], 'album'));
  }

  /// 某艺术家的专辑（`getArtist`）。
  Future<List<SubsonicAlbum>> getArtistAlbums(String artistId) async {
    final sr = await _call('getArtist', {'id': artistId});
    return _parseAlbums(_child(sr['artist'], 'album'));
  }

  /// 某专辑的歌曲（`getAlbum`）。
  Future<List<SubsonicSong>> getAlbumSongs(String albumId) async {
    final sr = await _call('getAlbum', {'id': albumId});
    return _parseSongs(_child(sr['album'], 'song'));
  }

  /// 搜索（`search3`）：艺术家 / 专辑 / 歌曲。
  Future<SubsonicSearchResults> search(String query) async {
    final sr = await _call('search3', {'query': query});
    final result = sr['searchResult3'];
    if (result is! Map<String, dynamic>) return const SubsonicSearchResults();
    return SubsonicSearchResults(
      artists: _asList(result['artist'])
          .whereType<Map<String, dynamic>>()
          .map(SubsonicArtist.fromJson)
          .toList(growable: false),
      albums: _asList(result['album'])
          .whereType<Map<String, dynamic>>()
          .map(SubsonicAlbum.fromJson)
          .toList(growable: false),
      songs: _asList(result['song'])
          .whereType<Map<String, dynamic>>()
          .map(SubsonicSong.fromJson)
          .toList(growable: false),
    );
  }

  // ---------------------------------------------------------------------------
  // 流媒体
  // ---------------------------------------------------------------------------

  /// 构造某首歌的流地址（`stream.view`，含鉴权参数）。
  ///
  /// 返回的是音频字节流而非 JSON，需由调用方直接 `GET`（用于在线播放或缓存）。
  Uri streamUri(String songId) => _buildUri('stream', {'id': songId});

  /// 构造封面图地址（`getCoverArt.view`，含鉴权参数，返回图片字节）。
  Uri coverArtUri(String coverArtId) => _buildUri('getCoverArt', {'id': coverArtId});

  void close() {
    if (_ownsClient) _client.close();
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _call(
    String method,
    Map<String, String> params,
  ) async {
    final response = await _client
        .get(_buildUri(method, params))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw SubsonicException(
        '服务器返回 HTTP ${response.statusCode}',
        code: response.statusCode,
      );
    }

    final Object? root;
    try {
      root = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const SubsonicException('响应不是合法 JSON');
    }
    if (root is! Map<String, dynamic>) {
      throw const SubsonicException('响应结构异常');
    }

    final sr = root['subsonic-response'];
    if (sr is! Map<String, dynamic>) {
      throw const SubsonicException('缺少 subsonic-response 节点');
    }
    if (sr['status'] == 'failed') {
      final error = sr['error'];
      throw SubsonicException(
        (error is Map<String, dynamic>)
            ? (error['message']?.toString() ?? '未知错误')
            : '未知错误',
        code: (error is Map<String, dynamic>)
            ? (error['code'] as num?)?.toInt()
            : null,
      );
    }
    return sr;
  }

  Uri _buildUri(String method, Map<String, String> params) {
    final salt = _randomSalt();
    final token = md5.convert(utf8.encode(password + salt)).toString();
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(base)
        .resolve('rest/$method.view')
        .replace(queryParameters: {
          ...params,
          'u': username,
          's': salt,
          't': token,
          'v': apiVersion,
          'c': clientName,
          'f': 'json',
        });
  }

  String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static List<SubsonicAlbum> _parseAlbums(dynamic node) => _asList(node)
      .whereType<Map<String, dynamic>>()
      .map(SubsonicAlbum.fromJson)
      .toList(growable: false);

  static List<SubsonicSong> _parseSongs(dynamic node) => _asList(node)
      .whereType<Map<String, dynamic>>()
      .map(SubsonicSong.fromJson)
      .toList(growable: false);

  /// 从某个对象节点中取子列表键。
  static dynamic _child(dynamic node, String key) =>
      node is Map<String, dynamic> ? node[key] : null;

  /// Subsonic 单元素列表可能是对象而非数组，这里统一归一化为列表。
  static List<dynamic> _asList(dynamic node) {
    if (node == null) return const [];
    if (node is List) return node;
    if (node is Map) return [node];
    return const [];
  }
}
