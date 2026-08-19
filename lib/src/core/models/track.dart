import 'package:flutter/foundation.dart';

/// 曲目音频来源的抽象基类。
///
/// 由于 Achero 面向 Windows / Linux / Android / Web 四个平台，
/// 音频来源被抽象为三类：
/// * 桌面 / 移动端使用 [FileTrackSource]（`dart:io` 可直接读取文件）；
/// * Web 端没有文件系统，使用 [BytesTrackSource]（从文件选择器读入内存）；
/// * 网络 / RPC 音乐服务器使用 [UrlTrackSource]（HTTP 流式播放）。
sealed class TrackSource {
  const TrackSource();

  /// 该来源是否可以被持久化（内存字节无法跨会话持久化）。
  bool get isPersistable => true;

  /// 用于展示 / 诊断的人类可读标识。
  String get displayPath;
}

/// 指向本地磁盘文件的曲目来源（Windows / Linux / Android / macOS）。
@immutable
class FileTrackSource extends TrackSource {
  const FileTrackSource(this.path);

  /// 音频文件的绝对路径。
  final String path;

  @override
  String get displayPath => path;

  @override
  bool operator ==(Object other) =>
      other is FileTrackSource && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// 驻留内存的曲目来源（Web）。
@immutable
class BytesTrackSource extends TrackSource {
  const BytesTrackSource({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String mimeType;

  @override
  bool get isPersistable => false;

  @override
  String get displayPath => fileName;

  @override
  bool operator ==(Object other) =>
      other is BytesTrackSource &&
      other.fileName == fileName &&
      listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(fileName, Object.hashAll(bytes));
}

/// 指向网络流媒体的曲目来源（RPC 音乐服务器 / 在线音频）。
///
/// 鉴权由服务器在 URL 中携带签名令牌（query 参数），而非自定义请求头。
@immutable
class UrlTrackSource extends TrackSource {
  const UrlTrackSource(this.url, {this.mimeType});

  /// 可直接播放的流媒体 URL。
  final String url;

  /// 可选 MIME 类型提示。
  final String? mimeType;

  @override
  String get displayPath => url;

  @override
  bool operator ==(Object other) =>
      other is UrlTrackSource && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// 音源类型（音乐来源），用于在播放页标识当前曲目来自哪里。
enum TrackOrigin {
  local('本地'),
  rpc('RPC'),
  subsonic('Subsonic');

  const TrackOrigin(this.label);

  /// 展示用名称。
  final String label;
}

/// 一首可播放的曲目。
///
/// 元数据（标题 / 艺术家 / 专辑）默认由 [LibraryScanner] 从文件名与目录结构推断，
/// 也可以由插件或外部标签读取器补充到 [metadata] 中。
@immutable
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.source,
    this.artist,
    this.album,
    this.trackNumber,
    this.duration = Duration.zero,
    this.coverArtPath,
    this.coverArtUrl,
    this.lyricsPath,
    this.metadata = const {},
    this.origin = TrackOrigin.local,
    this.remoteUrl,
  });

  /// 稳定的唯一标识。文件来源通常基于路径哈希，保证跨会话一致。
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final int? trackNumber;
  final Duration duration;
  final TrackSource source;

  /// 音源类型（本地 / RPC / Subsonic）。
  final TrackOrigin origin;

  /// 服务器流地址（RPC / Subsonic 源；本地曲目为 null）。
  ///
  /// 下载后仍保留：本地文件缺失/损坏时回退到该地址在线播放，或重新下载。
  final String? remoteUrl;

  /// 封面图本地路径（可空）。
  final String? coverArtPath;

  /// 封面图网络地址（可空，RPC / Subsonic 等服务器源提供）。
  final String? coverArtUrl;

  /// 歌词文件（.lrc）路径（可空）。
  final String? lyricsPath;

  /// 可扩展的附加元数据，插件可读写（如 BPM、风格、评分等）。
  final Map<String, dynamic> metadata;

  /// 歌曲标题下方的副标题（艺术家 · 专辑）。
  String get subtitle {
    final parts = <String>[
      if (artist != null && artist!.isNotEmpty) artist!,
      if (album != null && album!.isNotEmpty) album!,
    ];
    return parts.join(' · ');
  }

  /// 文件扩展名（无点号，小写）。内存来源使用 [BytesTrackSource.fileName]，
  /// 网络来源使用 [UrlTrackSource.url] 的路径部分。
  String get extension {
    final name = switch (source) {
      FileTrackSource(:final path) => path,
      BytesTrackSource(:final fileName) => fileName,
      UrlTrackSource(:final url) => Uri.tryParse(url)?.path ?? url,
    };
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    int? trackNumber,
    Duration? duration,
    TrackSource? source,
    String? coverArtPath,
    String? coverArtUrl,
    String? lyricsPath,
    Map<String, dynamic>? metadata,
    TrackOrigin? origin,
    String? remoteUrl,
    bool clearArtist = false,
    bool clearAlbum = false,
  }) {
    return Track(
      id: id,
      title: title ?? this.title,
      artist: clearArtist ? null : (artist ?? this.artist),
      album: clearAlbum ? null : (album ?? this.album),
      trackNumber: trackNumber ?? this.trackNumber,
      duration: duration ?? this.duration,
      source: source ?? this.source,
      coverArtPath: coverArtPath ?? this.coverArtPath,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      lyricsPath: lyricsPath ?? this.lyricsPath,
      metadata: metadata ?? this.metadata,
      origin: origin ?? this.origin,
      remoteUrl: remoteUrl ?? this.remoteUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'trackNumber': trackNumber,
        'durationMs': duration.inMilliseconds,
        'source': _sourceToJson(source),
        'coverArtPath': coverArtPath,
        'coverArtUrl': coverArtUrl,
        'lyricsPath': lyricsPath,
        'metadata': metadata,
        'origin': origin.name,
        'remoteUrl': remoteUrl,
      };

  static Track fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        trackNumber: json['trackNumber'] as int?,
        duration: Duration(milliseconds: (json['durationMs'] as int?) ?? 0),
        source: _sourceFromJson(json['source'] as Map<String, dynamic>),
        coverArtPath: json['coverArtPath'] as String?,
        coverArtUrl: json['coverArtUrl'] as String?,
        lyricsPath: json['lyricsPath'] as String?,
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
        origin: _originFromName(json['origin'] as String?),
        remoteUrl: json['remoteUrl'] as String?,
      );

  static Map<String, dynamic> _sourceToJson(TrackSource source) =>
      switch (source) {
        FileTrackSource(:final path) => {'type': 'file', 'path': path},
        // 内存来源不可持久化，仅保留文件名作为占位（重载时会被丢弃）。
        BytesTrackSource(:final fileName) => {
            'type': 'bytes',
            'fileName': fileName,
          },
        UrlTrackSource(:final url, :final mimeType) => {
            'type': 'url',
            'url': url,
            'mimeType': mimeType,
          },
      };

  static TrackSource _sourceFromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'file' => FileTrackSource(json['path'] as String),
      'url' => UrlTrackSource(
          json['url'] as String,
          mimeType: json['mimeType'] as String?,
        ),
      _ => throw ArgumentError('无法解析的曲目来源: ${json['type']}'),
    };
  }

  static TrackOrigin _originFromName(String? name) =>
      TrackOrigin.values.asNameMap()[name] ?? TrackOrigin.local;

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($title, id=$id)';
}
