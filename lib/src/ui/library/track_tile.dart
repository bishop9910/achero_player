import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/library/music_library.dart';
import '../../core/models/track.dart';
import '../../core/player/player_controller.dart';
import '../common/cover_art.dart';
import '../common/marquee_text.dart';

/// 曲目列表项：点击播放，右键菜单提供播放列表 / 收藏 / 移除操作。
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.isCurrent = false,
    this.isPlaying = false,
    this.onTap,
    this.onRemove,
  });

  final Track track;
  final int? index;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final player = context.read<PlayerController>();
    final library = context.read<MusicLibrary>();
    final downloads = context.read<AppServices>().downloads;

    return ListTile(
      onTap: onTap,
      leading: _Leading(
        track: track,
        index: index,
        isCurrent: isCurrent,
        isPlaying: isPlaying,
        scheme: scheme,
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? scheme.primary : null,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: track.subtitle.isEmpty
          ? null
          : MarqueeText(
              text: track.subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
      trailing: PopupMenuButton<_TrackAction>(
        tooltip: '更多操作',
        icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
        onSelected: (action) async {
          switch (action) {
            case _TrackAction.play:
              await player.playTrack(track);
              break;
            case _TrackAction.favorite:
              library.toggleFavorite(track.id);
              break;
            case _TrackAction.addToPlaylist:
              await _showPlaylistPicker(context, track);
              break;
            case _TrackAction.download:
              final ok = await downloads.download(track);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('无法下载：缺少缓存或服务器地址'),
                  duration: Duration(milliseconds: 1500),
                ));
              }
              break;
            case _TrackAction.remove:
              onRemove?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: _TrackAction.play, child: Text('播放')),
          PopupMenuItem(
            value: _TrackAction.favorite,
            child: Text(library.isFavorite(track.id) ? '取消收藏' : '收藏'),
          ),
          const PopupMenuItem(
              value: _TrackAction.addToPlaylist, child: Text('添加到播放列表')),
          if (track.origin != TrackOrigin.local)
            PopupMenuItem(
              value: _TrackAction.download,
              child: Text(track.source is FileTrackSource ? '重新下载' : '下载'),
            ),
          if (onRemove != null)
            const PopupMenuItem(value: _TrackAction.remove, child: Text('从曲库移除')),
        ],
      ),
    );
  }

  Future<void> _showPlaylistPicker(BuildContext context, Track track) async {
    final library = context.read<MusicLibrary>();
    final playlists = library.playlists.where((p) => !p.isFavorite).toList();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('添加到播放列表',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('还没有播放列表，先去「播放列表」页创建一个吧'),
              ),
            for (final pl in playlists)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(pl.name),
                subtitle: Text('${pl.trackCount} 首'),
                onTap: () {
                  library.addToPlaylist(pl.id, track.id);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.isPlaying,
    required this.scheme,
  });

  final Track track;
  final int? index;
  final bool isCurrent;
  final bool isPlaying;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    // 有封面：显示圆形缩略图，当前播放时加主色描边。
    final hasCover = (track.coverArtUrl != null && track.coverArtUrl!.isNotEmpty) ||
        (track.coverArtPath != null && track.coverArtPath!.isNotEmpty);
    if (hasCover) {
      return Container(
        width: 40,
        height: 40,
        foregroundDecoration: isCurrent
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary, width: 2.5),
              )
            : null,
        child: ClipOval(
          child: CoverArt(track: track, borderRadius: 0, iconSize: 20),
        ),
      );
    }

    // 无封面：保持原序号 / 播放图标。
    if (isCurrent) {
      return Icon(
        isPlaying ? Icons.graphic_eq : Icons.volume_up_outlined,
        color: scheme.primary,
      );
    }
    if (index != null) {
      return SizedBox(
        width: 28,
        child: Center(
          child: Text('${index! + 1}',
              style: Theme.of(context).textTheme.labelMedium),
        ),
      );
    }
    return Icon(Icons.music_note, color: scheme.outline);
  }
}

enum _TrackAction { play, favorite, addToPlaylist, download, remove }
