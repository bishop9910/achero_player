import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/platform/platform_filesystem.dart';

/// 全局背景图：从本地路径读字节并渲染（跨平台）。
///
/// 经 [PlatformFileSystem.readBytes] 读取，因此不依赖 `dart:io`，Web 端
/// 读取失败时返回 null → 不显示背景（由调用方负责平台提示）。
class WallpaperImage extends StatefulWidget {
  const WallpaperImage({super.key, required this.path, required this.fs});

  final String path;
  final PlatformFileSystem fs;

  @override
  State<WallpaperImage> createState() => _WallpaperImageState();
}

class _WallpaperImageState extends State<WallpaperImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WallpaperImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    final bytes = await widget.fs.readBytes(widget.path);
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
