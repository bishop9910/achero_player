---
icon: lucide/music
---

# Achero Player

一个**纯 Dart** 编写、**跨平台**、**深度可定制**、**可插拔**的音乐播放器。

<div class="grid cards" markdown>

-   🎵 **音频播放**

    基于 `media_kit`（libmpv/ffmpeg），全格式解码，单一 API 覆盖 Windows / Linux / Android / Web 四大平台。

-   🎨 **深度定制主题**

    种子色 / 深浅色 / 运行时字体，Material 3 一键换肤。

-   🎤 **LRC 歌词**

    解析、滚动高亮，显示位置与字号颜色自由定制。

-   🧩 **插件系统**

    独立页面 / 设置区块 / 播放页面板 / 事件订阅，双向扩展。

-   📜 **运行时脚本插件**

    独立 `.dart` 文件放到插件目录即可加载，**无需重新编译**。

-   ☁️ **音乐服务器源**

    JSON-RPC 2.0 与 Subsonic / OpenSubsonic，含音频与元数据缓存。

-   🧱 **干净的分层架构**

    核心逻辑纯 Dart、UI 与实现解耦，可单元测试。

-   🖥️ **桌面歌词**

    独立置顶悬浮窗显示歌词（仅桌面端）。

-   🎛️ **后台播放**

    Android 通知栏 / Linux MPRIS / Windows SMTC 系统级媒体控制，锁屏与耳机按键可用。

-   ✅ **多选批量操作**

    曲库 / 标签 / 播放记录支持多选（桌面端右键进入），批量加歌单 / 删除 / 下载。

</div>

> 当前版本聚焦「框架 + 核心能力 + 可扩展性」，内置完整的播放、曲库、
> 播放列表、歌词与主题系统，以及一批编译侧 + 脚本侧示例插件。

---

## ✨ 功能特性

| 模块 | 说明 |
| --- | --- |
| 音频播放 | 基于 `media_kit`（libmpv/ffmpeg），全格式解码、单 API 覆盖四大平台 |
| 音乐库 | 目录扫描、单个文件导入、Web 内存导入、搜索 |
| 播放列表 | 创建 / 重命名 / 删除、收藏（我最喜爱） |
| 歌词 | 自动加载同名 `.lrc` 或服务器内联，滚动高亮、点击跳转 |
| 主题 | 种子色、明暗模式、色调滑杆、一键预设 |
| 字体 | 界面 / 歌词字体分离，运行时加载 `.ttf/.otf` |
| 标签 | 为曲目打彩色标签并按标签过滤 |
| 音乐服务器源 | RPC（JSON-RPC 2.0）与 Subsonic/OpenSubsonic，含缓存 |
| 桌面歌词 | 独立置顶悬浮窗显示歌词（仅桌面端） |
| 后台播放 | Android 通知栏 / Linux MPRIS / Windows SMTC 系统媒体控制 |
| 多选批量 | 曲库 / 标签 / 播放记录多选，批量加歌单 / 删除 / 下载 |
| 播放统计 | 单曲 / 专辑 / 播放列表三榜排行，封面预览、点击播放 |
| 插件 | 页面 / 设置 / 播放面板 / 事件 / 持久化键值 |

---

## 🚀 快速开始

### 环境要求

- Flutter **3.44+**（Dart 3.12+）

### 安装依赖

```bash
flutter pub get
```

### 运行

=== "Windows"

    ```powershell
    flutter run -d windows
    ```

=== "Linux"

    ```bash
    # media_kit 自带 libmpv 库，通常无需额外安装；如遇缺库报错再补系统依赖
    flutter run -d linux
    ```

=== "Android"

    ```bash
    flutter run -d android
    ```

=== "Web"

    ```bash
    flutter run -d chrome
    ```

首次启动后在 **曲库 → 添加音乐** 导入音频：

- **桌面 / Android**：选择「扫描整个文件夹」或「选择音频文件」。
- **Web**：浏览器没有文件系统，直接从文件选择器导入（内存中，会话内有效）。

!!! tip "歌词提示"

    把与歌曲同名的 `.lrc` 文件放到音频旁边（如 `歌曲.mp3` + `歌曲.lrc`），
    播放时自动加载并跟随滚动。

---

## 🧭 项目结构

```
lib/
├── main.dart                    # 入口
└── src/
    ├── bootstrap.dart           # 组装根：创建所有服务并接线
    ├── app_services.dart        # 服务容器（依赖注入）
    ├── achero_app.dart          # MaterialApp 与主题装配
    ├── plugin_bootstrap.dart    # ★ 插件注册入口（加插件改这里）
    ├── core/                    # 纯 Dart 核心（不依赖 UI）
    │   ├── audio/               # 音频引擎抽象 + media_kit 实现
    │   ├── library/             # 音乐库、扫描器、元数据提取
    │   ├── lyrics/              # LRC 解析器与歌词模型
    │   ├── models/              # Track / Playlist 等模型
    │   ├── platform/            # 平台文件系统（条件导入 IO/Web）
    │   ├── player/              # 播放控制器（队列/循环/随机/歌词）
    │   ├── plugins/             # 插件 API / 注册表 / 事件总线
    │   │   └── script/          # 运行时脚本插件引擎 / 适配器 / 加载器
    │   ├── settings/            # 设置模型与持久化
    │   └── theme/               # 主题工厂 + 运行时字体管理
    ├── builtin_plugins/         # 编译侧插件（可视化/标签/极光/桌面歌词/音乐服务器/Subsonic）
    └── ui/                      # Flutter UI 层
        ├── shell/               # 响应式根壳层（Rail/底部导航）
        ├── library/             # 曲库页
        ├── player/              # 播放页 / 歌词 / 迷你播放条
        ├── playlists/           # 播放列表
        ├── settings/            # 设置页
        └── common/              # 通用组件

assets/
└── plugins/                     # 运行时脚本插件（示例，首次运行复制到插件目录）

tool/
└── verify_dart_eval.dart        # 脚本引擎端到端验证（纯 Dart，可直接 dart run）
```

---

## 📚 文档导航

<div class="grid cards" markdown>

-   🧱 [**架构设计**](architecture.md)

    分层架构、依赖注入、数据流与设计取舍。

-   🧩 [**编译侧插件**](plugins.md)

    `AcheroPlugin` 插件开发完整指南。

-   📜 [**运行时脚本插件**](runtime-plugins.md)

    独立 `.dart` 文件，无需重新编译即可加载。

-   🎨 [**主题 / 字体 / 歌词**](theme.md)

    外观定制指南。

-   🖥️ [**桌面歌词窗口**](desktop-lyrics.md)

    独立置顶悬浮窗显示歌词。

-   ☁️ [**RPC 协议**](rpc.md)

    音乐服务器 RPC 协议（JSON-RPC 2.0）。

-   🎛️ [**Subsonic 源**](subsonic.md)

    Subsonic / OpenSubsonic 源与缓存机制。

-   📦 [**打包发布**](build.md)

    各平台 release 打包与发布检查清单。

</div>

---

## 🧪 测试

```bash
flutter analyze   # 静态分析
flutter test      # 单元测试：LRC 解析、设置序列化、插件清单、
                  #   缓存管理、Subsonic/RPC 客户端
dart run tool/verify_dart_eval.dart  # 脚本插件引擎端到端验证（纯 Dart）
```

---

## ⚖️ 许可

MIT License。
