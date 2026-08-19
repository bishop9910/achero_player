# Achero 音乐服务器 RPC 协议

内置插件 **音乐服务器**（`com.achero.musicServer`）通过本协议从远端「音乐服务器源」
拉取曲目元数据并**流式播放**。协议基于 [JSON-RPC 2.0](https://www.jsonrpc.org/specification)
over HTTP，纯 Dart 实现（见 `lib/src/core/rpc/music_server_client.dart`），
无任何原生依赖，四平台通用。

---

## 1. 传输层

- **端点**：一个固定的 HTTP URL，例如 `http://192.168.1.10:8080/rpc`。
- **方法**：`POST`。
- **请求头**：
  - `Content-Type: application/json`
  - （可选）`Authorization: Bearer <token>`
- **请求体**：标准 JSON-RPC 2.0 请求对象。

```json
{ "jsonrpc": "2.0", "id": 1, "method": "music.list", "params": { "offset": 0, "limit": 200 } }
```

- **响应体**：标准 JSON-RPC 2.0 响应（成功返回 `result`，失败返回 `error`）。

```json
{ "jsonrpc": "2.0", "id": 1, "result": { "tracks": [ /* ... */ ] } }
```

---

## 2. 鉴权策略

| 用途 | 方式 | 说明 |
| --- | --- | --- |
| RPC 元数据调用 | `Authorization: Bearer <token>` 请求头 | 客户端支持，服务端可校验 |
| 音频流 | **签名 URL**（令牌放在 query 参数） | 流鉴权走 URL 签名（当前引擎虽支持自定义请求头，但 URL 签名更利于缓存与直链分享），如 `.../stream/1?token=<签名>` |

> 建议：`music.streamUrl` 返回的 `url` 直接带上有效期内的签名令牌，播放器拿到即可用。

---

## 3. 方法

### 3.1 `music.ping`（可选）

健康检查。参数为空。**客户端不强制要求实现**——ping 失败会自动跳过，直接尝试
`music.list`；但建议实现，便于快速探活。

**请求**

```json
{ "jsonrpc": "2.0", "id": 0, "method": "music.ping", "params": {} }
```

**响应**

```json
{ "jsonrpc": "2.0", "id": 0, "result": { "ok": true } }
```

### 3.2 `music.list`

拉取曲目列表。

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `offset` | int | 否 | 分页偏移，默认 0 |
| `limit` | int | 否 | 每页数量，默认 200 |

**响应**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tracks": [
      {
        "id": "1",
        "title": "海阔天空",
        "artist": "Beyond",
        "album": "乐与怒",
        "durationMs": 324000,
        "url": "http://192.168.1.10:8080/stream/1?token=abc123",
        "coverUrl": "http://192.168.1.10:8080/cover/1",
        "lyrics": "[00:00.00]今天我\n[00:05.00]寒夜里看雪飘过"
      }
    ]
  }
}
```

### 3.3 `music.listAlbums`

拉取专辑列表（用于按专辑浏览）。客户端不强制要求实现——失败会自动回退到纯歌曲列表。

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `offset` | int | 否 | 分页偏移，默认 0 |
| `limit` | int | 否 | 每页数量，默认 200 |

**响应**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "albums": [
      {
        "id": "a1",
        "name": "乐与怒",
        "artist": "Beyond",
        "coverUrl": "http://192.168.1.10:8080/cover/album/a1",
        "songCount": 10,
        "year": 1993
      }
    ]
  }
}
```

### 3.4 `music.listArtists`

拉取艺术家列表（用于按艺术家浏览）。客户端不强制要求实现。

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `offset` | int | 否 | 分页偏移，默认 0 |
| `limit` | int | 否 | 每页数量，默认 200 |

