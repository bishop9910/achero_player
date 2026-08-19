import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library/album_overrides.dart';
import '../../core/library/library_catalog.dart';
import '../../core/models/track.dart';
import '../common/cover_art.dart';

/// 专辑编辑页：对某个专辑分组内的曲目做手动重新归类。
///
/// 用于处理「真正重名」的专辑被合并到同一组的情况：可把单首曲目移到其它
/// 专辑 / 新建专辑，或整张专辑重命名，或把曲目重置回自动归类。
class AlbumEditPage extends StatelessWidget {
  const AlbumEditPage({super.key, required this.albumKey});

  /// [LibraryCatalog.AlbumGroup.key]（即规范化专辑名）。
  final String albumKey;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<LibraryCatalog>();
    final album = catalog.albumByKey(albumKey);

    if (album == null) {
      return const Scaffold(body: Center(child: Text('专辑不存在')));
    }

    final tracks = catalog.tracksOfAlbum(albumKey);

    return Scaffold(
      appBar: AppBar(title: Text('编辑专辑：${album.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('${tracks.length} 首曲目',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                FilledButton.tonalIcon(
                  onPressed: tracks.isEmpty
                      ? null
                      : () => _renameAlbum(context, album, tracks),
                  icon: const Icon(Icons.drive_file_rename_outline),
                  label: const Text('重命名整张专辑'),
                ),
              ],
            ),
          ),
          Expanded(
            child: tracks.isEmpty
                ? const Center(child: Text('专辑里没有曲目'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) =>
                        _TrackRow(track: tracks[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final overrides = context.watch<AlbumOverrides>();
    final scheme = Theme.of(context).colorScheme;
    final autoAlbum = track.album ?? kUnknownAlbum;
    final override = overrides.overrideFor(track.id);
    final currentAlbum = override ?? autoAlbum;

    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CoverArt(track: track, borderRadius: 0, iconSize: 18),
        ),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (track.artist != null && track.artist!.isNotEmpty) track.artist!,
          '$currentAlbum${override != null ? '（已手动调整）' : ''}',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: '重新归类',
        icon: Icon(Icons.drive_file_move_outlined, color: scheme.primary),
        onPressed: () => _pickAlbum(context, track),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 交互
// ---------------------------------------------------------------------------

Future<void> _renameAlbum(
  BuildContext context,
  AlbumGroup album,
  List<Track> tracks,
) async {
  final controller = TextEditingController(text: album.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('重命名整张专辑'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '新专辑名'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  controller.dispose();

  if (name == null || name.isEmpty || name == album.name) return;
  if (!context.mounted) return;
  final overrides = context.read<AlbumOverrides>();
  await overrides.assignToAlbum(tracks.map((t) => t.id), name);
}

Future<void> _pickAlbum(BuildContext context, Track track) async {
  final catalog = context.read<LibraryCatalog>();
  final overrides = context.read<AlbumOverrides>();
  final current = overrides.overrideFor(track.id) ?? track.album ?? kUnknownAlbum;
  final names = catalog.albums
      .map((a) => a.name)
      .where((n) => n != current)
      .toList(growable: false);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('重新归类「${track.title}」',
                style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.album_outlined),
            title: Text('当前：$current',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            enabled: false,
          ),
          const Divider(height: 1),
          for (final name in names)
            ListTile(
              leading: const Icon(Icons.album),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(sheetContext);
                overrides.setOverride(track.id, name);
              },
            ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('新建专辑…'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final name = await _promptAlbumName(context);
              if (name != null) await overrides.setOverride(track.id, name);
            },
          ),
          if (overrides.overrideFor(track.id) != null)
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('重置为自动归类'),
              onTap: () {
                Navigator.pop(sheetContext);
                overrides.setOverride(track.id, null);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<String?> _promptAlbumName(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新建专辑'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '专辑名'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  controller.dispose();
  return (name != null && name.isNotEmpty) ? name : null;
}
