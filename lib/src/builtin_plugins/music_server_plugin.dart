import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/cache/cache_manager.dart';
import '../core/models/track.dart';
import '../core/plugins/plugin_types.dart';
import '../core/rpc/download.dart';
import '../core/rpc/music_server_client.dart';
import '../core/util/stable_id.dart';
import '../ui/settings/cache_settings_section.dart';

/// 内置插件：通过 RPC 音乐服务器源添加音乐，并把音频下载到缓存。
///
/// 使用 [MusicServerClient]（JSON-RPC 2.0 over HTTP）拉取远端曲目：
/// * 列表元数据**不缓存**——每次连接都请求服务器最新数据；
/// * 音频流下载到缓存后以 [FileTrackSource] 播放（Web 退化为在线流式）。
/// 协议细节见 `docs/RPC.md`。
class MusicServerPlugin extends AcheroPlugin {
  @override
  String get id => 'com.achero.musicServer';

  @override
  String get name => '音乐服务器';

  @override
  String get version => '1.2.4';

  @override
  String get description => '通过 RPC 音乐服务器添加并缓存流式播放曲目。';

  @override
  IconData get icon => Icons.cloud_queue;

  PluginContext? _context;
  CacheManager? _cache;
  Timer? _cleanupTimer;

  static const _keyEndpoint = 'endpoint';
  static const _keyToken = 'token';
  static const _keyPath = 'cachePath';
  static const _keyTtl = 'ttlDays';

  @override
  Future<void> onLoad(PluginContext context) async {
    _context = context;
    await _initCache();
    unawaited(_runCleanup());
    _cleanupTimer =
        Timer.periodic(const Duration(hours: 6), (_) => _runCleanup());
    context.log('已就绪，缓存目录：${_cache?.rootDir ?? '（禁用）'}');
  }

  @override
  Future<void> onUnload() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _context = null;
  }

  Future<void> _initCache() async {
    final prefs = _context?.prefs;
    final fs = _context?.fs;
    if (prefs == null || fs == null || !fs.supportsDirectoryScan) {
      _cache = null;
      return;
    }
    var path = prefs.getString(_keyPath) ?? '';
    if (path.isEmpty) {
      path = await _defaultCacheDir();
      if (path.isEmpty) return;
    }
    final ttlDays = prefs.getInt(_keyTtl) ?? 7;
    final cache = CacheManager(
      fs: fs,
      rootDir: path,
      ttl: Duration(days: ttlDays),
    );
    await cache.init();
    _cache = cache;
  }

  Future<String> _defaultCacheDir() async {
    if (kIsWeb) return '';
    try {
      final dir = await getApplicationSupportDirectory();
      return p.join(dir.path, 'cache', 'rpc');
    } catch (_) {
      return '';
    }
  }

  Future<void> _runCleanup() async {
    final cache = _cache;
    if (cache == null) return;
    try {
      final deleted = await cache.cleanup();
      if (deleted > 0) _context?.log('已清理 $deleted 个过期缓存文件');
    } catch (_) {
      // 清理失败不影响播放。
    }
  }

  Future<void> _setCacheTtl(int days) async {
    await _context?.prefs.setInt(_keyTtl, days);
    _cache?.ttl = Duration(days: days);
  }

  Future<void> _setCachePath(String path) async {
    await _context?.prefs.setString(_keyPath, path);
    await _initCache();
  }

  @override
  List<PluginPage> get pages => [
        PluginPage(
          id: '$id.page',
          title: name,
          icon: icon,
          builder: (_) => _ServerPage(plugin: this),
        ),
      ];

  @override
  List<PluginSettingsSection> get settingsSections => [
        PluginSettingsSection(
          id: '$id.cache',
          title: '缓存',
          builder: (_) => [
            CacheSettingsSection(
              cacheProvider: () => _cache,
              ttlProvider: () => _context?.prefs.getInt(_keyTtl) ?? 7,
              onTtlChanged: _setCacheTtl,
              onPathChanged: _setCachePath,
            ),
          ],
        ),
      ];
}

class _ServerPage extends StatefulWidget {
  const _ServerPage({required this.plugin});

  final MusicServerPlugin plugin;

