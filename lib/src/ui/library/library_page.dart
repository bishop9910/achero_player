import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library/library_catalog.dart';
import '../../core/library/music_library.dart';
import '../../core/models/track.dart';
import '../../core/player/player_controller.dart';
import 'add_music.dart';
import 'category_pages.dart';
import 'track_tile.dart';

/// 曲库页：按「歌曲 / 专辑 / 艺术家」浏览、搜索、播放本地音乐。
///
/// 「专辑 / 艺术家」分类由核心组件 [LibraryCatalog] 提供，对本地、RPC、
/// Subsonic 三种来源的曲目统一生效（只要曲目带有 `album` / `artist` 字段）。
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _Header(onAdd: () => addMusic(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '搜索曲目、艺术家或专辑',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _query = ''),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: '歌曲'),
              Tab(text: '专辑'),
              Tab(text: '艺术家'),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SongsView(query: _query),
                _AlbumsView(query: _query),
                _ArtistsView(query: _query),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 歌曲分栏
// ---------------------------------------------------------------------------

class _SongsView extends StatelessWidget {
  const _SongsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<MusicLibrary>();
    final player = context.watch<PlayerController>();
    final tracks = _filterSongs(library.tracks, query);

    if (tracks.isEmpty) {
      return _EmptyLibrary(query: query, hasAny: library.trackCount > 0);
    }
    return ListView.builder(
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
          onTap: () => player.playQueue(tracks, startIndex: index),
          onRemove: () => library.removeTrack(track.id),
        );
      },
    );
  }

  static List<Track> _filterSongs(List<Track> all, String query) {
    final list = [...all]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            (t.artist?.toLowerCase().contains(q) ?? false) ||
            (t.album?.toLowerCase().contains(q) ?? false))
        .toList(growable: false);
  }
}

// ---------------------------------------------------------------------------
// 专辑分栏
// ---------------------------------------------------------------------------

class _AlbumsView extends StatelessWidget {
  const _AlbumsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<LibraryCatalog>();
    final q = query.trim().toLowerCase();
    final albums = q.isEmpty
        ? catalog.albums
        : catalog.albums
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.artist.toLowerCase().contains(q))
            .toList(growable: false);

    if (albums.isEmpty) {
      return _EmptyLibrary(query: query, hasAny: catalog.albumCount > 0);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return AlbumCard(
          coverTrack: catalog.coverTrackOf(album.key),
          name: album.name,
          artist: album.artist,
          trackCount: album.trackCount,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AlbumDetailPage(albumKey: album.key),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 艺术家分栏
// ---------------------------------------------------------------------------

class _ArtistsView extends StatelessWidget {
  const _ArtistsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<LibraryCatalog>();
    final q = query.trim().toLowerCase();
    final artists = q.isEmpty
        ? catalog.artists
        : catalog.artists
            .where((a) => a.name.toLowerCase().contains(q))
            .toList(growable: false);

    if (artists.isEmpty) {
      return _EmptyLibrary(
          query: query, hasAny: catalog.artistCount > 0);
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Text(
              artist.name.isEmpty
                  ? '?'
                  : String.fromCharCode(artist.name.runes.first),
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
          title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${artist.trackCount} 首'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArtistDetailPage(artistName: artist.name),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 页头与空态
// ---------------------------------------------------------------------------

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
            hasAny ? '没有匹配「$query」的内容' : '曲库空空如也',
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
