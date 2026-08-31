import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/lyrics/lrc_parser.dart';
import '../../core/player/player_controller.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/theme_factory.dart';

/// 滚动歌词视图。
///
/// 跟随播放进度自动定位当前行，并严格遵循 [LyricSettings]：
/// * 显示位置（顶部 / 居中 / 底部）与垂直偏移；
/// * 字号、高亮色与字体族。
/// 点击任意一行可跳转到对应时间。
///
/// 歌词行高度按「实际换行数」动态计算，**绝不省略**：单行/双行保持原有节奏，
/// 长句换到第三行及以上时整行撑开完整显示，不做 `TextOverflow.ellipsis`。
class LyricsView extends StatefulWidget {
  const LyricsView({super.key});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scroll = ScrollController();
  int _lastActive = -1;
  double _viewportHeight = 0;
  double _lineHeight = 32;

  // 可变行高测量缓存：歌词 / 宽度 / 字号 / 字体 / 当前行不变时直接复用，
  // 避免播放进度高频刷新时反复对整首歌做文本排版。
  Object? _cacheLyrics;
  String _cacheKey = '';
  List<double> _itemHeights = const [];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final appSettings = context.watch<SettingsController>().settings;
    final lyricSettings = appSettings.lyrics;
    final lyrics = player.lyrics;
    final scheme = Theme.of(context).colorScheme;

    if (lyrics == null || lyrics.lines.isEmpty) {
      return const _EmptyLyrics();
    }

    final active = lyrics.activeIndexAt(player.position);
    if (active != _lastActive) {
      _lastActive = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollTo(active, lyricSettings);
      });
    }

    final fontSize = lyricSettings.fontSize * appSettings.font.lyricsScale;
    final lineHeight = fontSize * 1.8;
    _lineHeight = lineHeight;
    final highlightColor = lyricSettings.highlightColor != null
        ? Color(lyricSettings.highlightColor!)
        : scheme.primary;

    final activeStyle = ThemeFactory.lyricTextStyle(
      appSettings,
      highlightColor,
      fontSize * 1.12,
    ).copyWith(fontWeight: FontWeight.w700);

    final baseStyle = ThemeFactory.lyricTextStyle(
      appSettings,
      scheme.onSurfaceVariant,
      fontSize,
    ).copyWith(fontWeight: FontWeight.w400);

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        _itemHeights = _measureHeights(
          lyrics: lyrics,
          width: constraints.maxWidth,
          lineHeight: lineHeight,
          active: active,
          activeStyle: activeStyle,
          baseStyle: baseStyle,
        );

        return ListView.builder(
          controller: _scroll,
          // 每行按实际换行数独立定高：歌词再长也完整展示，不会省略成 …。
          itemExtentBuilder: (index, _) => _itemHeights[index],
          // 上下留白使首尾行也能滚动到居中。
          padding: EdgeInsets.symmetric(
            vertical: (_viewportHeight - lineHeight * 2) / 2,
          ),
          itemCount: lyrics.lines.length,
          itemBuilder: (context, index) {
            final line = lyrics.lines[index];
            final isActive = index == active;
            return _LyricLineTile(
              text: line.text,
              isActive: isActive,
              style: isActive ? activeStyle : baseStyle,
              onTap: () => player.seek(line.time),
            );
          },
        );
      },
    );
  }

  /// 计算每行歌词占用的高度（以 [lineHeight] 为一行槽位的整数倍）。
  ///
  /// 用 [TextPainter] 以实际渲染样式测量换行数；当前行用高亮样式（字号略大、
  /// 加粗）测量，保证它成为当前行时也不会因字重变化而重新换行挤出。
  List<double> _measureHeights({
    required LyricDocument lyrics,
    required double width,
    required double lineHeight,
    required int active,
    required TextStyle activeStyle,
    required TextStyle baseStyle,
  }) {
    final key = '${baseStyle.fontFamily}|'
        '${baseStyle.fontFamilyFallback?.join(',')}|'
        '${baseStyle.fontSize}|'
        '${activeStyle.fontFamily}|'
        '${activeStyle.fontSize}|'
        '$active';
    if (identical(_cacheLyrics, lyrics) && _cacheKey == key) {
      return _itemHeights;
    }

    final heights = <double>[];
    for (var i = 0; i < lyrics.lines.length; i++) {
      final line = lyrics.lines[i];
      final style = i == active ? activeStyle : baseStyle;
      final painter = TextPainter(
        text: TextSpan(text: line.text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: null,
      )..layout(maxWidth: width > 0 ? width : double.infinity);

      var lineCount = painter.computeLineMetrics().length;
      if (lineCount < 1) lineCount = 1;
      // 单行/双行保持原有两行高度节奏；三行及以上按实际行数撑开，不截断。
      final slots = lineCount < 2 ? 2 : lineCount;
      heights.add(slots * lineHeight);
    }

    _cacheLyrics = lyrics;
    _cacheKey = key;
    _itemHeights = heights;
    return heights;
  }

  void _scrollTo(int active, LyricSettings settings) {
    if (!_scroll.hasClients) return;
    final topPad = (_viewportHeight - _lineHeight * 2) / 2;

    var before = topPad;
    final index = active.clamp(0, _itemHeights.length - 1);
    for (var i = 0; i < index && i < _itemHeights.length; i++) {
      before += _itemHeights[i];
    }
    final h = _itemHeights.isEmpty ? 0.0 : _itemHeights[index];

    final anchor = switch (settings.alignment) {
      LyricAlignment.top => 0.0,
      LyricAlignment.bottom => 1.0,
      LyricAlignment.center => 0.5,
    };
    final target = before +
        h * anchor -
        _viewportHeight * anchor +
        settings.verticalOffset;
    final clamped = target.clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      clamped,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }
}

class _LyricLineTile extends StatelessWidget {
  const _LyricLineTile({
    required this.text,
    required this.isActive,
    required this.style,
    required this.onTap,
  });

  final String text;
  final bool isActive;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: style,
          child: Text(
            text,
            // 歌词必须完整展示，不限制行数、不做溢出省略。
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lyrics_outlined,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            '暂无歌词',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 4),
          Text(
            '将同名 .lrc 文件放在歌曲旁即可自动加载',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
