import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:achero_player/src/core/rpc/subsonic_client.dart';

http.Response _subsonic(Map<String, dynamic> body) => http.Response.bytes(
      utf8.encode(jsonEncode({'subsonic-response': body})),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('SubsonicClient', () {
    test('鉴权参数与 getAlbumList 解析', () async {
      Uri? seen;
      final client = SubsonicClient(
        baseUrl: 'http://x:4533',
        username: 'u',
        password: 'p',
        client: MockClient((request) async {
          seen = request.url;
          expect(request.url.path, '/rest/getAlbumList2.view');
          return _subsonic({
            'status': 'ok',
            'version': '1.16.1',
            'albumList2': {
              'album': [
                {'id': 'a1', 'name': '海阔天空', 'artist': 'Beyond', 'songCount': 10},
              ],
            },
          });
        }),
      );

      final albums = await client.getAlbumList();
      expect(albums.length, 1);
      expect(albums.first.name, '海阔天空');
      expect(albums.first.artist, 'Beyond');

      // 鉴权：t = md5(password + salt)
      final q = seen!.queryParameters;
      expect(q['u'], 'u');
      expect(q['f'], 'json');
      expect(q['v'], '1.16.1');
      expect(q['c'], 'achero');
      expect(q['t'], md5.convert(utf8.encode('p${q['s']}')).toString());
    });

    test('getAlbumSongs 解析（单元素对象归一化）', () async {
      final client = SubsonicClient(
        baseUrl: 'http://x:4533',
        username: 'u',
        password: 'p',
        client: MockClient((request) async => _subsonic({
          'status': 'ok',
          'album': {
            'id': 'a1',
            'song': {
              'id': 's1',
              'title': '歌',
              'duration': 120,
              'suffix': 'mp3',
              'contentType': 'audio/mpeg',
            },
          },
        })),
      );

      final songs = await client.getAlbumSongs('a1');
      expect(songs.length, 1);
      expect(songs.first.title, '歌');
      expect(songs.first.suffix, 'mp3');
      expect(songs.first.durationSec, 120);
    });

    test('search3 解析聚合结果', () async {
      final client = SubsonicClient(
        baseUrl: 'http://x:4533',
        username: 'u',
        password: 'p',
        client: MockClient((request) async => _subsonic({
          'status': 'ok',
          'searchResult3': {
            'artist': [
              {'id': 'ar1', 'name': 'Beyond'},
            ],
            'album': [
              {'id': 'a1', 'name': '乐与怒'},
            ],
            'song': [
              {'id': 's1', 'title': '海阔天空'},
            ],
          },
        })),
      );

      final results = await client.search('beyond');
      expect(results.artists.length, 1);
      expect(results.albums.length, 1);
      expect(results.songs.length, 1);
      expect(results.songs.first.title, '海阔天空');
    });

    test('failed 状态抛出 SubsonicException', () async {
      final client = SubsonicClient(
        baseUrl: 'http://x:4533',
        username: 'u',
        password: 'bad',
        client: MockClient((request) async => _subsonic({
          'status': 'failed',
          'error': {'code': 40, 'message': 'Wrong username or password'},
        })),
      );

      await expectLater(
        client.ping(),
        throwsA(isA<SubsonicException>()
            .having((e) => e.code, 'code', 40)
            .having((e) => e.message, 'message', 'Wrong username or password')),
      );
    });

    test('streamUri 携带鉴权参数', () {
      final client = SubsonicClient(baseUrl: 'http://x:4533', username: 'u', password: 'p');
      final uri = client.streamUri('s42');
      expect(uri.path, '/rest/stream.view');
      expect(uri.queryParameters['id'], 's42');
      expect(uri.queryParameters['t'],
          md5.convert(utf8.encode('p${uri.queryParameters['s']}')).toString());
    });
  });
}
