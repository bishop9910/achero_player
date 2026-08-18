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
    if (bytes == null || !mounted) return;
    // 预热：提前把降采样后的图片解码并缓存，避免首次切页时解码与过渡动画抢资源。
    try {
      await precacheImage(
        ResizeImage(MemoryImage(bytes), width: 1920),
        context,
      );
    } catch (_) {
      // 预热失败不影响显示。
    }
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const SizedBox.shrink();
    // cacheWidth: 只对超宽原图（>1920px）等比降采样解码，大幅降低显存占用与
    // 首帧解码开销，避免页面切换动画掉帧。
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: 1920,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
