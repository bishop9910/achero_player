import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        _scrollTo(active, lyricSettings);
      });
    }

    final fontSize = lyricSettings.fontSize * appSettings.font.lyricsScale;
    final lineHeight = fontSize * 1.8;
    _lineHeight = lineHeight;
    final highlightColor = lyricSettings.highlightColor != null
        ? Color(lyricSettings.highlightColor!)
        : scheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        return ListView.builder(
          controller: _scroll,
          itemExtent: lineHeight,
          // 上下留白使首尾行也能滚动到居中。
          padding: EdgeInsets.symmetric(
            vertical: (_viewportHeight - lineHeight) / 2,
          ),
          itemCount: lyrics.lines.length,
          itemBuilder: (context, index) {
            final line = lyrics.lines[index];
            final isActive = index == active;
            return _LyricLineTile(
              text: line.text,
              isActive: isActive,
              style: ThemeFactory.lyricTextStyle(
                appSettings,
                isActive ? highlightColor : scheme.onSurfaceVariant,
                isActive ? fontSize * 1.12 : fontSize,
              ).copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
              onTap: () => player.seek(line.time),
            );
          },
        );
      },
    );
  }

  void _scrollTo(int active, LyricSettings settings) {
    if (!_scroll.hasClients) return;
    final lineHeight = _lineHeight;
    final anchor = switch (settings.alignment) {
      LyricAlignment.top => 0.0,
      LyricAlignment.bottom => 1.0,
      LyricAlignment.center => 0.5,
    };
    final target = active * lineHeight -
        (_viewportHeight - lineHeight) * anchor +
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
