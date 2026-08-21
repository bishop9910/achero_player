---
icon: lucide/monitor
---

# 桌面歌词独立窗口

内置插件 **桌面歌词**（`com.achero.desktopLyrics`）在**独立的置顶悬浮窗**里
显示当前播放的歌词行，随播放实时同步、可拖动。

!!! warning "平台限制"

    仅 **Windows / Linux / macOS** 支持；Android / Web 上会显示「仅桌面端支持」。

---

## 1. 使用

1. 打开 **设置 → 插件 → 桌面歌词**。
2. 打开「桌面歌词独立窗口」开关 → 屏幕下方出现一个无边框、透明、置顶的歌词条。
3. 播放歌曲，歌词行实时更新；可按住拖动（原生拖拽，无闪烁）。
4. 关闭开关（或直接关掉悬浮窗）即可收起。

开关状态会持久化：下次启动若上次是开启的，会自动重新打开悬浮窗。

### 外观自定义

在「桌面歌词」设置区可直接调整，即时生效：

- **歌词字号**（18–48）
- **背景不透明度**（20%–100%）
- **高亮颜色**（蓝/紫/绿/粉/白）
- **显示下一行歌词**开关
- **鼠标穿透**开关（开启后歌词窗不响应鼠标、不挡操作）
- **始终置顶**开关

---

## 2. 技术方案

- **多窗口**：[`desktop_multi_window`](https://pub.dev/packages/desktop_multi_window)
  —— 创建第二个 Flutter 窗口（独立引擎）。
- **窗口属性**：[`window_manager`](https://pub.dev/packages/window_manager)
  —— 无边框、透明、置顶、底部居中、跳过任务栏。
- **数据同步**：主窗口把「当前歌词行 / 下一行 / 曲名 / 播放状态」通过
  `WindowController.invokeMethod('update', json)` 推送到子窗口。

### 关键改动

```
lib/main.dart                                     # 按窗口参数路由到歌词 UI
lib/src/desktop_lyrics/desktop_lyrics_window.dart # 子窗口 UI（透明歌词条）
lib/src/desktop_lyrics/desktop_lyrics_constants.dart
lib/src/builtin_plugins/desktop_lyrics_plugin.dart# 插件：开关 + 开窗 + 推送
windows/runner/flutter_window.cpp                  # 注册子窗口插件回调
linux/runner/my_application.cc                     # 注册子窗口插件回调
```

---

## 3. 原生改动说明

`desktop_multi_window` 的每个子窗口都有独立的 Flutter 引擎，需要把插件
重新注册到子窗口。已在原生侧加好回调：

- **Windows**（`windows/runner/flutter_window.cpp`）：`DesktopMultiWindowSetWindowCreatedCallback`
  内调用 `RegisterPlugins`。
- **Linux**（`linux/runner/my_application.cc`）：`desktop_multi_window_plugin_set_window_created_callback`
  内调用 `fl_register_plugins`。

!!! note "新增插件后"

    需运行一次 `flutter pub get`（`flutter run` 会自动执行），
    以重新生成 `generated_plugin_registrant`，让新原生插件进入编译。

---

## 4. 平台与已知限制

| 项目 | 说明 |
| --- | --- |
| Windows | 透明 + 置顶正常 |
| Linux | 透明置顶依赖窗口管理器 / 合成器（GNOME/X11 通常可用；部分 Wayland 环境表现不一） |
| Android / Web | 不支持，显示提示 |
| 多显示器 | 默认底部居中于主屏；可拖动到其他屏幕 |

已知限制：

- 子窗口是**极简歌词条**，不做完整播放控制（控制仍在主窗口）。
- 歌词来自主播放器的 `PlayerController`（同名 `.lrc` 或服务器内联歌词），
  无歌词时显示「♪ 暂无歌词 ♪」。
- 若出现窗口无法透明，请确认未使用远程桌面 / 某些安全软件的窗口过滤。
