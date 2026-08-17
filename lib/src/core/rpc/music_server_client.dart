import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// RPC 音乐服务器返回的曲目元数据。
class RemoteTrack {
  const RemoteTrack({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.url,
    this.coverUrl,
    this.lyrics,
  });

  final String id;
  final String title;
  final String? artist;
  final String? album;
  final int? durationMs;

  /// 流媒体 URL。为空时由 `music.streamUrl` 解析。
  final String? url;

  final String? coverUrl;

  /// 内联 LRC 歌词文本（可选）。
  final String? lyrics;

  static RemoteTrack fromJson(Map<String, dynamic> json) => RemoteTrack(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        durationMs: (json['durationMs'] as num?)?.toInt(),
        url: json['url'] as String?,
        coverUrl: json['coverUrl'] as String?,
        lyrics: json['lyrics'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'url': url,
        'coverUrl': coverUrl,
        'lyrics': lyrics,
      };
}

/// RPC 调用失败（网络错误、非 200、或 JSON-RPC 错误对象）。
class MusicServerException implements Exception {
  const MusicServerException(this.message, {this.code});

  final String message;

  /// HTTP 状态码或 JSON-RPC 错误码。
  final int? code;

  @override
  String toString() => 'MusicServerException($code): $message';
}

/// 音乐服务器 RPC 客户端（JSON-RPC 2.0 over HTTP）。
///
/// 协议详见 `docs/RPC.md`。客户端只负责「元数据」与「流地址」两个层面的
/// 远程调用；真正的音频流由播放器直接拉取返回的 URL（见 `UrlTrackSource`）。
class MusicServerClient {
  MusicServerClient({
    required this.endpoint,
    http.Client? client,
    this.authToken,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// JSON-RPC 端点，例如 `http://192.168.1.10:8080/rpc`。
  final String endpoint;

  /// 可选鉴权令牌，随 RPC 请求以 `Authorization: Bearer <token>` 发送。
  final String? authToken;

  final http.Client _client;
  final bool _ownsClient;
  int _nextId = 0;

  static const Duration _timeout = Duration(seconds: 15);

  /// 健康检查：`music.ping`。
  Future<void> ping() async {
    await _call('music.ping', const {});
  }

  /// 拉取曲目列表：`music.list`。
  Future<List<RemoteTrack>> listTracks({int offset = 0, int limit = 200}) async {
    final result = await _call('music.list', {
      'offset': offset,
      'limit': limit,
    });
    final list = result['tracks'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(RemoteTrack.fromJson)
        .toList(growable: false);
  }

  /// 解析流地址：`music.streamUrl`，返回可直接播放的 URL。
  Future<String> resolveStreamUrl(String id) async {
    final result = await _call('music.streamUrl', {'id': id});
    final url = result['url'];
    if (url is! String || url.isEmpty) {
      throw const MusicServerException('服务器未返回有效的流地址');
    }
    return url;
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  // ---------------------------------------------------------------------------
  // JSON-RPC 传输
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _call(
    String method,
    Map<String, dynamic> params,
  ) async {
    final id = _nextId++;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              if (authToken != null && authToken!.isNotEmpty)
                'Authorization': 'Bearer $authToken',
            },
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const MusicServerException('连接超时，请检查服务器地址');
    } on http.ClientException catch (e) {
      throw MusicServerException('网络错误：${e.message}');
    }

    if (response.statusCode != 200) {
      throw MusicServerException(
        '服务器返回 HTTP ${response.statusCode}',
        code: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      // 显式按 UTF-8 解码，避免服务器未标注 charset 时中文被 latin1 误读。
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const MusicServerException('响应不是合法 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const MusicServerException('响应不是合法的 JSON 对象');
    }

    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      throw MusicServerException(
        error['message']?.toString() ?? '未知 RPC 错误',
        code: (error['code'] as num?)?.toInt(),
      );
    }

    final result = decoded['result'];
    print('$method -> $result');
    return result is Map<String, dynamic> ? result : const {};
  }
}
