import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/font_manager.dart';
import 'section.dart';

/// 外观与字体设置：主题色、明暗模式、界面/歌词字体、运行时字体目录。
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  static const List<Color> _presetColors = [
    Color(0xFF6C5CE7),
    Color(0xFF0984E3),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFFE84393),
    Color(0xFFFDCB6E),
    Color(0xFF636E72),
    Color(0xFFD63031),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final fonts = context.watch<FontManager>();
    final theme = settings.settings.theme;
    final font = settings.settings.font;
    final scheme = Theme.of(context).colorScheme;

    final hue = HSLColor.fromColor(theme.seed).hue.toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('外观与字体')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsSection(
            title: '明暗模式',
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<ThemeBrightness>(
                  segments: [
                    for (final b in ThemeBrightness.values)
                      ButtonSegment(value: b, label: Text(b.label)),
                  ],
                  selected: {theme.brightness},
                  onSelectionChanged: (s) => settings
                      .updateTheme(theme.copyWith(brightness: s.first)),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: '主题色',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.seed,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outline),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: hue.clamp(0, 360),
                        max: 360,
                        label: '${hue.round()}°',
                        onChanged: (h) => settings.updateTheme(
                          theme.copyWith(
                            seedColor:
                                HSLColor.fromColor(theme.seed).withHue(h).toColor().toARGB32(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final color in _presetColors)
                      _Swatch(
                        color: color,
                        selected: color.toARGB32() == theme.seedColor,
                        onTap: () => settings
                            .updateTheme(theme.copyWith(seedColor: color.toARGB32())),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.palette_outlined, color: scheme.primary),
                title: const Text('调色盘…'),
                subtitle: const Text('打开完整颜色选择器（HSV 色轮 + 滑块）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openColorPicker(context, settings, theme),
              ),
            ],
          ),
          SettingsSection(
            title: '背景图片',
            children: [
              if (theme.hasBackgroundImage)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(
                    theme.backgroundImagePath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: '移除背景图片',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => settings
                        .updateTheme(theme.copyWith(clearBackgroundImage: true)),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('选择背景图片'),
                onTap: () async {
                  final result =
                      await FilePicker.platform.pickFiles(type: FileType.image);
                  if (result == null || result.files.isEmpty) return;
                  final path = result.files.first.path;
                  if (!context.mounted) return;
                  if (path == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('当前平台不支持本地背景图片'),
                        duration: Duration(milliseconds: 1500),
                      ),
                    );
                    return;
                  }
                  settings.updateTheme(
                      theme.copyWith(backgroundImagePath: path));
                },
              ),
              ListTile(
                title: const Text('背景变暗'),
                subtitle: SizedBox(
                  height: 36,
                  child: Slider(
                    value: theme.backgroundDim.clamp(0.0, 0.9).toDouble(),
                    min: 0.0,
                    max: 0.9,
                    divisions: 18,
                    label: '${(theme.backgroundDim * 100).round()}%',
                    onChanged: (v) =>
                        settings.updateTheme(theme.copyWith(backgroundDim: v)),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: '字体',
            children: [
              _FontPickerTile(
                label: '界面字体',
                value: font.uiFamily,
                families: fonts.allFamilies,
                onChanged: (f) => settings.updateFont(font.copyWith(uiFamily: f)),
              ),
              const Divider(height: 1),
              _FontPickerTile(
                label: '歌词字体',
                value: font.lyricsFamily.isEmpty ? font.uiFamily : font.lyricsFamily,
                families: fonts.allFamilies,
                onChanged: (f) => settings.updateFont(font.copyWith(lyricsFamily: f)),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('歌词字号缩放'),
                subtitle: SizedBox(
                  height: 36,
                  child: Slider(
                    value: font.lyricsScale,
                    min: 0.7,
                    max: 1.8,
                    divisions: 11,
                    label: '${font.lyricsScale.toStringAsFixed(2)}×',
                    onChanged: (v) =>
                        settings.updateFont(font.copyWith(lyricsScale: v)),
                  ),
                ),
              ),
            ],
          ),
          if (supportsDirectoryPicker)
            SettingsSection(
              title: '运行时字体',
              children: [
                if (font.fontFolders.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('尚未添加字体目录'),
                    subtitle: Text('把 .ttf/.otf 放入目录后即可在下拉框中选择'),
                  )
                else
                  for (final folder in font.fontFolders)
                    ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folder, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => settings.updateFont(
                          font.copyWith(
                            fontFolders: font.fontFolders.where((f) => f != folder).toList(),
                          ),
                        ),
                      ),
                    ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('添加字体目录'),
                  onTap: () async {
                    final dir = await FilePicker.platform.getDirectoryPath();
                    if (dir == null) return;
                    settings.updateFont(
                      font.copyWith(fontFolders: [...font.fontFolders, dir]),
                    );
                    await fonts.loadFromDirectories([dir]);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<void> _openColorPicker(
  BuildContext context,
  SettingsController settings,
  ThemeSettings theme,
) async {
  var picked = theme.seed;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('选择主题色'),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: picked,
          onColorChanged: (color) => picked = color,
          enableAlpha: false,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            settings.updateTheme(theme.copyWith(seedColor: picked.toARGB32()));
            Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }
}

class _FontPickerTile extends StatelessWidget {
  const _FontPickerTile({
    required this.label,
    required this.value,
    required this.families,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> families;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: DropdownButton<String>(
        value: families.contains(value) ? value : '',
        underline: const SizedBox.shrink(),
        items: [
          for (final f in families)
            DropdownMenuItem(
              value: f,
              child: Text(f.isEmpty ? '平台默认' : f),
            ),
        ],
        onChanged: (v) => onChanged(v ?? ''),
      ),
    );
  }
}