  @override
  State<_ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<_ServerPage> {
  late final TextEditingController _endpoint = TextEditingController();
  late final TextEditingController _token = TextEditingController();

  bool _loading = false;
  String? _error;
  List<RemoteTrack> _tracks = const [];
  MusicServerClient? _client;

  @override
  void initState() {
    super.initState();
    final prefs = widget.plugin._context?.prefs;
    _endpoint.text = prefs?.getString(MusicServerPlugin._keyEndpoint) ?? '';
    _token.text = prefs?.getString(MusicServerPlugin._keyToken) ?? '';
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _token.dispose();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _endpoint,
                  decoration: const InputDecoration(
                    labelText: '服务器 RPC 地址',
                    hintText: 'http://192.168.1.10:8080/rpc',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '访问令牌（可选）',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _connect,
                  icon: const Icon(Icons.sync),
                  label: Text(_loading ? '连接中…' : '连接并获取列表'),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
              title: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ),
        ],
        if (_error == null && _client != null && _tracks.isEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: scheme.primary),
              title: const Text('未获取到曲目'),
              subtitle: const Text(
                  '请确认地址是 RPC 端点（如 http://localhost:8080/rpc），且服务器实现了 music.list'),
            ),
          ),
        ],
        if (_tracks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('共 ${_tracks.length} 首',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _addAll,
                icon: const Icon(Icons.playlist_add),
                label: const Text('全部添加'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final track in _tracks)
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([track.artist, track.album].whereType<String>().join(' · ')),
              trailing: IconButton(
                tooltip: '添加',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _addOne(track),
              ),
              onTap: () => _addOne(track),
            ),
        ],
      ],
    );
  }

  Future<void> _connect() async {
    final endpoint = _endpoint.text.trim();
    if (endpoint.isEmpty) {
      setState(() => _error = '请输入服务器 RPC 地址');
      return;
    }
    final token = _token.text.trim();
    final prefs = widget.plugin._context?.prefs;
    await prefs?.setString(MusicServerPlugin._keyEndpoint, endpoint);
    await prefs?.setString(MusicServerPlugin._keyToken, token);

    _client?.close();
    final client = MusicServerClient(
      endpoint: endpoint,
      authToken: token.isEmpty ? null : token,
    );

    setState(() {
      _loading = true;
      _error = null;
      _tracks = const [];
    });

    try {
      // ping 仅作健康检查，失败不阻塞——部分服务器可能只实现 music.list。
      try {
        await client.ping();
      } catch (_) {
        // 忽略 ping 失败，继续尝试获取列表。
      }
      // 列表不做缓存：服务器返回什么就显示什么，保证始终是最新数据。
      final tracks = await client.listTracks();
      if (!mounted) {
        client.close();
        return;
      }
      setState(() {
        _tracks = tracks;
        _client = client;
      });
    } on MusicServerException catch (e) {
      client.close();
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      client.close();
      if (mounted) setState(() => _error = '未知错误：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOne(RemoteTrack remote) async {
    final library = widget.plugin._context?.library;
    final client = _client;
    if (library == null || client == null) return;

    try {
      final track = await _buildTrack(remote, client);
      final added = library.addTracks([track]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added > 0 ? '已添加「${remote.title}」' : '「${remote.title}」已在曲库中'),
        duration: const Duration(milliseconds: 1500),
      ));
    } on MusicServerException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('添加失败：${e.message}'),
          duration: const Duration(milliseconds: 1500)));
    }
  }

  Future<void> _addAll() async {
    final library = widget.plugin._context?.library;
    final client = _client;
    if (library == null || client == null || _tracks.isEmpty) return;

    setState(() => _loading = true);
    final built = <Track>[];
    var failures = 0;
    for (final remote in _tracks) {
      try {
        built.add(await _buildTrack(remote, client));
      } catch (_) {
        failures++;
      }
    }
    final added = library.addTracks(built);
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('新增 $added 首${failures > 0 ? '，$failures 首失败' : ''}'),
      duration: const Duration(milliseconds: 1500),
    ));
  }

  /// 解析流地址并缓存音频：命中缓存 → 本地文件；否则下载后播放；
  /// 无缓存能力（Web）→ 在线流式。
  Future<Track> _buildTrack(RemoteTrack remote, MusicServerClient client) async {
    final url = remote.url ?? await client.resolveStreamUrl(remote.id);
    final ext = _extensionFromUrl(url);
    final metadata = <String, dynamic>{
      if (remote.lyrics != null && remote.lyrics!.isNotEmpty) 'lyrics': remote.lyrics,
    };

    final cache = widget.plugin._cache;
    if (cache != null) {
      if (await cache.hasAudio(remote.id, ext)) {
        return _makeTrack(
            remote, client, FileTrackSource(cache.audioPath(remote.id, ext)), metadata);
      }
      final bytes = await downloadStream(Uri.parse(url));
      if (bytes != null) {
        final path = await cache.putAudio(remote.id, ext, bytes);
        return _makeTrack(remote, client, FileTrackSource(path), metadata);
      }
    }
    return _makeTrack(remote, client, UrlTrackSource(url), metadata);
  }

  Track _makeTrack(
    RemoteTrack remote,
    MusicServerClient client,
    TrackSource source,
    Map<String, dynamic> metadata,
  ) {
    return Track(
      id: stableId('${client.endpoint}#${remote.id}', prefix: 'track'),
      title: remote.title,
      artist: remote.artist,
      album: remote.album,
      duration: Duration(milliseconds: remote.durationMs ?? 0),
      source: source,
      coverArtUrl: remote.coverUrl,
      metadata: metadata,
    );
  }

  String _extensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'mp3';
    return path.substring(dot + 1).toLowerCase();
  }
}
