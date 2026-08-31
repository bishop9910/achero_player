import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library/music_library.dart';

/// 弹出一个「添加到播放列表」底部弹层，把 [trackIds] 加入所选歌单。
///
/// 供曲库单曲菜单与多选批量添加共用（收藏「我最喜爱」不在候选列表内）。
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  List<String> trackIds,
) async {
  if (trackIds.isEmpty) return;
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
                library.addToPlaylist(pl.id, trackIds);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
