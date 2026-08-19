import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library/library_catalog.dart';
import '../../core/models/track.dart';
import '../../core/player/player_controller.dart';
import '../common/cover_art.dart';
import 'track_tile.dart';

/// 专辑卡片：封面 + 专辑名 + 艺术家 · N 首。
///
/// 用于曲库「专辑」分栏的网格，以及艺术家详情页的横向专辑条。
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.coverTrack,
    required this.name,
    required this.artist,
    required this.trackCount,
    required this.onTap,
  });

  final Track? coverTrack;
  final String name;
  final String artist;
  final int trackCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverTrack != null
                  ? CoverArt(track: coverTrack!, borderRadius: 0, iconSize: 40)
                  : _CoverFallback(iconSize: 40, scheme: scheme),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            '$artist · $trackCount 首',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 封面占位：渐变底 + 音符图标（与 [CoverArt] 的兜底样式一致）。
class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.iconSize, required this.scheme});

  final double iconSize;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
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

/// 专辑详情页：封面 + 元信息 + 曲目列表。
class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({super.key, required this.albumKey});

  /// [LibraryCatalog.AlbumGroup.key]。
  final String albumKey;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<LibraryCatalog>();
    final player = context.watch<PlayerController>();
    final album = catalog.albumByKey(albumKey);

    if (album == null) {
      return const Scaffold(body: Center(child: Text('专辑不存在')));
    }

    final tracks = catalog.tracksOfAlbum(albumKey);
    final coverTrack = catalog.coverTrackOf(albumKey);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(album.name)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AlbumHeaderCover(coverTrack: coverTrack, scheme: scheme),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${album.artist} · ${tracks.length} 首',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: tracks.isEmpty
                              ? null
                              : () => player.playQueue(tracks),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('播放全部'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
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
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _AlbumHeaderCover extends StatelessWidget {
  const _AlbumHeaderCover({required this.coverTrack, required this.scheme});

  final Track? coverTrack;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: coverTrack != null
            ? CoverArt(track: coverTrack!, borderRadius: 0, iconSize: 48)
            : _CoverFallback(iconSize: 48, scheme: scheme),
      ),
    );
  }
}

/// 艺术家详情页：头像 + 专辑条 + 全部歌曲。
class ArtistDetailPage extends StatelessWidget {
  const ArtistDetailPage({super.key, required this.artistName});

  final String artistName;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<LibraryCatalog>();
    final player = context.watch<PlayerController>();
    final tracks = catalog.tracksOfArtist(artistName);
    final albums = catalog.albumsOfArtist(artistName);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(artistName)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      artistName.isEmpty
                          ? '?'
                          : String.fromCharCode(artistName.runes.first),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artistName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${tracks.length} 首 · ${albums.length} 张专辑',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: tracks.isEmpty
                              ? null
                              : () => player.playQueue(tracks),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('播放全部'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text('专辑',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 188,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: albums.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    return SizedBox(
                      width: 140,
                      child: AlbumCard(
                        coverTrack: catalog.coverTrackOf(album.key),
                        name: album.name,
                        artist: album.artist,
                        trackCount: album.trackCount,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AlbumDetailPage(albumKey: album.key),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text('歌曲',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          SliverList.builder(
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
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
