import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:flutter/material.dart';

import '../../../ui/library/playlist_picker.dart';
import '../../platform/platform_filesystem.dart';
import '../../settings/app_settings.dart';
import '../plugin_types.dart';
import 'compiled_script.dart';

/// 把一段运行时脚本（`.dart` 源文件）适配成宿主认识的 [AcheroPlugin]。
///
/// 脚本通过「JSON 字符串」与宿主通信：脚本暴露顶层函数，宿主用 [CompiledScript]
/// 调用；脚本则通过 `call(method, paramsJson)` 回调宿主能力。UI 采用声明式：
/// 脚本返回行数据（title/subtitle/trailing/action），宿主渲染标准 ListTile。
class ScriptPluginAdapter extends AcheroPlugin {
  ScriptPluginAdapter(String source, {required String sourceName})
      : _sourceName = sourceName {
    _script = CompiledScript.compile(source, hostCall: $Closure(_hostDispatch));
    final raw = _script.invoke('manifest');
    _manifest = switch (raw) {
      String s => (jsonDecode(s) as Map<String, dynamic>),
      Map<String, dynamic> m => m,
      _ => throw ArgumentError('manifest() 必须返回 JSON 字符串或 Map'),
    };
  }

  late final CompiledScript _script;
  late final Map<String, dynamic> _manifest;
  final String _sourceName;

  PluginContext? _context;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // ---------------------------------------------------------------------------
  // AcheroPlugin 元信息与贡献点
  // ---------------------------------------------------------------------------

  @override
  String get id => _manifest['id'] as String? ?? 'script.$_sourceName';

  @override
  String get name => _manifest['name'] as String? ?? '未命名插件';

  @override
  String get version => _manifest['version'] as String? ?? '0.0.0';

  @override
  String get description => _manifest['description'] as String? ?? '';

  @override
  IconData get icon => _iconFor(_manifest['icon'] as String?);

  @override
  List<PluginPage> get pages {
    final page = _manifest['page'];
    if (page is! Map) return const [];
    return [
      PluginPage(
        id: (page['id'] as String?) ?? id,
        title: (page['title'] as String?) ?? name,
        icon: _iconFor(page['icon'] as String?),
        builder: (_) => _ScriptPage(adapter: this),
      ),
    ];
  }

  @override
  List<PluginSettingsSection> get settingsSections {
    final section = _manifest['settings'];
    if (section is! Map) return const [];
    return [
      PluginSettingsSection(
        id: (section['id'] as String?) ?? '$id.settings',
        title: (section['title'] as String?) ?? name,
        builder: (_) => [_ScriptSettingsSection(adapter: this)],
      ),
    ];
  }

  /// 页面是否声明了「正序 / 倒序」排序切换（`page.sort == true`）。
  ///
  /// 为 true 时，宿主在页面上渲染一个排序切换，并把方向（`asc` / `desc`）
  /// 作为第二个参数传给脚本的 `pageRows(call, sortDir)`。
  bool get pageSortable {
    final page = _manifest['page'];
    return page is Map && (page['sort'] as bool?) == true;
  }

  // ---------------------------------------------------------------------------
  // 生命周期
  // ---------------------------------------------------------------------------

  @override
  Future<void> onLoad(PluginContext context) async {
    _context = context;
    _invokeVoid('onLoad');
    _subscribeEvents(context);
  }

