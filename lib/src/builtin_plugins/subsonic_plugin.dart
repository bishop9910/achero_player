import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/cache/cache_manager.dart';
import '../core/models/track.dart';
import '../core/plugins/plugin_types.dart';
import '../core/rpc/subsonic_client.dart';
import '../core/util/stable_id.dart';
import '../ui/settings/cache_settings_section.dart';

/// 内置插件：Subsonic / OpenSubsonic 音乐服务器源。
///
/// 兼容 Navidrome、Airsonic(-Advanced)、Gonic 等主流自托管服务器：
/// 浏览专辑 / 搜索 / 导入曲库，并把**音频文件与 JSON 元数据**缓存到本地
/// （支持自定义路径与 TTL 定期清理）。协议与缓存说明见 `docs/SUBSONIC.md`。
class SubsonicPlugin extends AcheroPlugin {
  @override
  String get id => 'com.achero.subsonic';

  @override
  String get name => 'Subsonic 服务器';

  @override
  String get version => '1.3.0';

  @override
  String get description => '连接 Navidrome / Airsonic 等服务器，导入并缓存音乐。';

  @override
  IconData get icon => Icons.cloud;

  PluginContext? _context;
  CacheManager? _cache;
  Timer? _cleanupTimer;

  static const _keyServer = 'server';
  static const _keyUser = 'username';
  static const _keyPass = 'password';
  static const _keyPath = 'cachePath';
  static const _keyTtl = 'ttlDays';

  @override
  Future<void> onLoad(PluginContext context) async {
    _context = context;
    await _initCache();
    // 启动即清理一次，之后每 6 小时定期清理过期文件。
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
    _context?.downloads.registerCache(TrackOrigin.subsonic, cache);
  }

  Future<String> _defaultCacheDir() async {
    if (kIsWeb) return '';
    try {
      final dir = await getApplicationSupportDirectory();
      return p.join(dir.path, 'cache', 'subsonic');
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
          builder: (_) => _SubsonicPage(plugin: this),
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

// ---------------------------------------------------------------------------
// 主页面
// ---------------------------------------------------------------------------

class _SubsonicPage extends StatefulWidget {
  const _SubsonicPage({required this.plugin});

  final SubsonicPlugin plugin;

  @override
  State<_SubsonicPage> createState() => _SubsonicPageState();
}

class _SubsonicPageState extends State<_SubsonicPage> {
  late final TextEditingController _server = TextEditingController();
  late final TextEditingController _user = TextEditingController();
  late final TextEditingController _pass = TextEditingController();
  final TextEditingController _query = TextEditingController();

  bool _loading = false;
  String? _error;
  SubsonicClient? _client;
  List<SubsonicAlbum> _albums = const [];
  SubsonicSearchResults? _searchResults;

  @override
  void initState() {
    super.initState();
    final prefs = widget.plugin._context?.prefs;
    _server.text = prefs?.getString(SubsonicPlugin._keyServer) ?? '';
    _user.text = prefs?.getString(SubsonicPlugin._keyUser) ?? '';
    _pass.text = prefs?.getString(SubsonicPlugin._keyPass) ?? '';
  }

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    _query.dispose();
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
                  controller: _server,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'http://192.168.1.10:4533',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _user,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pass,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _connect,
                  icon: const Icon(Icons.link),
                  label: Text(_loading ? '连接中…' : '连接'),
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
        if (_client != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(_query.text.trim()),
            decoration: InputDecoration(
              hintText: '搜索歌曲 / 专辑 / 艺术家',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => _search(_query.text.trim()),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          Text('最新专辑', style: Theme.of(context).textTheme.titleMedium),
          if (_albums.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('没有专辑，试试搜索')),
            )
          else
            for (final album in _albums)
              ListTile(
                leading: const Icon(Icons.album_outlined),
                title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(album.artist ?? ''),
                onTap: () => _openAlbum(album),
              ),
          if (_searchResults != null) _buildSearchResults(),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults!;
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('没有匹配结果')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('搜索结果', style: Theme.of(context).textTheme.titleMedium),
        for (final album in results.albums)
          ListTile(
            leading: const Icon(Icons.album),
            title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(album.artist ?? ''),
            onTap: () => _openAlbum(album),
          ),
        for (final song in results.songs)
          ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([song.artist, song.album].whereType<String>().join(' · ')),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => _playSong(song),
          ),
      ],
    );
  }

