import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library/music_library.dart';
import '../../core/models/playlist.dart';
import '../../core/player/player_controller.dart';
import '../library/track_tile.dart';

/// 播放列表页：管理收藏与自定义播放列表。
class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<MusicLibrary>();
    final playlists = library.playlists;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('播放列表',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _createPlaylist(context),
                icon: const Icon(Icons.add),
                label: const Text('新建'),
              ),
            ],
          ),
        ),
        Expanded(
          child: playlists.isEmpty
              ? const Center(child: Text('还没有播放列表'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final pl = playlists[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          pl.isFavorite
                              ? Icons.favorite
                              : Icons.queue_music,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(pl.name),
                      subtitle: Text('${pl.trackCount} 首曲目'),
                      trailing: pl.isFavorite
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'rename') {
                                  await _renamePlaylist(context, pl);
                                } else if (action == 'delete') {
                                  library.deletePlaylist(pl.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'rename', child: Text('重命名')),
                                PopupMenuItem(value: 'delete', child: Text('删除')),
                              ],
                            ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailPage(playlistId: pl.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final library = context.read<MusicLibrary>();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建播放列表'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '播放列表名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      library.createPlaylist(name);
    }
    controller.dispose();
  }

  Future<void> _renamePlaylist(BuildContext context, Playlist playlist) async {
    final library = context.read<MusicLibrary>();
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名播放列表'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '播放列表名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      library.renamePlaylist(playlist.id, name);
    }
    controller.dispose();
  }
}

/// 播放列表详情：曲目列表 + 一键播放。
class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<MusicLibrary>();
    final player = context.watch<PlayerController>();
    final playlist = library.playlistById(playlistId);

    if (playlist == null) {
      return const Scaffold(body: Center(child: Text('播放列表已删除')));
    }

    final tracks = library.tracksByIds(playlist.trackIds);

    return Scaffold(
      appBar: AppBar(title: Text(playlist.name)),
      body: tracks.isEmpty
          ? const Center(child: Text('列表还没有曲目'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => player.playQueue(tracks),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('播放全部'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return TrackTile(
                        track: track,
                        index: index,
                        isCurrent: player.currentTrack?.id == track.id,
                        isPlaying: player.currentTrack?.id == track.id &&
                            player.isPlaying,
                        onTap: () => player.playQueue(tracks, startIndex: index),
                        onRemove: playlist.isFavorite
                            ? null
                            : () => library.removeFromPlaylist(playlist.id, track.id),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
