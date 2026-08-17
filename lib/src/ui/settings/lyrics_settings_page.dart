import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import 'section.dart';

/// 歌词显示设置：位置、偏移、字号与高亮颜色。
class LyricsSettingsPage extends StatelessWidget {
  const LyricsSettingsPage({super.key});

  static const List<Color> _highlightPresets = [
    Color(0xFF6C5CE7),
    Color(0xFF0984E3),
    Color(0xFF00B894),
    Color(0xFFE84393),
    Color(0xFFFF7675),
    Color(0xFFFDCB6E),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final lyrics = settings.settings.lyrics;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('歌词显示')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsSection(
            title: '显示位置',
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<LyricAlignment>(
                  segments: [
                    for (final a in LyricAlignment.values)
                      ButtonSegment(value: a, label: Text(a.label)),
                  ],
                  selected: {lyrics.alignment},
                  onSelectionChanged: (s) => settings
                      .updateLyrics(lyrics.copyWith(alignment: s.first)),
                ),
              ),
              ListTile(
                title: const Text('垂直偏移'),
                subtitle: Text('${lyrics.verticalOffset.round()} px'),
                trailing: SizedBox(
                  width: 180,
                  child: Slider(
                    value: lyrics.verticalOffset.clamp(-240, 240),
                    min: -240,
                    max: 240,
                    onChanged: (v) => settings
                        .updateLyrics(lyrics.copyWith(verticalOffset: v)),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: '文字样式',
            children: [
              ListTile(
                title: const Text('歌词字号'),
                subtitle: Text('${lyrics.fontSize.round()}'),
                trailing: SizedBox(
                  width: 180,
                  child: Slider(
                    value: lyrics.fontSize,
                    min: 12,
                    max: 40,
                    onChanged: (v) =>
                        settings.updateLyrics(lyrics.copyWith(fontSize: v)),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('高亮颜色',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _HighlightSwatch(
                          label: '主题色',
                          color: scheme.primary,
                          selected: lyrics.highlightColor == null,
                          onTap: () => settings
                              .updateLyrics(lyrics.copyWith(clearHighlight: true)),
                        ),
                        for (final color in _highlightPresets)
                          _HighlightSwatch(
                            label: '',
                            color: color,
                            selected: color.toARGB32() == lyrics.highlightColor,
                            onTap: () => settings.updateLyrics(
                                lyrics.copyWith(highlightColor: color.toARGB32())),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SettingsSection(
            title: '预览',
            children: [
              Container(
                height: 120,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '这是当前的高亮歌词样式',
                  style: TextStyle(
                    fontSize: lyrics.fontSize,
                    color: lyrics.highlightColor != null
                        ? Color(lyrics.highlightColor!)
                        : scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightSwatch extends StatelessWidget {
  const _HighlightSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: label.isEmpty
            ? (selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null)
            : Text(label,
                style: TextStyle(
                  color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                )),
      ),
    );
  }
}
