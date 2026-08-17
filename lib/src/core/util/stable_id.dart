/// 生成稳定、跨会话一致且不含非法字符的短标识。
///
/// 基于 FNV-1a 64 位哈希，纯 Dart 实现、无第三方依赖，
/// 用于曲目 id（以文件路径为种子）与播放列表 id 等场景。
String stableId(String input, {String prefix = ''}) {
  var hash = 0xcbf29ce484222325;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  // 转成 16 进制，并避免负号。
  final hex = (hash & 0x7fffffffffffffff).toRadixString(16);
  return prefix.isEmpty ? hex : '$prefix-$hex';
}

/// 生成一个随机但可读的唯一 id（用于用户新建的播放列表）。
String newUuidLike() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = Object().hashCode.toUnsigned(32).toRadixString(16);
  return '$now-$rand';
}