**响应**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "artists": [
      {
        "id": "ar1",
        "name": "Beyond",
        "albumCount": 8,
        "songCount": 96,
        "coverUrl": "http://192.168.1.10:8080/cover/artist/ar1"
      }
    ]
  }
}
```

### 3.5 `music.listSongs`

按专辑或艺术家拉取曲目（`albumId` / `artistId` 至少提供其一；同时提供时以服务器实现为准）。

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `albumId` | string | 二选一 | 按专辑拉取曲目 |
| `artistId` | string | 二选一 | 按艺术家拉取曲目 |
| `offset` | int | 否 | 分页偏移，默认 0 |
| `limit` | int | 否 | 每页数量，默认 200 |

**响应**（曲目结构与 [`music.list`](#32-musiclist) 一致）

```json
{ "jsonrpc": "2.0", "id": 1, "result": { "tracks": [ /* ... */ ] } }
```

### 3.6 `music.streamUrl`

当 `music.list` 未返回 `url` 时，按曲目 id 解析流地址。

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | 曲目 id |

**响应**

```json
{ "jsonrpc": "2.0", "id": 2, "result": { "url": "http://192.168.1.10:8080/stream/1?token=abc123" } }
```

---

## 4. 数据结构：Track

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | 曲目唯一 id |
| `title` | string | 是 | 标题 |
| `artist` | string | 否 | 艺术家 |
| `album` | string | 否 | 专辑 |
| `durationMs` | int | 否 | 时长（毫秒） |
| `url` | string | 否 | 流地址；为空则客户端调 `music.streamUrl` 解析 |
| `coverUrl` | string | 否 | 封面地址（预留） |
| `lyrics` | string | 否 | 内联 LRC 歌词文本；有则直接用于滚动歌词 |

### Album

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | 专辑唯一 id |
| `name` | string | 是 | 专辑名 |
| `artist` | string | 否 | 专辑艺术家 |
| `coverUrl` | string | 否 | 封面地址（预留） |
| `songCount` | int | 否 | 曲目数 |
| `year` | int | 否 | 发行年份 |

### Artist

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | 艺术家唯一 id |
| `name` | string | 是 | 艺术家名 |
| `albumCount` | int | 否 | 专辑数 |
| `songCount` | int | 否 | 曲目数 |
| `coverUrl` | string | 否 | 头像 / 封面地址（预留） |

---

## 5. 错误处理

失败时返回 JSON-RPC 错误对象，客户端会抛出 `MusicServerException`：

```json
{ "jsonrpc": "2.0", "id": 1, "error": { "code": -32601, "message": "未知方法" } }
```

| 场景 | code |
| --- | --- |
| 网络不可达 / 超时 | 客户端本地（`-1`） |
| HTTP 非 200 | HTTP 状态码 |
| JSON-RPC 标准错误 | 见 JSON-RPC 2.0（如 `-32601` 方法不存在） |

---

## 6. 在 Achero 中使用

1. 打开 **Achero → 音乐服务器**（插件页）。
2. 填写「服务器 RPC 地址」（可选访问令牌）。
3. 点「连接并获取列表」，勾选或「全部添加」。
4. 添加的曲目进入曲库，流式播放；`lyrics` 字段会自动成为歌词。曲目的
   `artist` / `album` 字段会由核心 `LibraryCatalog` 统一归类，直接出现在
   主页「曲库 → 专辑 / 艺术家」分栏中（与本地、Subsonic 来源合并展示）。

> 说明：`music.listAlbums` / `music.listArtists` / `music.listSongs` 是
> **可选**的服务器端浏览方法，客户端已实现但当前 UI 不直接使用——曲库分类
> 统一由曲目自带的 `artist` / `album` 字段在客户端完成。

### 缓存

音乐服务器插件只缓存**音频文件**，不缓存列表元数据：

- **列表不缓存**：每次「连接」都实时请求 `music.list`，服务器返回什么就显示什么。
- **音频缓存**：添加曲目时把流下载到 `audio/<id>.<ext>`，之后以本地文件播放
  （离线可播）。
- **TTL 定期清理 / 自定义路径**：默认保留 7 天，插件加载时清理一次 + 每 6
  小时自动清理；路径可在「设置 → 插件 → 音乐服务器 → 缓存」自定义。
- Web 端无文件系统，自动退化为在线流式（不缓存）。

---

## 7. 参考服务端要点

任何能回 JSON 的 HTTP 服务即可实现本协议。最小实现只需两个端点：

```
POST /rpc   → 解析 JSON-RPC，分发到 music.ping / music.list / music.streamUrl
GET  /stream/{id}?token=…   → 返回音频字节流（支持 Range，便于拖动进度）
```

若要支持按专辑 / 艺术家浏览，再实现三个可选方法：`music.listAlbums`、
`music.listArtists`、`music.listSongs`。

以 Dart（`shelf`）为例的思路：

```dart
Future<Response> rpc(Request req) async {
  final body = jsonDecode(await req.readAsString());
  final result = switch (body['method']) {
    'music.ping' => {'ok': true},
    'music.list' => {'tracks': [...serverTracks]},
    'music.listAlbums' => {'albums': [...serverAlbums]},
    'music.listArtists' => {'artists': [...serverArtists]},
    'music.listSongs' => {
        'tracks': serverTracks.where((t) =>
            t.albumId == body['params']['albumId'] ||
            t.artistId == body['params']['artistId']).toList()
      },
    'music.streamUrl' => {
        'url': '${base}/stream/${body['params']['id']}?token=${sign(...)}'
      },
    _ => throw RpcError(-32601, 'unknown method'),
  };
  return Response.ok(jsonEncode({
    'jsonrpc': '2.0',
    'id': body['id'],
    'result': result,
  }));
}
```

> 实现服务端时务必支持 **HTTP Range 请求**，否则进度条拖动与流式播放体验会受影响。
