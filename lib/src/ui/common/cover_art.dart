import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/models/track.dart';

/// 封面组件：优先网络封面（`Track.coverArtUrl`），其次本地路径
/// （`Track.coverArtPath`，从音频内嵌标签提取），都没有时显示渐变占位图标。
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.track,
    this.borderRadius = 16,
    this.iconSize = 48,
  });

  final Track track;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = _Fallback(
      borderRadius: borderRadius,
      iconSize: iconSize,
      scheme: scheme,
    );

    // 优先使用本地缓存封面（快、可离线）；本地缺失时回退到网络封面。
    final path = track.coverArtPath;
    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _LocalCover(
          path: path,
          fallbackUrl: track.coverArtUrl,
          fallback: fallback,
        ),
      );
    }

    final url = track.coverArtUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
        ),
      );
    }

    return fallback;
  }
}

class _LocalCover extends StatefulWidget {
  const _LocalCover({
    required this.path,
    this.fallbackUrl,
    required this.fallback,
  });

  final String path;

  /// 本地文件缺失时回退的网络封面地址。
  final String? fallbackUrl;
  final Widget fallback;

  @override
  State<_LocalCover> createState() => _LocalCoverState();
}

class _LocalCoverState extends State<_LocalCover> {
  Uint8List? _bytes;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_LocalCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    final fs = context.read<AppServices>().fs;
    final bytes = await fs.readBytes(widget.path);
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _missing = bytes == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    }
    final url = widget.fallbackUrl;
    if (_missing && url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    }
    return widget.fallback;
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.borderRadius,
    required this.iconSize,
    required this.scheme,
  });

  final double borderRadius;
  final double iconSize;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: iconSize,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
