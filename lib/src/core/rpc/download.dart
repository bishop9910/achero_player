import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 下载一个 URL 的字节流；失败返回 null。
///
/// 供音乐服务器插件把流媒体下载到缓存使用（RPC / Subsonic 共用）。
Future<Uint8List?> downloadStream(Uri uri) async {
  try {
    final response = await http.get(uri).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}
