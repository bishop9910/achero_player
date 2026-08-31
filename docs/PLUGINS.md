# Achero Player 插件开发指南（编译侧）

Achero 的插件系统让你以「纯 Dart 模块」的方式扩展播放器：新增独立页面、
设置区块、播放页面板，并订阅播放事件、持久化自己的数据。

> **插件有两种形态**：
> * **运行时脚本插件**（推荐，用于轻量逻辑）：**独立的 `.dart` 文件**放在插件
>   目录即可加载，无需重新编译。见 **[docs/RUNTIME_PLUGINS.md](RUNTIME_PLUGINS.md)**。
> * **编译侧插件**（本文档）：继承 `AcheroPlugin` 的 Dart 类，随应用一起编译。
>   适合需要 `http` / `crypto` / 动画等重能力的插件。

> ⚠️ **重要前提**：Flutter 在移动端 / 桌面端使用 AOT 编译，**无法在运行时
> 加载任意 Dart 代码**。因此编译侧插件是「编译进应用」的 Dart 类——你编写插件后
> 在 `lib/src/plugin_bootstrap.dart` 注册，随应用一起编译。这换来的是零
> 沙箱、全能力、类型安全的扩展体验。

---

## 1. 最小插件

一个插件就是继承 `AcheroPlugin` 的类，所有贡献点都有默认空实现：

```dart
import 'package:flutter/material.dart';
import 'package:achero_player/src/core/plugins/plugin_types.dart';

class HelloPlugin extends AcheroPlugin {
  @override
  String get id => 'com.example.hello';   // 全局唯一

  @override
  String get name => '你好插件';

  @override
  String get version => '1.0.0';

  @override
  String get description => '一个最小的示例插件';

  @override
  IconData get icon => Icons.waving_hand;
}
```

然后在 `lib/src/plugin_bootstrap.dart` 中注册：

```dart
void registerAllPlugins(PluginRegistry registry) {
  registry
    ..register(VisualizerPlugin())
    ..register(TagsPlugin())
    ..register(AuroraPlugin())
    ..register(HelloPlugin());   // ← 你的插件
}
```

热重载后即可在「设置 → 插件」看到它。

---

## 2. 生命周期

```dart
class MyPlugin extends AcheroPlugin {
  @override
  Future<void> onLoad(PluginContext context) async {
    // 插件被启用时调用。可在这里订阅事件、读取持久化数据。
  }

  @override
  Future<void> onUnload() async {
    // 插件被禁用 / 应用退出时调用。记得取消订阅、释放资源。
  }
}
```

- `enabledByDefault` 决定默认是否启用（默认 `true`）。
- 用户在「设置 → 插件」可随时开关；开关会触发 `onLoad` / `onUnload`。
- 单个插件加载抛异常不会拖垮应用，仅记录日志并保持禁用。

---

## 3. 贡献点

插件可以向宿主贡献四类内容：

### 3.1 独立页面（`pages`）

出现在主导航栏中：

```dart
@override
List<PluginPage> get pages => [
  PluginPage(
    id: '$id.main',
    title: name,
    icon: icon,
    builder: (context) => const MyPageWidget(),
  ),
];
```

### 3.2 设置区块（`settingsSections`）

出现在「设置 → 插件」该插件的卡片下：

```dart
@override
List<PluginSettingsSection> get settingsSections => [
  PluginSettingsSection(
    id: '$id.prefs',
    title: '我的设置',
    builder: (context) => [
      SwitchListTile(title: const Text('开启某功能'), value: ..., onChanged: ...),
    ],
  ),
];
```

> 注意：`builder` 返回的是 `List<Widget>`（而非单个 widget）。

### 3.3 播放页面板（`playerWidgets`）

注入到「正在播放」页底部的横滑面板（如可视化频谱）：

```dart
@override
List<PlayerWidget> get playerWidgets => [
  PlayerWidget(
    id: '$id.panel',
    title: '频谱',
    builder: (context) => const MyPanel(),
  ),
];
```

### 3.4 命令（`actions`）

```dart
@override
List<PluginAction> get actions => [
  PluginAction(
    id: '$id.scan',
    label: '执行扫描',
    icon: Icons.radar,
    onInvoke: () async { /* ... */ },
  ),
];
```

---

## 4. PluginContext —— 插件能拿到什么

`onLoad` 传入的 `PluginContext` 是插件与宿主交互的唯一通道：