  Future<void> _connect() async {
    final server = _server.text.trim();
    final user = _user.text.trim();
    final pass = _pass.text;
    if (server.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = '请填写服务器地址、用户名与密码');
      return;
    }
    final prefs = widget.plugin._context?.prefs;
    await prefs?.setString(SubsonicPlugin._keyServer, server);
    await prefs?.setString(SubsonicPlugin._keyUser, user);
    await prefs?.setString(SubsonicPlugin._keyPass, pass);

    _client?.close();
    final client = SubsonicClient(baseUrl: server, username: user, password: pass);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await client.ping();
      final albums = await _cachedAlbums(
        widget.plugin._cache,
        'albumlist-newest',
        () => client.getAlbumList(type: 'newest'),
      );
      if (!mounted) {
        client.close();
        return;
      }
      setState(() {
        _client = client;
        _albums = albums;
      });
    } on SubsonicException catch (e) {
      client.close();
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      client.close();
      if (mounted) setState(() => _error = '未知错误：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    final client = _client;
    if (client == null || query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final results = await _cachedSearch(
        widget.plugin._cache,
        'search-$query',
        () => client.search(query),
      );
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) setState(() => _searchResults = const SubsonicSearchResults());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAlbum(SubsonicAlbum album) {
    final client = _client;
    if (client == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AlbumPage(
          plugin: widget.plugin,
          client: client,
          album: album,
        ),
      ),
    );
  }

  Future<void> _playSong(SubsonicSong song) async {
    final client = _client;
    final player = widget.plugin._context?.player;
    if (client == null || player == null) return;
    final track = await _buildTrack(song, client, widget.plugin._cache);
    if (track == null || !mounted) return;
    await player.playTrack(track);
  }
}

// ---------------------------------------------------------------------------
// 专辑详情页
// ---------------------------------------------------------------------------

class _AlbumPage extends StatefulWidget {
  const _AlbumPage({
    required this.plugin,
    required this.client,
    required this.album,
  });

  final SubsonicPlugin plugin;
  final SubsonicClient client;
  final SubsonicAlbum album;

  @override
  State<_AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<_AlbumPage> {
  List<SubsonicSong> _songs = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _cachedSongs(
        widget.plugin._cache,
        'album-${widget.album.id}',
        () => widget.client.getAlbumSongs(widget.album.id),
      );
      if (mounted) setState(() => _songs = songs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.album.artist ?? ''} · ${_songs.length} 首',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _importAll,
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('导入整张专辑'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final song in _songs)
                      ListTile(
                        leading: song.track != null
                            ? SizedBox(
                                width: 28,
                                child: Center(child: Text('${song.track}')),
                              )
                            : const Icon(Icons.music_note),
                        title: Text(song.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatSeconds(song.durationSec)),
                        trailing: IconButton(
                          tooltip: '导入',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _importSong(song),
                        ),
                        onTap: () => _play(song),
                      ),
                  ],
                ),
    );
  }

  Future<void> _play(SubsonicSong song) async {
    final player = widget.plugin._context?.player;
    if (player == null) return;
    final track = await _buildTrack(song, widget.client, widget.plugin._cache);
    if (track == null) return;
    await player.playTrack(track);
  }

  Future<void> _importSong(SubsonicSong song) async {
    await _import([song]);
  }

  Future<void> _importAll() async {
    await _import(_songs);
  }

  Future<void> _import(List<SubsonicSong> songs) async {
    final library = widget.plugin._context?.library;
    if (library == null) return;
    setState(() => _loading = true);
    final tracks = <Track>[];
    var failures = 0;
    for (final song in songs) {
      final track = await _buildTrack(song, widget.client, widget.plugin._cache);
      if (track != null) {
        tracks.add(track);
      } else {
        failures++;
      }
    }
    final added = library.addTracks(tracks);
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('新增 $added 首${failures > 0 ? '，$failures 首失败' : ''}'),
      duration: const Duration(milliseconds: 1500),
    ));
  }
}

