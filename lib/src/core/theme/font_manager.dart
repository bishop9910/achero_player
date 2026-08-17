import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/platform_filesystem.dart';

/// 运行时字体管理器。
///
/// 把用户放置在指定目录中的 `.ttf` / `.otf` 通过 [FontLoader] 动态注册，
/// 使字体无需重新编译即可在「设置 → 外观」中选择。桌面 / 移动端均可使用，
/// Web 端因无文件系统而跳过（详见 docs/THEME.md）。
class FontManager extends ChangeNotifier {
  FontManager(this._fs);

  final PlatformFileSystem _fs;
  final Map<String, String> _loaded = {};
  bool _loading = false;

  /// 跨平台内置可选字体（空字符串 = 平台默认）。
  static const List<String> systemFamilies = [
    '',
    'Roboto',
    'serif',
    'monospace',
    'sans-serif',
  ];

  /// 已从磁盘加载的字体族名。
  List<String> get loadedFamilies => List.unmodifiable(_loaded.keys);

  /// 全部可选字体族（内置 + 运行时加载）。
  List<String> get allFamilies => [...systemFamilies, ...loadedFamilies];

  bool get isLoading => _loading;

  /// 从若干目录加载字体，返回成功加载的数量。
  Future<int> loadFromDirectories(List<String> directories) async {
    if (_loading) return 0;
    _loading = true;
    notifyListeners();

    var count = 0;
    try {
      for (final dir in directories) {
        final files = await _fs.listFontFiles(dir);
        for (final file in files) {
          final family = _familyFromPath(file);
          if (family.isEmpty || _loaded.containsKey(family)) continue;
          final bytes = await _fs.readBytes(file);
          if (bytes == null) continue;
          if (await _tryLoad(family, bytes)) {
            _loaded[family] = file;
            count++;
          }
        }
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
    return count;
  }

  Future<bool> _tryLoad(String family, Uint8List bytes) async {
    try {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _familyFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    final dot = name.lastIndexOf('.');
    final base = dot < 0 ? name : name.substring(0, dot);
    return base.trim().replaceAll(RegExp(r'[^A-Za-z0-9\-_ ]'), '');
  }
}
