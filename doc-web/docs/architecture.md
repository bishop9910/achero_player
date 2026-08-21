---
icon: lucide/layers
---

# Achero Player 架构说明

Achero 追求**核心逻辑纯 Dart、依赖显式注入、可插拔**。除「桌面歌词多窗口」
外，跨平台能力均无原生代码；磁盘与文件操作经平台抽象隔离。

```
lib/src/
├── core/              纯 Dart 核心（不依赖 Flutter UI，可单测）
│   ├── audio/         音频引擎抽象 + media_kit 实现
│   ├── library/       音乐库、目录扫描、元数据、专辑覆盖（AlbumOverrides）+ 专辑/艺术家分类（LibraryCatalog）
│   ├── lyrics/        LRC 解析器与歌词模型
│   ├── models/        Track（文件/字节/URL 三种来源）/ Playlist
│   ├── platform/      平台文件系统（条件导入 IO/Web）+ 能力探测
│   ├── player/        播放控制器（队列/循环/随机/歌词）
│   ├── plugins/       插件 API / 注册表 / 清单 / 事件总线
│   │   └── script/    运行时脚本插件：编译执行、适配器、加载器
│   ├── rpc/           RPC 音乐服务器客户端 + Subsonic 客户端 + 流下载
│   ├── cache/         磁盘缓存（音频/JSON、TTL、清理）
│   ├── settings/      设置模型与持久化
│   └── theme/         主题工厂 + 运行时字体
├── desktop_lyrics/    桌面歌词独立窗口（多窗口 + window_manager）
├── builtin_plugins/   编译侧插件（可视化/标签/极光/桌面歌词/RPC/Subsonic）
└── ui/                Flutter 界面层
assets/plugins/        运行时脚本插件（独立 .dart 文件）
tool/                  纯 Dart 验证脚本（dart run）
```

---

## 1. 组装根与依赖注入

`lib/src/bootstrap.dart` 是唯一的组装点：按依赖顺序创建所有服务，装入
`AppServices`（`lib/src/app_services.dart`），再由 `provider` 注入 widget 树。

```
bootstrap()
 ├─ SharedPreferences / PlatformFileSystem
 ├─ SettingsController(settings)
 ├─ FontManager(fs)
 ├─ MusicLibrary(prefs, fs)
 ├─ AlbumOverrides(prefs)              # 专辑名手动覆盖（默认自动识别）
 ├─ LibraryCatalog(library, overrides) # 按专辑/艺术家建立分类索引
 ├─ MediaKitEngine()
 ├─ PlayerController(engine, settings, fs)
 ├─ PluginEventBus / PluginRegistry
 ├─ 加载运行时字体
 ├─ registerAllPlugins(plugins)            # 编译侧插件
 ├─ ScriptPluginLoader(fs).loadInto()      # 运行时脚本插件（扫描 .dart 并注册）
 ├─ plugins.initialize(ctxFactory)          # 按清单启用插件、注入 PluginContext
 └─ 桥接 player/library 事件到 PluginEventBus
```

- 没有隐式单例：对象一律经构造器传入。
- UI 通过 `context.watch<XxxController>()` 订阅，`context.read` 触发命令。

---

## 2. 音频引擎抽象

`AudioEngine`（接口）把「播放」与实现解耦：

```dart
abstract interface class AudioEngine {
  Stream<PlaybackStatus> get statusStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<void> get completionStream;
  Stream<String> get errorStream;
  Future<void> load(Track track);
  Future<void> play(); Future<void> resume();
  Future<void> pause(); Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double v); Future<void> setRate(double r);
}
```

当前实现 `MediaKitEngine` 用 `media_kit`（libmpv/ffmpeg）覆盖 Windows / Linux /
Android / Web；ffmpeg 全格式解码，Windows 上也能直接播放 OGG/Opus/FLAC，不再受
Media Foundation 限制，Web 端回退到浏览器 HTML5 音频。