  @override
  Future<void> onUnload() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _invokeVoid('onUnload');
    _context = null;
  }

  void _subscribeEvents(PluginContext context) {
    final events = _manifest['events'];
    if (events is! List) return;
    for (final name in events.cast<String>()) {
      switch (name) {
        case 'trackStarted':
          _subscriptions.add(context.events.onTrackStarted
              .listen((t) => _emitEvent('trackStarted', {
                    'id': t.id,
                    'title': t.title,
                    'artist': t.artist,
                  })));
          break;
        case 'trackChanged':
          _subscriptions.add(context.events.onTrackChanged
              .listen((t) => _emitEvent('trackChanged', {
                    'id': t.id,
                    'title': t.title,
                  })));
          break;
        case 'stateChanged':
          _subscriptions.add(context.events.onStateChanged
              .listen((s) => _emitEvent('stateChanged', {'status': s.name})));
          break;
        case 'libraryChanged':
          _subscriptions.add(context.events.onLibraryChanged
              .listen((n) => _emitEvent('libraryChanged', {'count': n})));
          break;
      }
    }
  }

  void _emitEvent(String name, Map<String, dynamic> payload) {
    _invokeVoid('onEvent', [name, jsonEncode(payload)]);
  }

  // ---------------------------------------------------------------------------
  // 脚本 ↔ 宿主调用
  // ---------------------------------------------------------------------------

  $Value? _hostDispatch(Runtime runtime, $Value? target, List<$Value?> args) {
    final method = args.isNotEmpty ? (args[0]?.$reified?.toString() ?? '') : '';
    final paramsJson =
        args.length > 1 ? (args[1]?.$reified?.toString() ?? '{}') : '{}';
    try {
      return _boxResult(_dispatch(method, paramsJson));
    } catch (error) {
      _context?.log('宿主回调 $method 出错：$error');
      return $null();
    }
  }

  dynamic _dispatch(String method, String paramsJson) {
    final params = paramsJson.isEmpty
        ? const <String, dynamic>{}
        : (jsonDecode(paramsJson) as Map<String, dynamic>);
    final ctx = _context;

    switch (method) {
      case 'log':
        ctx?.log(params['msg']?.toString() ?? '');
        return null;
      case 'prefsGet':
        return ctx?.prefs.getString(params['key'].toString());
      case 'prefsSet':
        ctx?.prefs.setString(
            params['key'].toString(), params['value']?.toString() ?? '');
        return null;
      case 'prefsGetInt':
        return ctx?.prefs.getInt(params['key'].toString());
      case 'prefsSetInt':
        ctx?.prefs.setInt(
            params['key'].toString(), (params['value'] as num?)?.toInt() ?? 0);
        return null;
      case 'prefsRemove':
        ctx?.prefs.remove(params['key'].toString());
        return null;
      case 'listTracks':
        final tracks = ctx?.library.tracks ?? const [];
        return jsonEncode([
          for (final t in tracks)
            {
              'id': t.id,
              'title': t.title,
              'artist': t.artist,
              'album': t.album,
              'coverPath': t.coverArtPath,
              'coverUrl': t.coverArtUrl,
            },
        ]);
      case 'playTrack':
        final playCtx = ctx;
        final track = playCtx?.library.trackById(params['id'].toString());
        if (track != null && playCtx != null) {
          playCtx.player.playTrack(track);
        }
        return null;
      case 'listPlaylists':
        final playlists = ctx?.library.playlists ?? const [];
        return jsonEncode([
          for (final pl in playlists)
            {
              'name': pl.name,
              'trackIds': pl.trackIds,
            },
        ]);
      case 'trackCount':
        return ctx?.library.trackCount ?? 0;
      case 'setSeedColor':
        final settings = ctx?.settings;
        if (settings != null) {
          settings.updateTheme(settings.settings.theme.copyWith(
            seedColor: (params['argb'] as num?)?.toInt() ?? 0xFF0984E3,
          ));
        }
        return null;
      case 'getSeedColor':
        return ctx?.settings.settings.theme.seedColor;
      case 'setBrightness':
        final settings = ctx?.settings;
        if (settings != null) {
          final brightness = ThemeBrightness.values.firstWhere(
            (b) => b.name == params['value'],
            orElse: () => ThemeBrightness.dark,
          );
          settings.updateTheme(settings.settings.theme.copyWith(brightness: brightness));
        }
        return null;
      default:
        throw ArgumentError('未知宿主方法: $method');
    }
  }

  static $Value? _boxResult(dynamic value) {
    if (value == null) return $null();
    if (value is String) return $String(value);
    return value; // int / bool 作为原语返回
  }

  // ---------------------------------------------------------------------------
  // 供 UI 使用
  // ---------------------------------------------------------------------------

  List<_ScriptRow> _readRows(String function, [List<dynamic> args = const []]) {
    final json = _invokeJson(function, args);
    if (json == null) return const [];
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(_ScriptRow.fromJson)
        .toList(growable: false);
  }

  void _fireAction(String function, String? action) {
    _invokeVoid(function, [action ?? '']);
  }

  String? _invokeJson(String function, [List<dynamic> args = const []]) {
    try {
      return _script.invoke(function, args)?.toString();
    } catch (error) {
      if (!_isMissingFunction(error)) {
        _context?.log('脚本 $function 调用失败：$error');
      }
      return null;
    }
  }

  void _invokeVoid(String function, [List<dynamic> args = const []]) {
    try {
      _script.invoke(function, args);
    } catch (error) {
      if (!_isMissingFunction(error)) {
        _context?.log('脚本 $function 调用失败：$error');
      }
    }
  }

  /// 脚本中未声明（被 dart_eval 树摇掉的）可选钩子，调用时抛
  /// 「Unable to find / Cannot find」——这类情况应静默跳过，不算错误。
  bool _isMissingFunction(Object error) {
    final text = error.toString();
    return text.contains('Unable to find') || text.contains('Cannot find');
  }
}

