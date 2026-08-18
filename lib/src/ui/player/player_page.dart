import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import '../../core/models/track.dart';
import '../../core/player/player_controller.dart';
import '../../core/plugins/plugin_registry.dart';
import '../../core/plugins/plugin_types.dart';
import '../../core/settings/app_settings.dart';
import '../common/cover_art.dart';
import 'lyrics_view.dart';
import 'seek_bar.dart';

/// 正在播放页：封面 / 歌词切换、进度条、播放控制与插件面板。
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _lyricsMode = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final registry = context.watch<PluginRegistry>();
    final track = player.currentTrack;

    if (track == null) {
      return const _EmptyPlayer();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _Header(
            trackTitle: track.title,
            subtitle: track.subtitle,
            lyricsMode: _lyricsMode,
            onToggle: () => setState(() => _lyricsMode = !_lyricsMode),
          ),
          Expanded(
            child: _lyricsMode ? const LyricsView() : _ArtworkView(track: track),
          ),
          SeekBar(
            position: player.position,
            duration: player.duration ?? Duration.zero,
            onSeek: player.seek,
          ),
          const SizedBox(height: 4),
          _Controls(player: player),
          const SizedBox(height: 4),
          _VolumeControl(player: player),
          if (registry.playerWidgets.isNotEmpty)
            _PluginPanels(widgets: registry.playerWidgets),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.trackTitle,
    required this.subtitle,
    required this.lyricsMode,
    required this.onToggle,
  });

  final String trackTitle;
  final String subtitle;
  final bool lyricsMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trackTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: lyricsMode ? '显示封面' : '显示歌词',
          icon: Icon(lyricsMode ? Icons.album_outlined : Icons.lyrics_outlined),
          onPressed: onToggle,
        ),
      ],
    );
  }
}

class _ArtworkView extends StatelessWidget {
  const _ArtworkView({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CoverArt(track: track, borderRadius: 28, iconSize: 120),
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: player.shuffle ? '关闭随机' : '随机播放',
          icon: Icon(Icons.shuffle, color: player.shuffle ? scheme.primary : scheme.onSurfaceVariant),
          onPressed: player.toggleShuffle,
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '上一首',
          iconSize: 40,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: player.previous,
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: player.isPlaying ? '暂停' : '播放',
          iconSize: 44,
          icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          onPressed: player.togglePlayPause,
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '下一首',
          iconSize: 40,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: player.next,
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: player.repeatMode.label,
          icon: Icon(player.repeatMode.icon,
              color: player.repeatMode == RepeatMode.off ? scheme.onSurfaceVariant : scheme.primary),
          onPressed: player.cycleRepeatMode,
        ),
      ],
    );
  }
}

class _VolumeControl extends StatefulWidget {
  const _VolumeControl({required this.player});

  final PlayerController player;

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  double? _dragValue;
  double _lastVolume = 1.0;

  IconData _iconFor(double v) {
    if (v <= 0) return Icons.volume_off;
    if (v < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  void _toggleMute() {
    final v = widget.player.volume;
    if (v > 0) {
      _lastVolume = v;
      widget.player.setVolume(0);
    } else {
      widget.player.setVolume(_lastVolume <= 0 ? 1.0 : _lastVolume);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final player = widget.player;
    final shown = _dragValue ?? player.volume;
    return Row(
      children: [
        IconButton(
          tooltip: shown <= 0 ? '取消静音' : '静音',
          icon: Icon(_iconFor(shown), color: scheme.onSurfaceVariant),
          onPressed: _toggleMute,
        ),
        Expanded(
          child: Slider(
            value: shown,
            onChangeStart: (v) => setState(() => _dragValue = v),
            onChanged: (v) {
              setState(() => _dragValue = v);
              if (v > 0) _lastVolume = v;
              player.setVolume(v, persist: false);
            },
            onChangeEnd: (v) {
              setState(() => _dragValue = null);
              player.setVolume(v);
            },
          ),
        ),
      ],
    );
  }
}

class _PluginPanels extends StatelessWidget {
  const _PluginPanels({required this.widgets});
  final List<PlayerWidget> widgets;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widgets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final w = widgets[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(w.title,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Expanded(child: Center(child: w.builder(context))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.album_outlined,
              size: 80, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('还没有正在播放的曲目',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('去曲库挑一首吧',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
