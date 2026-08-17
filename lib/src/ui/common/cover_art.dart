import 'package:flutter/material.dart';

import '../../core/models/track.dart';

/// 封面组件：优先网络封面（`Track.coverArtUrl`），其次本地路径，
/// 都没有时显示渐变占位图标。
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

    final url = track.coverArtUrl;
    if (url == null || url.isEmpty) return fallback;

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