// ---------------------------------------------------------------------------
// 声明式 UI 渲染
// ---------------------------------------------------------------------------

class _ScriptRow {
  const _ScriptRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.action,
    this.color,
    this.sortValue,
    this.coverPath,
    this.coverUrl,
    this.header,
    this.trackId,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final String? action;

  /// 可选的 ARGB 颜色，用于在行左侧渲染一个色点。
  final int? color;

  /// 可选的排序值：当页面声明了 `sort` 时，宿主据此在各自分组内排序。
  final num? sortValue;

  /// 封面本地路径（可空）。
  final String? coverPath;

  /// 封面网络地址（可空）。
  final String? coverUrl;

  /// 非空表示这是一个分组标题行，渲染为小标题而非曲目行。
  final String? header;

  /// 曲目 id（供多选 / 播放定位）。
  final String? trackId;

  factory _ScriptRow.fromJson(Map<String, dynamic> json) => _ScriptRow(
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        trailing: json['trailing']?.toString(),
        action: json['action']?.toString(),
        color: (json['color'] as num?)?.toInt(),
        sortValue: json['sortValue'] as num?,
        coverPath: json['coverPath']?.toString(),
        coverUrl: json['coverUrl']?.toString(),
        header: json['header']?.toString(),
        trackId: json['trackId']?.toString(),
      );
}

class _ScriptPage extends StatefulWidget {
  const _ScriptPage({required this.adapter});

  final ScriptPluginAdapter adapter;

  @override
  State<_ScriptPage> createState() => _ScriptPageState();
}