曲目有三种来源（`TrackSource` 密封类），引擎统一映射：

| 来源 | 用途 | 引擎映射 |
| --- | --- | --- |
| `FileTrackSource` | 本地文件 / 缓存命中 | `Media(Uri.file(path))` |
| `BytesTrackSource` | Web 内存导入 | `Media(Uri.dataFromBytes(...))` |
| `UrlTrackSource` | 在线流式（Web 兜底） | `Media(url)` |

---

## 3. 播放控制器

`PlayerController`（`ChangeNotifier`）是 UI 与引擎之间的唯一桥梁：

- 维护**原始队列**（`_baseQueue`）与**播放顺序**（`_queue`，洗牌后的副本）。
- 命令：`playQueue / playTrack / togglePlayPause / next / previous / seek /
  setVolume / toggleShuffle / cycleRepeatMode / refreshLyrics`。
- 自动接续：监听引擎 `completionStream`，按 `RepeatMode`（顺序/循环/单曲）
  决定停止、单曲重播或切下一首。
- 歌词：`refreshLyrics()` 优先读曲目 `metadata['lyrics']`（服务器内联），
  否则读本地同名 `.lrc` → `LrcParser.parse`。

---

## 4. 平台抽象

所有触碰磁盘的代码都经由 `PlatformFileSystem` 接口，并用**条件导入**在
编译期选择实现，避免把 `dart:io` 链进 Web 产物：

```dart
// platform_fs_factory.dart
import 'platform_filesystem_io.dart'
    if (dart.library.js_interop) 'platform_filesystem_web.dart' as impl;
```

- `IoPlatformFileSystem`：`dart:io`，Windows / Linux / Android。
- `WebPlatformFileSystem`：目录扫描 / 写入返回「不支持」，走 `file_picker` 内存导入。

接口除目录扫描、读字节外，还提供缓存所需的
`writeBytes / deleteFile / ensureDirectory / lastModified / listFiles`。

`lib/src/core/platform/platform_capabilities.dart` 单独描述「是否有目录选择器」
等能力（`supportsDirectoryPicker`），与「是否有文件系统」分开判断。

---

## 5. 缓存

`lib/src/core/cache/cache_manager.dart` 是通用磁盘缓存，供 Subsonic / RPC 插件共用：

```
<cacheDir>/
├── audio/<id>.<ext>   # 音频文件
└── json/<key>.json    # 元数据
```

- 绝对 TTL：`now - mtime > ttl` 即过期（`ttl` 可运行时调整）。
- `cleanup()` 删除过期、`clearAll()` 清空、`totalSize()` 统计。
- 插件加载时清理一次 + 每 6 小时定期清理；路径 / 保留天数可在设置里改。

---

## 6. 音乐服务器源

- `lib/src/core/rpc/music_server_client.dart` —— 自定义 JSON-RPC 2.0 协议
  （见 [RPC 协议](rpc.md)），用于自建服务端。
- `lib/src/core/rpc/subsonic_client.dart` —— Subsonic/OpenSubsonic 协议
  （Navidrome、Airsonic 等，见 [Subsonic 源](subsonic.md)），token 鉴权
  `t = md5(password + salt)`。
- `lib/src/core/rpc/download.dart` —— 把流下载到缓存（两插件共用）。

两个源插件都遵循同一模式：**元数据缓存 → 音频下载到缓存 → 以 `FileTrackSource`
播放；Web 端退化为 `UrlTrackSource` 在线流式。**

---

## 7. 插件系统

Achero 有**两类插件**，统一接入同一个 `PluginRegistry`：

1. **编译侧插件**（`AcheroPlugin` 子类，`builtin_plugins/`）：完整 Dart + Flutter
   能力，可做自定义 UI（标签、极光、可视化、音乐服务器、Subsonic、桌面歌词）。
   见 [编译侧插件](plugins.md)。
