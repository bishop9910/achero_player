# Subsonic / OpenSubsonic 音乐服务器源

内置插件 **Subsonic 服务器**（`com.achero.subsonic`）让你连接主流的
自托管音乐服务器，浏览、搜索、导入并**缓存**音乐到本地。

兼容实现 **Subsonic / OpenSubsonic API** 的服务器，例如：

- [Navidrome](https://www.navidrome.org/)（最流行的轻量自托管方案）
- [Airsonic](https://airsonic.github.io/) / Airsonic-Advanced
- [Gonic](https://github.com/sentriz/gonic)
- Astiga、funkwhale（部分兼容）等

---

## 1. 连接

在「Subsonic 服务器」插件页填写：

| 字段 | 说明 |
| --- | --- |
| 服务器地址 | 形如 `http://192.168.1.10:4533`（可含反向代理子路径前缀） |
| 用户名 / 密码 | 服务器账号 |

鉴权采用 Subsonic 的 **token 模式**：`t = md5(password + salt)`，
每个请求附带随机 `salt`，密码不会明文出现在 URL 中。

> 兼容性说明：本插件走 **JSON**（`f=json`）接口，要求服务器支持
> `ping` / `getAlbumList2` / `getAlbum` / `search3` / `stream`，Navidrome
> 与 Airsonic 均完整支持。

---

## 2. 浏览与导入

连接成功后：

- **最新专辑**：默认拉取 `getAlbumList2(type=newest)`。
- **搜索**：走 `search3`，返回艺术家 / 专辑 / 歌曲。
- 点击专辑进入歌曲列表，点歌曲即**播放**，点右侧 `+` 或「导入整张专辑」
  即**导入曲库**。
- 导入的曲目自带 `artist` / `album` 字段，会由核心组件 `LibraryCatalog`
  自动归类，直接出现在主页「曲库 → 专辑 / 艺术家」分栏中（与本地、RPC
  来源统一处理）。

---

## 3. 缓存机制

插件会把两类数据缓存到本地磁盘，避免重复请求、支持离线播放：

```
<cacheDir>/
├── audio/     # 音频文件：<songId>.<ext>
└── json/      # 元数据：album-<id>.json / search-<q>.json / albumlist-newest.json
```

### 3.1 音频缓存

- 播放 / 导入一首歌时，先查 `audio/<id>.<ext>`；命中则直接播放本地文件，
  否则下载 `stream.view` 流写入缓存后播放。
- 音频以 `FileTrackSource` 进入曲库，因此可被普通播放、加入播放列表。

### 3.2 JSON 元数据缓存

- 专辑列表、专辑歌曲、搜索结果按 key 序列化为 JSON 缓存，
  再次浏览时优先读缓存（未过期则不发请求）。

### 3.3 定期删除（TTL）

- 缓存有**保留天数**（默认 7 天，可在「设置 → 插件 → Subsonic 服务器 → 缓存」调整）。
- 过期判定基于文件**最后写入时间**：`now - mtime > ttl` 即删除。
- 清理时机：**插件加载时清理一次**，之后**每 6 小时**自动清理；
  也可在设置里手动「清理过期缓存」或「清空全部缓存」。

### 3.4 自定义缓存路径

- 默认路径：`<应用数据目录>/cache/subsonic`。
- 在设置里点「缓存目录」可改成任意绝对路径；Web 端无文件系统，
  该设置不可用（见下）。

---

## 4. 平台差异

| 平台 | 行为 |
| --- | --- |
| Windows / Linux / Android | 完整缓存（音频 + 元数据） |
| Web | 无文件系统，**自动退化为在线流式播放**（`UrlTrackSource`），不缓存 |

> Web 端在线播放要求服务器允许音频流的 **CORS**。

---

## 5. 与 JSON-RPC 插件的区别

| | `music_server_plugin` | `subsonic_plugin` |
| --- | --- | --- |
| 协议 | 自定义 JSON-RPC 2.0（`docs/RPC.md`） | Subsonic / OpenSubsonic |
| 适用 | 自建 / 自定义服务端 | Navidrome、Airsonic 等现成服务器 |
| 缓存 | 音频 + 元数据 + TTL 清理 | 音频 + 元数据 + TTL 清理 |
| 歌词 | 支持（内联 `lyrics`） | 依赖服务器（标准 API 不返回歌词） |

二者可并存，按需在「设置 → 插件」启用。

---

## 6. 实现要点（代码结构）

- `lib/src/core/rpc/subsonic_client.dart` —— 纯 Dart 客户端：鉴权、解析、
  单元素列表归一化（Subsonic 单元素会返回对象而非数组）。
- `lib/src/core/cache/cache_manager.dart` —— 通用磁盘缓存（音频/JSON、
  TTL、清理、统计），经 `PlatformFileSystem` 抽象实现跨平台。
- `lib/src/ui/settings/cache_settings_section.dart` —— 可复用的缓存设置区块
  （路径/TTL/清理/清空），Subsonic 与 RPC 插件共用。
- `lib/src/core/rpc/download.dart` —— 流下载到缓存的共用工具。
- `lib/src/builtin_plugins/subsonic_plugin.dart` —— 页面（浏览/搜索/导入）
  与缓存接入。
