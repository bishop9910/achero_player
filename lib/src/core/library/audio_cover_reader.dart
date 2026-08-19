import 'dart:typed_data';

/// 从音频文件头部字节中提取内嵌封面。
///
/// 纯 Dart 解析，支持最常见的两种内嵌封面：
/// * MP3 的 ID3v2 `APIC` 帧；
/// * FLAC 的 `PICTURE` 元数据块。
/// 传入的 [head] 需足够长以覆盖标签块（通常文件前 1MB 内）。
class AudioCoverReader {
  const AudioCoverReader();

  /// 返回封面图片字节；无封面返回 null。
  Uint8List? extract(Uint8List head) {
    if (_isId3(head)) return _fromId3(head);
    if (_isFlac(head)) return _fromFlac(head);
    return null;
  }

  bool _isId3(Uint8List b) =>
      b.length >= 3 && b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33; // 'ID3'

  bool _isFlac(Uint8List b) =>
      b.length >= 4 && b[0] == 0x66 && b[1] == 0x4C && b[2] == 0x61 && b[3] == 0x43; // 'fLaC'

  Uint8List? _fromId3(Uint8List b) {
    if (b.length < 10) return null;
    var i = 10; // 跳过 'ID3' + ver(2) + flags(1) + size(4)
    final len = b.length;
    while (i + 10 <= len) {
      final id = String.fromCharCodes([b[i], b[i + 1], b[i + 2], b[i + 3]]);
      if (id == '\x00\x00\x00\x00') break; // 到达 padding
      // ID3v2.3 的 frame size 是大端 4 字节。
      final size =
          (b[i + 4] << 24) | (b[i + 5] << 16) | (b[i + 6] << 8) | b[i + 7];
      if (size <= 0 || i + 10 + size > len) break;
      if (id == 'APIC') {
        final data = _apicData(b.sublist(i + 10, i + 10 + size));
        if (data != null) return data;
      }
      i += 10 + size;
    }
    return null;
  }

  Uint8List? _apicData(Uint8List frame) {
    // APIC: encoding(1) + MIME(null 结尾) + type(1) + desc(null 结尾) + data
    var j = 1;
    while (j < frame.length && frame[j] != 0) {
      j++;
    }
    j++; // 跳过 MIME 结尾 null
    j++; // 跳过 picture type
    while (j < frame.length && frame[j] != 0) {
      j++;
    }
    j++; // 跳过 description 结尾 null
    if (j >= frame.length) return null;
    return frame.sublist(j);
  }

  Uint8List? _fromFlac(Uint8List b) {
    var i = 4; // 跳过 'fLaC'
    final len = b.length;
    while (i + 4 <= len) {
      final header =
          (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
      final isLast = ((header >> 31) & 1) == 1;
      final type = (header >> 24) & 0x7f;
      final size = header & 0x00ffffff;
      i += 4;
      if (i + size > len) break;
      if (type == 6) {
        final data = _flacPictureData(b.sublist(i, i + size));
        if (data != null) return data;
      }
      i += size;
      if (isLast) break;
    }
    return null;
  }

  Uint8List? _flacPictureData(Uint8List block) {
    var j = 4; // 跳过 picture type(4)
    if (j + 4 > block.length) return null;
    final mimeLen =
        (block[j] << 24) | (block[j + 1] << 16) | (block[j + 2] << 8) | block[j + 3];
    j += 4 + mimeLen;
    if (j + 4 > block.length) return null;
    final descLen =
        (block[j] << 24) | (block[j + 1] << 16) | (block[j + 2] << 8) | block[j + 3];
    j += 4 + descLen;
    j += 4 + 4 + 4 + 4; // width + height + depth + colors
    if (j + 4 > block.length) return null;
    final dataLen =
        (block[j] << 24) | (block[j + 1] << 16) | (block[j + 2] << 8) | block[j + 3];
    j += 4;
    if (j + dataLen > block.length) return null;
    return block.sublist(j, j + dataLen);
  }
}
