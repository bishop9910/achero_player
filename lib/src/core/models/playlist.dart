import 'package:flutter/foundation.dart';

import 'track.dart';

/// 一个播放列表：有序的曲目 id 集合。
///
/// 列表存储 [Track.id] 而非对象引用，便于跨会话持久化，
/// 且当曲库重扫后 id 仍可稳定对应到曲目。
@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.trackIds = const [],
    this.coverTrackId,
    this.isFavorite = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;

  /// 有序的曲目 id 列表。
  final List<String> trackIds;

  /// 用作封面的曲目 id（可选）。
  final String? coverTrackId;

  /// 「我最喜爱」等系统列表的标记。
  final bool isFavorite;

  final DateTime? createdAt;

  int get trackCount => trackIds.length;

  Playlist copyWith({
    String? name,
    String? description,
    List<String>? trackIds,
    String? coverTrackId,
    bool? isFavorite,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackIds: trackIds ?? this.trackIds,
      coverTrackId: coverTrackId ?? this.coverTrackId,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
    );
  }

  /// 追加一首曲目，若已存在则返回自身（幂等）。
  Playlist addTrack(String trackId) {
    if (trackIds.contains(trackId)) return this;
    return copyWith(trackIds: [...trackIds, trackId]);
  }

  Playlist removeTrack(String trackId) {
    if (!trackIds.contains(trackId)) return this;
    return copyWith(
      trackIds: trackIds.where((id) => id != trackId).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'trackIds': trackIds,
        'coverTrackId': coverTrackId,
        'isFavorite': isFavorite,
        'createdAt': createdAt?.toIso8601String(),
      };

  static Playlist fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        trackIds: (json['trackIds'] as List<dynamic>?)?.cast<String>() ??
            const [],
        coverTrackId: json['coverTrackId'] as String?,
        isFavorite: json['isFavorite'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) => other is Playlist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