2. **运行时脚本插件**（`assets/plugins/` 或插件目录里的独立 `.dart` 文件）：
   由 `dart_eval` 解释执行，声明式贡献页面/设置，通过 `call` 使用宿主能力。
   见 [运行时脚本插件](runtime-plugins.md)。

核心对象：

- `AcheroPlugin`：编译侧插件基类，贡献 `pages / settingsSections / playerWidgets / actions`。
- `ScriptPluginAdapter`：把脚本适配成 `AcheroPlugin`。
- `PluginRegistry`：注册、按 `PluginManifest` 启用/禁用、聚合贡献。
- `PluginContext`：注入 `settings/player/library/fonts/fs/events/prefs/log`。
- `PluginEventBus`：播放 / 曲库事件的广播总线，由 `bootstrap` 桥接而来。

设计上**核心不依赖插件**，插件单向依赖核心——扩展不会反向污染核心逻辑。

---

## 8. 桌面歌词多窗口（原生例外）

`desktop_lyrics_plugin` + `lib/src/desktop_lyrics/` 用
[`desktop_multi_window`](https://pub.dev/packages/desktop_multi_window) +
[`window_manager`](https://pub.dev/packages/window_manager) 创建独立的无边框、
透明、置顶歌词窗口。这是**唯一需要原生改动的功能**（`windows/runner`、
`linux/runner` 各加了一处子窗口插件注册回调），仅桌面端可用，见
[桌面歌词窗口](desktop-lyrics.md)。

---

## 9. 数据流（以「播放一首歌」为例）

``` mermaid
graph TD
    A[用户点击曲目] --> B[PlayerController.playQueue tracks, index]
    B --> C[重建队列 _rebuildQueue]
    C --> D[_startCurrent]
    D --> E[AudioEngine.load track]
    E --> F[AudioEngine.play]
    F --> G[statusStream / positionStream 回灌]
    G --> H[notifyListeners]
    H --> I[NowPlayingBar / PlayerPage / LyricsView 重绘]
    D --> J[refreshLyrics]
    J --> K[读内联 / 本地 .lrc]
    K --> L[LrcParser → LyricsView 滚动高亮]
    H --> M[bootstrap 桥接转发到 PluginEventBus]
    M --> N[订阅插件更新自身状态]
```

桌面歌词另开一条链路：插件监听 `PlayerController`，歌词行变化时经
`WindowController.invokeMethod('update', json)` 推送到子窗口。

---

## 10. 状态管理与响应式

- 核心对象均为 `ChangeNotifier`（或 `ValueNotifier`）。
- UI 用 `provider` 的 `watch`（订阅）/ `read`（命令）分离读写。
- 主题切换：`SettingsController` 变化 → `_AppBuilder` 重建 `MaterialApp` 的
  `theme/darkTheme/themeMode`，全应用即时换肤。

---

## 11. 关键设计取舍

| 取舍 | 理由 |
| --- | --- |
| 用 `media_kit`（libmpv/ffmpeg）而非 `audioplayers` / `just_audio` | ffmpeg 全格式解码，Windows 上也能播 OGG/Opus/FLAC，不再受 Media Foundation 限制 |
| 元数据默认从文件名推断 | 避免引入原生标签库；`TrackMetadataExtractor` 可替换为 ID3 读取 |
| 双插件体系（编译侧 + 脚本侧） | 编译侧给足能力；脚本侧（dart_eval）实现「运行时加载独立文件」，但受 Dart 子集限制 |
| 服务器源统一「缓存 + 本地播放」 | 离线可播、减少重复下载；Web 退化为在线流式 |
| 歌词单行定高（`itemExtent`） | 让位置对齐与滚动 offset 计算精确 |
| 序列化用 `dart:convert` + 手动 toJson/fromJson | 无代码生成依赖，round-trip 可单测 |
| 桌面歌词用原生多窗口 | 多窗口是引擎层能力，无法纯 Dart；仅桌面端 |