class _ScriptPageState extends State<_ScriptPage> {
  List<_ScriptRow> _rows = const [];
  String _sortDir = 'desc';
  final Set<String> _selectedIds = {};

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final sortable = widget.adapter.pageSortable;
    var rows = sortable
        ? widget.adapter._readRows('pageRows', [_sortDir])
        : widget.adapter._readRows('pageRows');
    if (sortable) {
      // 排序放在宿主（纯 Dart）进行，避免依赖 dart_eval 里不可靠的 List.sort。
      // 按 header 分组，组内排序，保证分组标题不被混排。
      rows = _sortSections(rows);
    }
    debugPrint('[ScriptPage] 刷新 sortDir=$_sortDir 行数=${rows.length}');
    if (mounted) setState(() => _rows = rows);
  }

  List<_ScriptRow> _sortSections(List<_ScriptRow> rows) {
    final result = <_ScriptRow>[];
    var section = <_ScriptRow>[];
    void flush() {
      final sorted = List.of(section);
      sorted.sort((a, b) {
        final av = a.sortValue ?? 0;
        final bv = b.sortValue ?? 0;
        return _sortDir == 'desc' ? bv.compareTo(av) : av.compareTo(bv);
      });
      result.addAll(sorted);
      section = [];
    }

    for (final row in rows) {
      if (row.header != null) {
        flush();
        result.add(row);
      } else {
        section.add(row);
      }
    }
    flush();
    return result;
  }

  void _toggle(_ScriptRow row) {
    final id = row.trackId;
    if (id == null) return;
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  /// 行点击：`play:` 前缀由宿主直接播放曲目，其余转发给脚本的
  /// `onPageAction`（dart_eval 里做字符串解析不可靠，故放在宿主）。
  void _handleTap(_ScriptRow row) {
    final action = row.action;
    if (action != null && action.startsWith('play:')) {
      final id = action.substring('play:'.length);
      final library = widget.adapter._context?.library;
      final player = widget.adapter._context?.player;
      final track = library?.trackById(id);
      if (track != null) player?.playTrack(track);
      return;
    }
    widget.adapter._fireAction('onPageAction', action);
  }

  List<String> _selectedTrackIds() => _selectedIds.toList(growable: false);

  Future<void> _addSelectedToPlaylist() async {
    await showAddToPlaylistSheet(context, _selectedTrackIds());
    if (mounted) setState(_selectedIds.clear);
  }

  Future<void> _removeSelected() async {
    final library = widget.adapter._context?.library;
    if (library == null) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从曲库移除'),
        content: Text('确定要移除选中的 $count 首曲目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      library.removeTracks(_selectedTrackIds());
      if (mounted) setState(_selectedIds.clear);
    }
  }

  Future<void> _downloadSelected() async {
    final library = widget.adapter._context?.library;
    final downloads = widget.adapter._context?.downloads;
    if (library == null || downloads == null) return;
    final tracks = library.tracksByIds(_selectedTrackIds());
    final started = await downloads.downloadAll(tracks);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            started > 0 ? '已开始下载 $started 首' : '无法下载：缺少缓存或服务器地址'),
        duration: const Duration(milliseconds: 1500),
      ));
      setState(_selectedIds.clear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortable = widget.adapter.pageSortable;
    final scheme = Theme.of(context).colorScheme;

    final list = _rows.isEmpty
        ? ListView(
            children: const [
              SizedBox(height: 120),
              Center(child: Text('暂无内容')),
            ],
          )
        : ListView.builder(
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final row = _rows[index];
              if (row.header != null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    row.header!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                );
              }
              final selected =
                  row.trackId != null && _selectedIds.contains(row.trackId);
              final tile = ListTile(
                leading: _selectionMode
                    ? (row.trackId == null
                        ? null
                        : Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ))
                    : _ScriptCover(
                        fs: widget.adapter._context?.fs,
                        path: row.coverPath,
                        url: row.coverUrl,
                      ),
                title: Text(row.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: row.subtitle == null
                    ? null
                    : Text(row.subtitle!,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: row.color != null
                    ? _ColorDot(color: row.color!)
                    : (row.trailing == null ? null : Text(row.trailing!)),
                onTap: _selectionMode
                    ? () => _toggle(row)
                    : () => _handleTap(row),
                onLongPress: _selectionMode
                    ? null
                    : (row.trackId == null ? null : () => _toggle(row)),
              );
              // 桌面端：右键等同于长按，进入/退出多选（无 trackId 的行忽略）。
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTap: () => _toggle(row),
                child: tile,
              );
            },
          );

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: Column(
        children: [
          if (sortable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton.icon(
                    icon: Icon(
                      _sortDir == 'desc'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 18,
                    ),
                    label: Text(_sortDir == 'desc' ? '倒序' : '正序'),
                    onPressed: () {
                      _sortDir = _sortDir == 'desc' ? 'asc' : 'desc';
                      _reload();
                    },
                  ),
                ],
              ),
            ),
          if (_selectionMode)
            _ScriptSelectionBar(
              count: _selectedIds.length,
              onClose: () => setState(_selectedIds.clear),
              onAddToPlaylist: _addSelectedToPlaylist,
              onDownload: _downloadSelected,
              onRemove: _removeSelected,
            ),
          Expanded(child: list),
        ],
      ),
    );
  }
}

