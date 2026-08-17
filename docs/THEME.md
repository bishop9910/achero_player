# Achero Player 主题 / 字体 / 歌词自定义指南

Achero 把「外观」抽象成三个相互独立的设置域，全部持久化、即时生效：

| 设置域 | 位置 | 控制什么 |
| --- | --- | --- |
| 主题 `ThemeSettings` | 设置 → 外观与字体 | 种子色、明暗模式 |
| 字体 `FontSettings` | 设置 → 外观与字体 | 界面字体、歌词字体、运行时字体目录 |
| 歌词 `LyricSettings` | 设置 → 歌词显示 | 显示位置、偏移、字号、高亮色 |

它们统一收敛在 `AppSettings`（`lib/src/core/settings/app_settings.dart`），
由 `ThemeFactory`（`lib/src/core/theme/theme_factory.dart`）装配为 Material 主题。

---

## 1. 主题色与明暗模式

Achero 使用 Material 3 的 `ColorScheme.fromSeed`：**只要改一个种子色**，
整套配色（主色、容器色、表面色）会自动派生并保持一致。

- **明暗模式**：跟随系统 / 浅色 / 深色（分段按钮）。
- **色调滑杆**：0°–360° 任意调色。
- **调色盘**：完整颜色选择器（HSV 色轮 + 饱和度/明度滑块），精确取色。
- **预设色板**：一键套用海洋蓝（默认）、赛博紫等常用色。
- **插件预设**：脚本插件「主题预设」（`assets/plugins/theme_presets_plugin.dart`）
  在设置页额外贡献一组配色。

### 背景图片

在「设置 → 外观与字体 → 背景图片」可给整个应用加一张壁纸：

- **选择背景图片**：从本地选择一张图片（桌面 / 移动端）。
- **背景变暗**：叠加黑色蒙层（0%–90%），保证前景文字可读。
- **移除背景图片**：路径旁的删除按钮。

设置背景后，应用 `Scaffold` 背景透明，壁纸铺满整个窗口；壁纸经
`PlatformFileSystem` 读入内存渲染，故 Web 端不支持本地背景图片。

### 以代码方式改主题

```dart
final settings = context.read<SettingsController>();
settings.updateTheme(
  settings.settings.theme.copyWith(
    seedColor: 0xFF0984E3,               // ARGB 种子色
    brightness: ThemeBrightness.dark,    // system / light / dark
  ),
);
```

### 修改主题细节

在 `lib/src/core/theme/theme_factory.dart` 的 `_build` 中，可对
`ThemeData.copyWith(...)` 追加任意覆盖（圆角、卡片色、滑块样式等），
该文件是唯一的主题装配点。

---

## 2. 字体

### 2.1 界面字体 vs 歌词字体

- **界面字体**：应用于整个应用文本。
- **歌词字体**：只作用于歌词，留空则继承界面字体。

两者都支持「平台默认」以及内置字体（`Roboto` / `serif` / `monospace` /
`sans-serif`）。中文回退链内置了 `PingFang SC`、`Microsoft YaHei`、
`Noto Sans CJK SC`，因此即使选择西文字体，中文也能正常渲染。

### 2.2 运行时字体（无需重新编译）

桌面 / 移动端：在「设置 → 外观与字体 → 运行时字体」添加一个目录，或把
`.ttf` / `.otf` 直接放入应用数据目录的 `fonts/` 子目录，重启应用后，
这些字体会出现在字体下拉框中。

- Windows：`%APPDATA%/<AppSupport>/fonts`
- Linux：`~/.local/share/<AppSupport>/fonts`

> Web 端无文件系统，运行时字体不可用，请改用下方「内置字体」。

### 2.3 内置字体（随包发布）

1. 把字体文件放入 `assets/fonts/`；
2. 在 `pubspec.yaml` 声明：

```yaml
flutter:
  fonts:
    - family: MyFont
      fonts:
        - asset: assets/fonts/MyFont-Regular.ttf
        - asset: assets/fonts/MyFont-Bold.ttf
          weight: 700
```

3. 在 `lib/src/core/theme/font_manager.dart` 的 `systemFamilies` 中加入
   `'MyFont'`，即可出现在下拉框中。

---

## 3. 歌词显示

歌词由 `LyricSettings` 控制（`lib/src/core/settings/app_settings.dart`），
渲染于 `lib/src/ui/player/lyrics_view.dart`：

### 3.1 显示位置（`alignment`）

| 值 | 效果 |
| --- | --- |
| `center` | 当前行**垂直居中**（经典卡拉OK式） |
| `top` | 当前行靠近歌词区**顶部** |
| `bottom` | 当前行靠近歌词区**底部** |

### 3.2 垂直偏移（`verticalOffset`）

在位置锚点基础上再偏移像素（`-240 ~ +240`），正值下移。

### 3.3 字号与高亮色

- `fontSize`：歌词基准字号（12–40）。
- `highlightColor`：高亮行颜色，`null` 表示跟随主题主色。
- 字体缩放 `FontSettings.lyricsScale`：在字号基础上的整体缩放。

### 以代码方式改歌词

```dart
settings.updateLyrics(
  settings.settings.lyrics.copyWith(
    alignment: LyricAlignment.bottom,
    verticalOffset: -24,
    fontSize: 26,
    highlightColor: 0xFFE84393,
  ),
);
```

---

## 4. 设置持久化

所有设置序列化为 JSON 存入 `shared_preferences`（键 `achero.settings.v1`），
启动时恢复、变更即时落盘。序列化逻辑集中在 `AppSettings.toJson/fromJson`，
新增设置项时保持该文件的 round-trip 一致即可。