// ---------------------------------------------------------------------------
// 共享工具函数
// ---------------------------------------------------------------------------

Future<List<SubsonicAlbum>> _cachedAlbums(
  CacheManager? cache,
  String key,
  Future<List<SubsonicAlbum>> Function() fetch,
) async {
  final cached = await cache?.getJson(key);
  if (cached != null) {
    return (jsonDecode(cached) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(SubsonicAlbum.fromJson)
        .toList(growable: false);
  }
  final list = await fetch();
  await cache?.putJson(
    key,
    jsonEncode(list.map((e) => e.toJson()).toList(growable: false)),
  );
  return list;
}

Future<List<SubsonicSong>> _cachedSongs(
  CacheManager? cache,
  String key,
  Future<List<SubsonicSong>> Function() fetch,
) async {
  final cached = await cache?.getJson(key);
  if (cached != null) {
    return (jsonDecode(cached) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(SubsonicSong.fromJson)
        .toList(growable: false);
  }
  final list = await fetch();
  await cache?.putJson(
    key,
    jsonEncode(list.map((e) => e.toJson()).toList(growable: false)),
  );
  return list;
}

Future<SubsonicSearchResults> _cachedSearch(
  CacheManager? cache,
  String key,
  Future<SubsonicSearchResults> Function() fetch,
) async {
  final cached = await cache?.getJson(key);
  if (cached != null) {
    final map = jsonDecode(cached) as Map<String, dynamic>;
    return SubsonicSearchResults(
      artists: (map['artists'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubsonicArtist.fromJson)
          .toList(growable: false),
      albums: (map['albums'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubsonicAlbum.fromJson)
          .toList(growable: false),
      songs: (map['songs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubsonicSong.fromJson)
          .toList(growable: false),
    );
  }
  final results = await fetch();
  await cache?.putJson(
    key,
    jsonEncode({
      'artists': results.artists.map((e) => e.toJson()).toList(growable: false),
      'albums': results.albums.map((e) => e.toJson()).toList(growable: false),
      'songs': results.songs.map((e) => e.toJson()).toList(growable: false),
    }),
  );
  return results;
}

/// 把歌曲转为可播放的 [Track]：**不下载音频**，命中缓存用本地文件，
/// 否则在线流式（保证「导入」很快）。封面复用已缓存项。
Future<Track?> _buildTrack(
  SubsonicSong song,
  SubsonicClient client,
  CacheManager? cache,
) async {
  final ext = _audioExtension(song);
  final url = client.streamUri(song.id).toString();
  final coverPath = (cache != null && await cache.hasCover(song.id))
      ? cache.coverPath(song.id)
      : null;
  if (cache != null && await cache.hasAudio(song.id, ext)) {
    return _makeTrack(song, client, FileTrackSource(cache.audioPath(song.id, ext)),
        coverPath: coverPath, remoteUrl: url);
  }
  return _makeTrack(song, client, UrlTrackSource(url),
      coverPath: coverPath, remoteUrl: url);
}

Track _makeTrack(SubsonicSong song, SubsonicClient client, TrackSource source,
    {String? coverPath, required String remoteUrl}) {
  return Track(
    id: stableId('subsonic:${client.baseUrl}#${song.id}', prefix: 'track'),
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: Duration(seconds: song.durationSec ?? 0),
    source: source,
    coverArtPath: coverPath,
    coverArtUrl: song.coverArt == null
        ? null
        : client.coverArtUri(song.coverArt!).toString(),
    origin: TrackOrigin.subsonic,
    remoteUrl: remoteUrl,
  );
}

String _audioExtension(SubsonicSong song) {
  final suffix = song.suffix?.toLowerCase();
  if (suffix != null && suffix.isNotEmpty) return suffix;
  return switch (song.contentType) {
    'audio/mpeg' => 'mp3',
    'audio/flac' => 'flac',
    'audio/mp4' || 'audio/x-m4a' => 'm4a',
    'audio/ogg' => 'ogg',
    'audio/aac' => 'aac',
    'audio/wav' => 'wav',
    'audio/opus' => 'opus',
    _ => 'mp3',
  };
}

String formatSeconds(int? seconds) {
  if (seconds == null) return '';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
