import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:achero_player/src/core/rpc/music_server_client.dart';

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('MusicServerClient', () {
    test('music.list 正确解析曲目（含 UTF-8 中文）', () async {
      final client = MusicServerClient(
        endpoint: 'http://example.com/rpc',
        client: MockClient((request) async {
          final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
          expect(body['method'], 'music.list');
          expect(body['params'], {'offset': 0, 'limit': 200});
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': body['id'],
            'result': {
              'tracks': [
                {
                  'id': '1',
                  'title': '海阔天空',
                  'artist': 'Beyond',
                  'durationMs': 324000,
                  'url': 'http://x/stream/1',
                  'lyrics': '[00:00.00]歌词',
                },
              ],
            },
          });
        }),
      );

      final tracks = await client.listTracks();
      expect(tracks.length, 1);
      expect(tracks.first.id, '1');
      expect(tracks.first.title, '海阔天空');
      expect(tracks.first.durationMs, 324000);
      expect(tracks.first.url, 'http://x/stream/1');
      expect(tracks.first.lyrics, '[00:00.00]歌词');
    });

    test('resolveStreamUrl 返回流地址', () async {
      final client = MusicServerClient(
        endpoint: 'http://example.com/rpc',
        client: MockClient((request) async {
          final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
          expect(body['method'], 'music.streamUrl');
          expect(body['params'], {'id': '42'});
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': body['id'],
            'result': {'url': 'http://x/stream/42?token=signed'},
          });
        }),
      );

      final url = await client.resolveStreamUrl('42');
      expect(url, 'http://x/stream/42?token=signed');
    });

    test('RPC 错误对象抛出 MusicServerException', () async {
      final client = MusicServerClient(
        endpoint: 'http://example.com/rpc',
        client: MockClient((request) async => _jsonResponse({
          'jsonrpc': '2.0',
          'id': 0,
          'error': {'code': -32601, 'message': 'unknown method'},
        })),
      );

      await expectLater(
        client.ping(),
        throwsA(isA<MusicServerException>()
            .having((e) => e.code, 'code', -32601)
            .having((e) => e.message, 'message', 'unknown method')),
      );
    });

    test('HTTP 非 200 抛出携带状态码的异常', () async {
      final client = MusicServerClient(
        endpoint: 'http://example.com/rpc',
        client: MockClient((request) async => http.Response('oops', 500)),
      );

      await expectLater(
        client.ping(),
        throwsA(isA<MusicServerException>().having((e) => e.code, 'code', 500)),
      );
    });

    test('鉴权令牌随 Authorization 头发送', () async {
      String? authHeader;
      final client = MusicServerClient(
        endpoint: 'http://example.com/rpc',
        authToken: 'secret',
        client: MockClient((request) async {
          authHeader = request.headers['Authorization'];
          return _jsonResponse({'jsonrpc': '2.0', 'id': 0, 'result': {'ok': true}});
        }),
      );

      await client.ping();
      expect(authHeader, 'Bearer secret');
    });
  });
}
