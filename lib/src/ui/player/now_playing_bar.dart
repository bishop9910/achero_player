import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/player/player_controller.dart';
import '../common/cover_art.dart';
import '../common/formats.dart';
import '../common/marquee_text.dart';
import '../common/source_badge.dart';

/// 停靠在底部的迷你播放条。
///
/// 显示当前曲目与进度，提供播放/暂停与下一首；点击主体跳转播放页。
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: player.progress,
              minHeight: 2,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CoverArt(track: track, borderRadius: 8, iconSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SourceBadge(origin: track.origin),
                          ],
                        ),
                        if (track.subtitle.isNotEmpty)
                          MarqueeText(
                            text: track.subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    formatDuration(player.position),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  IconButton(
                    tooltip: player.isPlaying ? '暂停' : '播放',
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 34,
                    ),
                    color: scheme.primary,
                    onPressed: player.togglePlayPause,
                  ),
                  IconButton(
                    tooltip: '下一首',
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: player.next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
