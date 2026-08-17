import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library/music_library.dart';
import '../../core/models/track.dart';
import '../../core/player/player_controller.dart';
import 'add_music.dart';
import 'track_tile.dart';

/// 曲库页：浏览 / 搜索 / 播放本地音乐，并可添加音乐与移除曲目。
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<MusicLibrary>();
    final player = context.watch<PlayerController>();
    final tracks = _filter(library.tracks);

    return Column(
      children: [
        _Header(onAdd: () => addMusic(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '搜索曲目、艺术家或专辑',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? _EmptyLibrary(query: _query, hasAny: library.trackCount > 0)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return TrackTile(
                      track: track,
                      index: index,
                      isCurrent: player.currentTrack?.id == track.id,
                      isPlaying:
                          player.currentTrack?.id == track.id && player.isPlaying,
                      onTap: () =>
                          player.playQueue(tracks, startIndex: index),
                      onRemove: () => library.removeTrack(track.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Track> _filter(List<Track> all) {
    final list = [...all]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (_query.trim().isEmpty) return list;
    final q = _query.trim().toLowerCase();
    return list
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            (t.artist?.toLowerCase().contains(q) ?? false) ||
            (t.album?.toLowerCase().contains(q) ?? false))
        .toList(growable: false);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text('曲库',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加音乐'),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.query, required this.hasAny});

  final String query;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_outlined, size: 72, color: scheme.outline),
          const SizedBox(height: 16),
          Text(
            hasAny ? '没有匹配「$query」的曲目' : '曲库空空如也',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          if (!hasAny)
            Text(
              '点击右上角「添加音乐」导入音频',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