| 成员 | 类型 | 说明 |
| --- | --- | --- |
| `settings` | `SettingsController` | 读写全局设置（主题/歌词/播放…） |
| `player` | `PlayerController` | 播放控制与状态（当前曲目/进度/队列） |
| `library` | `MusicLibrary` | 曲库与播放列表 |
| `fonts` | `FontManager` | 运行时字体 |
| `fs` | `PlatformFileSystem` | 平台文件系统抽象 |
| `events` | `PluginEventBus` | 订阅播放/曲库事件 |
| `prefs` | `PluginPrefs` | **插件专属**的持久化键值（自动按插件 id 隔离） |
| `log` | `void Function(String)` | 输出日志到调试面板与控制台 |

### 持久化数据

`PluginPrefs` 提供 `getString/setString`、`getBool/setBool`、`getInt/setInt`、
`getStringList/setStringList` 等，键名自动加上 `achero.plugin.<id>.` 前缀，
插件之间不会互相污染：

```dart
@override
Future<void> onLoad(PluginContext context) async {
  final count = context.prefs.getInt('playCount') ?? 0;
  await context.prefs.setInt('playCount', count + 1);
  context.log('第 ${count + 1} 次加载');
}
```

---

## 5. 事件订阅

`PluginContext.events` 提供以下广播流：

| 流 | 载荷 | 说明 |
| --- | --- | --- |
| `onTrackStarted` | `Track` | 一首曲目开始播放 |
| `onTrackChanged` | `Track` | 切到新曲目 |
| `onStateChanged` | `PlaybackStatus` | 播放/暂停/完成等状态变化 |
| `onPositionChanged` | `Duration` | 播放进度（高频，建议自行节流） |
| `onLibraryChanged` | `int` | 曲库曲目数变化 |

```dart
StreamSubscription? _sub;

@override
Future<void> onLoad(PluginContext context) async {
  _sub = context.events.onTrackStarted.listen((track) {
    context.log('开始播放: ${track.title}');
  });
}

@override
Future<void> onUnload() async {
  await _sub?.cancel();
}
```

---

## 6. 完整示例

- 编译侧完整示例：`lib/src/builtin_plugins/tags_plugin.dart`（标签持久化 + 页面）、
  `lib/src/builtin_plugins/aurora_plugin.dart`（自定义 UI）、
  `lib/src/builtin_plugins/desktop_lyrics_plugin.dart`（多窗口）。
- 运行时脚本完整示例：`assets/plugins/statistics_plugin.dart`（事件 + 持久化 + 页面）、
  `assets/plugins/theme_presets_plugin.dart`（设置区块），见 `docs/RUNTIME_PLUGINS.md`。

> 说明：「播放统计」已从编译侧迁移为**运行时脚本插件**
> （`assets/plugins/statistics_plugin.dart`），它演示的「事件 + 持久化 + 页面」
> 组合在脚本侧同样成立，是理解两套插件差异的最好对照。

编译侧内置插件（`lib/src/builtin_plugins/`）：
- `visualizer_plugin.dart` —— 演示 `playerWidgets`（播放页频谱面板）。
- `tags_plugin.dart` —— 分类标签：为曲目打彩色标签并按标签过滤（`PluginPrefs` 持久化）。
- `aurora_plugin.dart` —— 极光·炫彩：自绘唱片 + 流动渐变 + 频谱条的全屏视觉页
  （演示 `CustomPainter` / `AnimationController` 的自定义 UI）。
- `desktop_lyrics_plugin.dart` —— 桌面歌词：独立置顶悬浮窗显示歌词（仅桌面端，
  见 `docs/DESKTOP_LYRICS.md`）。
- `music_server_plugin.dart` —— 演示「外部数据源 → 曲库」：通过 RPC
  音乐服务器拉取曲目（协议见 `docs/RPC.md`），并演示 URL 流媒体来源
  `UrlTrackSource` 与内联歌词。
- `subsonic_plugin.dart` —— Subsonic/OpenSubsonic 源与缓存（见 `docs/SUBSONIC.md`）。

运行时脚本插件（`assets/plugins/`，见 `docs/RUNTIME_PLUGINS.md`）：
- `statistics_plugin.dart` —— 播放统计：单曲 / 专辑 / 播放列表三榜排行，封面预览、点击播放、多选。
- `theme_presets_plugin.dart` —— 主题预设（设置区块 + 改主题）。

---

## 7. 最佳实践

1. **id 全局唯一**：使用反向域名风格（`com.example.xxx`）。
2. **及时释放资源**：在 `onUnload` 中取消订阅、关闭 `StreamController`。
3. **偏好数据走 `prefs`**：不要手写 SharedPreferences 键，避免冲突。
4. **避免阻塞 UI**：耗时操作放后台，只通过 `ValueNotifier`/`ChangeNotifier` 通知 UI。
5. **崩溃隔离**：`onLoad` 抛异常只会禁用该插件，但请勿吞掉真正的编程错误。
