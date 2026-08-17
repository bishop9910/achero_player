import 'dart:async';
import 'dart:convert';

import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:flutter/material.dart';

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
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final String? action;

  /// 可选的 ARGB 颜色，用于在行左侧渲染一个色点。
  final int? color;

  factory _ScriptRow.fromJson(Map<String, dynamic> json) => _ScriptRow(
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        trailing: json['trailing']?.toString(),
        action: json['action']?.toString(),
        color: (json['color'] as num?)?.toInt(),
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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final sortable = widget.adapter.pageSortable;
    final rows = sortable
        ? widget.adapter._readRows('pageRows', [_sortDir])
        : widget.adapter._readRows('pageRows');
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final sortable = widget.adapter.pageSortable;

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
              return ListTile(
                title: Text(row.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: row.subtitle == null
                    ? null
                    : Text(row.subtitle!,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: row.color != null
                    ? _ColorDot(color: row.color!)
                    : (row.trailing == null ? null : Text(row.trailing!)),
                onTap: () => widget.adapter._fireAction('onPageAction', row.action),
              );
            },
          );

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: sortable
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Spacer(),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'desc', label: Text('倒序')),
                          ButtonSegment(value: 'asc', label: Text('正序')),
                        ],
                        selected: {_sortDir},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          _sortDir = selection.first;
                          _reload();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(child: list),
              ],
            )
          : list,
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
