import 'package:flutter/material.dart';

import '../../core/models/track.dart';

/// 音源类型小徽标（本地 / RPC / Subsonic）。
///
/// 在播放页与迷你播放条上标识当前曲目来自哪个音乐来源。
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.origin});

  final TrackOrigin origin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        origin.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