class _ScriptCover extends StatefulWidget {
  const _ScriptCover({required this.fs, required this.path, required this.url});

  final PlatformFileSystem? fs;
  final String? path;
  final String? url;

  @override
  State<_ScriptCover> createState() => _ScriptCoverState();
}

class _ScriptCoverState extends State<_ScriptCover> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ScriptCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    final path = widget.path;
    final fs = widget.fs;
    if (path == null || path.isEmpty || fs == null) return;
    final bytes = await fs.readBytes(path);
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.music_note,
        color: Theme.of(context).colorScheme.outline, size: 20);
    final bytes = _bytes;
    final Widget child;
    if (bytes != null) {
      child = Image.memory(bytes,
          fit: BoxFit.cover,
          width: 36,
          height: 36,
          errorBuilder: (_, _, _) => fallback);
    } else if (widget.url != null && widget.url!.isNotEmpty) {
      child = Image.network(widget.url!,
          fit: BoxFit.cover,
          width: 36,
          height: 36,
          errorBuilder: (_, _, _) => fallback);
    } else {
      child = fallback;
    }
    return ClipOval(child: SizedBox(width: 36, height: 36, child: child));
  }
}

class _ScriptSelectionBar extends StatelessWidget {
  const _ScriptSelectionBar({
    required this.count,
    required this.onClose,
    required this.onAddToPlaylist,
    required this.onDownload,
    required this.onRemove,
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            IconButton(
              tooltip: '退出多选',
              icon: const Icon(Icons.close),
              color: scheme.onPrimaryContainer,
              onPressed: onClose,
            ),
            Expanded(
              child: Text(
                '已选 $count 首',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: '添加到歌单',
              icon: const Icon(Icons.playlist_add),
              color: scheme.onPrimaryContainer,
              onPressed: onAddToPlaylist,
            ),
            IconButton(
              tooltip: '下载',
              icon: const Icon(Icons.download_outlined),
              color: scheme.onPrimaryContainer,
              onPressed: onDownload,
            ),
            IconButton(
              tooltip: '从曲库移除',
              icon: const Icon(Icons.delete_outline),
              color: scheme.onPrimaryContainer,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScriptSettingsSection extends StatefulWidget {
  const _ScriptSettingsSection({required this.adapter});

  final ScriptPluginAdapter adapter;

  @override
  State<_ScriptSettingsSection> createState() => _ScriptSettingsSectionState();
}

class _ScriptSettingsSectionState extends State<_ScriptSettingsSection> {
  List<_ScriptRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _rows = widget.adapter._readRows('settingsTiles');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          ListTile(
            title: Text(row.title),
            subtitle: row.subtitle == null ? null : Text(row.subtitle!),
            trailing: row.color != null
                ? _ColorDot(color: row.color!)
                : (row.trailing == null
                    ? const Icon(Icons.chevron_right)
                    : Text(row.trailing!)),
            onTap: () => widget.adapter._fireAction('onSettingsAction', row.action),
          ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final int color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Color(color),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 图标名 → IconData
// ---------------------------------------------------------------------------

const Map<String, IconData> _icons = {
  'extension': Icons.extension,
  'bar_chart': Icons.bar_chart,
  'palette': Icons.palette,
  'waving_hand': Icons.waving_hand,
  'music_note': Icons.music_note,
  'settings': Icons.settings,
  'cloud': Icons.cloud,
  'star': Icons.star,
  'favorite': Icons.favorite,
  'info': Icons.info,
  'insights': Icons.insights,
  'history': Icons.history,
  'queue_music': Icons.queue_music,
};

IconData _iconFor(String? name) => _icons[name] ?? Icons.extension;
