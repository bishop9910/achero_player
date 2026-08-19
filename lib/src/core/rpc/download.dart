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

/// 下载封面图片字节流（短超时，失败返回 null）。
///
/// 封面通常较小，用短超时避免不可达的封面地址拖慢整体流程。
Future<Uint8List?> downloadCover(Uri uri) async {
  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}

/// 流式下载一个 URL，并通过 [onProgress] 回报进度（received/total 字节）。
///
/// 供下载管理器展示进度条；total 未知时为 0。
Future<Uint8List?> downloadStreamWithProgress(
  Uri uri, {
  void Function(int received, int total)? onProgress,
}) async {
  try {
    final request = http.Request('GET', uri);
    final streamed = await request.send().timeout(const Duration(minutes: 5));
    if (streamed.statusCode != 200) return null;
    final total = streamed.contentLength ?? 0;
    final chunks = <int>[];
    var received = 0;
    await for (final chunk in streamed.stream) {
      chunks.addAll(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    return Uint8List.fromList(chunks);
  } catch (_) {
    return null;
  }
}
