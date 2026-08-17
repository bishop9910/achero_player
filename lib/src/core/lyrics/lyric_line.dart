import 'package:flutter/foundation.dart';

/// 增强型 LRC 中的单字时间轴。
@immutable
class LyricWord {
  const LyricWord(this.time, this.text);

  final Duration time;
  final String text;

  @override
  String toString() => 'LyricWord($time, $text)';
}

/// 一行歌词：在某个时间点出现的文本。
@immutable
class LyricLine {
  const LyricLine({required this.time, required this.text, this.words = const []});

  /// 该行应开始显示的时间点（含全局 offset 校正）。
  final Duration time;

  /// 去掉时间标签后的纯文本。
  final String text;

  /// 增强型 LRC 的逐字时间轴（无则为空）。
  final List<LyricWord> words;

  bool get isInstrumental => text.trim().isEmpty;

  @override
  String toString() => 'LyricLine($time, "$text")';
}
