import 'package:flutter/foundation.dart';

import 'lyric_line.dart';

/// 解析后的歌词文档。
@immutable
class LyricDocument {
  const LyricDocument({
    this.title,
    this.artist,
    this.album,
    this.by,
    this.offset = Duration.zero,
    this.lines = const [],
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? by;

  /// 全局时间偏移（`[offset:...]`），正值表示整体提前。
  final Duration offset;

  /// 按时间升序排列的歌词行。
  final List<LyricLine> lines;

  bool get isEmpty => lines.isEmpty;

  /// 当前时间点应高亮的行下标；无匹配返回 -1。
  int activeIndexAt(Duration position) {
    if (lines.isEmpty) return -1;
    var index = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  @override
  String toString() => 'LyricDocument(${lines.length} lines)';
}

/// LRC 歌词解析器。
///
/// 支持：
/// * 标准元数据标签 `[ti:] [ar:] [al:] [by:] [offset:]`；
/// * 一行多个时间戳（逐次展开为多行）；
/// * 增强型 LRC 逐字时间轴 `<mm:ss.xx>`；
/// * `mm:ss` / `mm:ss.xx` / `mm:ss.xxx` 时间格式。
class LrcParser {
  const LrcParser();

  static final RegExp _metadataTag =
      RegExp(r'^\[(ti|ar|al|by|offset):(.*)\]$');
  static final RegExp _timeTag =
      RegExp(r'\[(\d{1,3}):(\d{1,2})(?:\.(\d{1,3}))?\]');
  static final RegExp _wordTag =
      RegExp(r'<(\d{1,3}):(\d{1,2})(?:\.(\d{1,3}))?>');

  /// 解析一段 LRC 文本。格式非法时返回空文档而非抛异常，保证播放器健壮。
  LyricDocument parse(String raw) {
    String? title, artist, album, by;
    var offset = Duration.zero;
    final lines = <LyricLine>[];

    for (final originalLine in raw.split(RegExp(r'\r?\n'))) {
      final line = originalLine.trim();
      if (line.isEmpty) continue;

      final meta = _metadataTag.firstMatch(line);
      if (meta != null) {
        final key = meta.group(1)!;
        final value = meta.group(2)!.trim();
        switch (key) {
          case 'ti':
            title = value;
            break;
          case 'ar':
            artist = value;
            break;
          case 'al':
            album = value;
            break;
          case 'by':
            by = value;
            break;
          case 'offset':
            offset = _parseOffset(value);
            break;
        }
        continue;
      }

      // 收集本行所有时间戳。
      final timestamps = <Duration>[];
      for (final m in _timeTag.allMatches(line)) {
        timestamps.add(_parseTimestamp(m));
      }
      if (timestamps.isEmpty) continue;

      // 移除所有 [..] 时间标签后得到歌词正文（保留增强型 <..> 供逐字解析）。
      var text = line;
      for (final m in _timeTag.allMatches(line).toList().reversed) {
        text = text.replaceRange(m.start, m.end, '');
      }
      text = text.trim();

      final words = _parseWords(text, offset);

      for (final t in timestamps) {
        lines.add(
          LyricLine(
            time: t + offset,
            text: _stripWordTags(text),
            words: words,
          ),
        );
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));
    return LyricDocument(
      title: title,
      artist: artist,
      album: album,
      by: by,
      offset: offset,
      lines: List.unmodifiable(lines),
    );
  }

  Duration _parseTimestamp(RegExpMatch m) {
    final minutes = int.parse(m.group(1)!);
    final seconds = int.parse(m.group(2)!);
    final fraction = m.group(3);
    final millis = fraction == null
        ? 0
        : int.parse(fraction.padRight(3, '0').substring(0, 3));
    return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  Duration _parseOffset(String raw) {
    final value = int.tryParse(raw.trim());
    return value == null ? Duration.zero : Duration(milliseconds: value);
  }

  /// 解析增强型 LRC 逐字时间轴。
  ///
  /// 每个 `<mm:ss.xx>` 之后的文本属于该时间点，直到下一个词标签或行尾。
  List<LyricWord> _parseWords(String text, Duration offset) {
    final matches = _wordTag.allMatches(text).toList();
    if (matches.isEmpty) return const [];

    final words = <LyricWord>[];
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final time = _parseWordTimestamp(m);
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final wordText = text.substring(m.end, end).trim();
      words.add(LyricWord(time + offset, wordText));
    }
    return words;
  }

  Duration _parseWordTimestamp(RegExpMatch m) {
    final minutes = int.parse(m.group(1)!);
    final seconds = int.parse(m.group(2)!);
    final fraction = m.group(3);
    final millis = fraction == null
        ? 0
        : int.parse(fraction.padRight(3, '0').substring(0, 3));
    return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  String _stripWordTags(String text) => text.replaceAll(_wordTag, '').trim();
}
