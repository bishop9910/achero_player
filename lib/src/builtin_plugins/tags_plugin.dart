import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models/track.dart';
import '../core/plugins/plugin_types.dart';

/// 内置插件：分类标签。
///
/// 为曲目打彩色标签，并按标签过滤浏览。数据以 JSON 存在插件专属键值里：
/// `{ "标签名": {"color": ARGB, "trackIds": [...]} }`
class TagsPlugin extends AcheroPlugin {
  @override
  String get id => 'com.achero.tags';

  @override
  String get name => '分类标签';

  @override
  String get version => '1.0.5';

  @override
  String get description => '为曲目打标签并按标签浏览曲库。';

  @override
  IconData get icon => Icons.label_outline;

  static const String _storageKey = 'tags';

  PluginContext? _context;
  final ValueNotifier<Map<String, _TagInfo>> _tags = ValueNotifier(const {});

  @override
  Future<void> onLoad(PluginContext context) async {
    _context = context;
    final raw = context.prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _tags.value = decoded.map(
          (name, value) =>
              MapEntry(name, _TagInfo.fromJson(value as Map<String, dynamic>)),
        );
      } catch (_) {
        _tags.value = const {};
      }
    }
  }

  @override
  Future<void> onUnload() async {
    _context = null;
  }

  List<String> get tagNames => _tags.value.keys.toList(growable: false);

  Color tagColor(String name) => Color(_tags.value[name]?.color ?? 0xFF0984E3);

  bool trackHasTag(String trackId, String tag) =>
      _tags.value[tag]?.trackIds.contains(trackId) ?? false;

  Future<void> createTag(String name, int color) async {
    if (name.trim().isEmpty || _tags.value.containsKey(name)) return;
    final next = Map<String, _TagInfo>.from(_tags.value);
    next[name] = _TagInfo(color, const []);
    _tags.value = next;
    await _persist();
  }

  Future<void> deleteTag(String name) async {
    final next = Map<String, _TagInfo>.from(_tags.value)..remove(name);
    _tags.value = next;
    await _persist();
  }

  Future<void> toggleTag(String trackId, String tag) async {
    final info = _tags.value[tag];
    if (info == null) return;
    final ids = List<String>.from(info.trackIds);
    if (ids.contains(trackId)) {
      ids.remove(trackId);
    } else {
      ids.add(trackId);
    }
    final next = Map<String, _TagInfo>.from(_tags.value);
    next[tag] = _TagInfo(info.color, ids);
    _tags.value = next;
    await _persist();
  }

  Future<void> _persist() async {
    await _context?.prefs.setString(
      _storageKey,
      jsonEncode(_tags.value.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  @override
  List<PluginPage> get pages => [
        PluginPage(
          id: '$id.page',
          title: name,
          icon: icon,
          builder: (_) => _TagsPage(plugin: this),
        ),
      ];
}

class _TagInfo {
  _TagInfo(this.color, this.trackIds);

  int color;
  List<String> trackIds;

  Map<String, dynamic> toJson() => {'color': color, 'trackIds': trackIds};

  factory _TagInfo.fromJson(Map<String, dynamic> json) => _TagInfo(
        (json['color'] as num?)?.toInt() ?? 0xFF0984E3,
        (json['trackIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}

// ---------------------------------------------------------------------------
// 页面
// ---------------------------------------------------------------------------

class _TagsPage extends StatefulWidget {
  const _TagsPage({required this.plugin});

  final TagsPlugin plugin;

  @override
  State<_TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<_TagsPage> {
  String? _selected;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<int> _palette = [
    0xFF0984E3, 0xFFE84393, 0xFF00B894, 0xFFE17055,
    0xFF6C5CE7, 0xFFFDCB6E, 0xFFD63031, 0xFF00CEC9,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, _TagInfo>>(
      valueListenable: widget.plugin._tags,
      builder: (context, tags, _) {
        final library = widget.plugin._context!.library;
        final tracks = library.tracks;
        final tagNames = widget.plugin.tagNames;
        final query = _query.trim().toLowerCase();
        final visibleTags = query.isEmpty
            ? tagNames
            : tagNames
                .where((name) => name.toLowerCase().contains(query))
                .toList(growable: false);
        final filtered = _selected == null
            ? tracks
            : tracks
                .where((t) => widget.plugin.trackHasTag(t.id, _selected!))
                .toList(growable: false);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索标签',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('全部'),
                            selected: _selected == null,
                            onSelected: (_) => setState(() => _selected = null),
                          ),
                          for (final name in visibleTags) ...[
                            const SizedBox(width: 8),
                            InputChip(
                              avatar: _Dot(color: widget.plugin.tagColor(name)),
                              label: Text(name),
                              selected: _selected == name,
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onSelected: (_) =>
                                  setState(() => _selected = name),
                              onDeleted: () => _deleteTag(name),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '新建标签',
                    icon: const Icon(Icons.add_circle_outline),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _createTag,
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('没有曲目'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final track = filtered[index];
                        return ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(track.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(track.artist ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            tooltip: '打标签',
                            icon: const Icon(Icons.label_outline),
                            onPressed: () => _pickTag(track),
                          ),
                          onTap: () => widget.plugin._context?.player
                              .playQueue(filtered, startIndex: index),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createTag() async {
    final controller = TextEditingController();
    var color = _palette.first;
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新建标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: '标签名称'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _palette)
                    GestureDetector(
                      onTap: () => setDialogState(() => color = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == color
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (controller.text.trim(), color)),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;
    await widget.plugin.createTag(result.$1, result.$2);
  }

  Future<void> _pickTag(Track track) async {
    final tags = widget.plugin.tagNames;
    if (tags.isEmpty) {
      _toast('请先新建一个标签');
      return;
    }
    final selected = <String>{
      for (final tag in tags)
        if (widget.plugin.trackHasTag(track.id, tag)) tag,
    };

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('为「${track.title}」添加标签',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final tag in tags)
                CheckboxListTile(
                  title: Text(tag),
                  value: selected.contains(tag),
                  secondary: _Dot(color: widget.plugin.tagColor(tag)),
                  onChanged: (_) {
                    setSheetState(() {
                      selected.contains(tag)
                          ? selected.remove(tag)
                          : selected.add(tag);
                    });
                    widget.plugin.toggleTag(track.id, tag);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTag(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除标签「$name」？'),
        content: const Text('只会删除标签本身，不会删除曲目。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.plugin.deleteTag(name);
      if (mounted && _selected == name) setState(() => _selected = null);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1500),
      ));
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
