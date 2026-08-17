# 运行时脚本插件（独立 `.dart` 文件）

Achero 的插件分为两类：

1. **编译侧插件**：随应用一起编译（见 `docs/PLUGINS.md`），适合需要
   `http` / `crypto` / 动画等重能力的插件。
2. **运行时脚本插件**：**独立的 `.dart` 源文件**，放在插件目录里，应用启动时
   扫描、编译、执行——**无需重新编译宿主**。本文档描述这一类。

> 原理：Flutter AOT 无法在运行时加载任意 Dart 代码，因此脚本由
> [dart_eval](https://pub.dev/packages/dart_eval)（用 Dart 写的 Dart 解释器）
> 解释执行。脚本仍是 Dart 语法，但运行在沙箱内、只支持 Dart 子集，
> 且只能通过宿主暴露的 `call` API 与播放器交互。

---

## 1. 插件文件放在哪

| 平台 | 目录 | 说明 |
| --- | --- | --- |
| Windows / Linux / Android | `<应用数据目录>/plugins/` | 把 `.dart` 文件拖进去，重启应用即加载 |
| Web | `assets/plugins/`（打包进应用） | 浏览器无文件系统，直接加载内置脚本 |

首次运行会把内置示例脚本复制到插件目录，方便你查看、修改、删除：
`statistics_plugin.dart`、`theme_presets_plugin.dart`。

---

## 2. 插件契约

一个插件就是一个 `.dart` 文件，声明若干**顶层函数**。脚本与宿主通过
**JSON 字符串**通信：脚本返回 JSON，宿主渲染；脚本用 `call(method, paramsJson)`
调用宿主能力。

### 2.1 必选：`manifest`

返回插件清单（JSON 字符串）。`manifest()` 中**不要调用 `call`**（此时宿主
上下文尚未就绪）。

```dart
import 'dart:convert';

String manifest(Function call) {
  return jsonEncode({
    'id': 'com.example.hello',          // 全局唯一
    'name': '你好插件',
    'version': '1.0.0',
    'description': '一个示例',
    'icon': 'extension',                 // Material 图标名（见 §5）
    'page': {                            // 可选：贡献独立页面
      'id': 'com.example.hello.page',
      'title': '你好',
      'icon': 'waving_hand',
      'sort': true,                      // 可选：页面顶部显示「正序/倒序」切换
    },
    'settings': {                        // 可选：贡献设置区块
      'id': 'com.example.hello.settings',
      'title': '我的设置',
    },
    'events': ['trackStarted'],          // 可选：订阅的宿主事件
  });
}
```

### 2.2 页面：`pageRows`

当有 `page` 时，宿主调用 `pageRows(call)`，返回行数组（JSON）：

```dart
String pageRows(Function call) {
  return jsonEncode([
    {'title': '第一行', 'subtitle': '副标题', 'trailing': '右侧', 'action': 'row:1'},
  ]);
}

void onPageAction(Function call, String action) {
  call('log', jsonEncode({'msg': '点了 $action'}));
}
```

若 `page.sort` 为 `true`，宿主会在页面顶部渲染「倒序 / 正序」切换，并把当前方向
（`'desc'` 倒序 / `'asc'` 正序，默认 `'desc'`）作为第二个参数传给 `pageRows`：

```dart
String pageRows(Function call, String sortDir) {
  // 按 sortDir 决定排序方向：'desc' 从大到小，'asc' 从小到大
  ...
}
```

参考实现见 `assets/plugins/statistics_plugin.dart`（播放统计，按次数正序/倒序）。

### 2.3 设置：`settingsTiles` / `onSettingsAction`

当有 `settings` 时：

```dart
String settingsTiles(Function call) {
  return jsonEncode([
    {'title': '开启某功能', 'subtitle': '说明', 'action': 'toggle'},
  ]);
}

void onSettingsAction(Function call, String action) {
  call('log', jsonEncode({'msg': action}));
}
```

**行字段**（`pageRows` / `settingsTiles` 通用，均可选）：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `title` | String | 标题 |
| `subtitle` | String | 副标题 |
| `trailing` | String | 右侧文字（设置项缺省显示箭头） |
| `action` | String | 点击后回传给 `onPageAction` / `onSettingsAction` |
| `color` | int | ARGB 颜色，行**右侧**渲染一个色点（如主题预设） |

### 2.4 事件：`onEvent`

`manifest.events` 声明要订阅的事件后，宿主会把事件转发给脚本：

```dart
void onEvent(Function call, String name, String payloadJson) {
  final payload = jsonDecode(payloadJson);
  call('log', jsonEncode({'msg': name + ' -> ' + payload['title']}));
}
```

支持的事件：`trackStarted` / `trackChanged`（payload 含 `id` `title` `artist`）、
`stateChanged`（`status`）、`libraryChanged`（`count`）。

### 2.5 生命周期（可选）

```dart
void onLoad(Function call) {}
void onUnload(Function call) {}
```

---

## 3. 宿主 API（`call`）

`call(method, paramsJson)` 返回结果 JSON（或 `$null`）。当前提供：

| method | params | 返回 |
| --- | --- | --- |
| `log` | `{msg}` | - |
| `prefsGet` | `{key}` | `String?`（插件专属键值） |
| `prefsSet` | `{key, value}` | - |
| `prefsGetInt` / `prefsSetInt` | `{key}` / `{key, value}` | `int?` / - |
| `prefsRemove` | `{key}` | - |
| `listTracks` | `{}` | JSON 数组 `[{id,title,artist,album}]` |
| `trackCount` | `{}` | `int` |
| `setSeedColor` | `{argb}` | -（改主题种子色） |
| `getSeedColor` | `{}` | `int` |
| `setBrightness` | `{value: light/dark/system}` | - |

新增宿主能力：在 `lib/src/core/plugins/script/script_plugin_adapter.dart` 的
`_dispatch` 中加一个 `case` 即可。

---

## 4. 完整示例

仓库自带两个脚本插件：

**`assets/plugins/statistics_plugin.dart`（播放统计）** —— 演示事件 + 持久化 + 页面：

```dart
import 'dart:convert';

String manifest(Function call) {
  return jsonEncode({
    'id': 'com.achero.statistics',
    'name': '播放统计',
    'version': '1.0.0',
    'description': '记录每首曲目的播放次数并展示排行榜',
    'icon': 'bar_chart',
    'page': {'id': 'com.achero.statistics.page', 'title': '播放统计', 'icon': 'bar_chart'},
    'events': ['trackStarted'],
  });
}

void onEvent(Function call, String name, String payloadJson) {
  if (name != 'trackStarted') return;
  final payload = jsonDecode(payloadJson);
  final id = payload['id'];
  if (id == null) return;

  final raw = call('prefsGet', jsonEncode({'key': 'plays'}));
  var counts = {};
  if (raw != null) counts = jsonDecode(raw);
  counts[id] = (counts[id] ?? 0) + 1;
  call('prefsSet', jsonEncode({'key': 'plays', 'value': jsonEncode(counts)}));
}

String pageRows(Function call) {
  final raw = call('prefsGet', jsonEncode({'key': 'plays'}));
  var counts = {};
  if (raw != null) counts = jsonDecode(raw);
  final tracks = jsonDecode(call('listTracks', '{}'));
  final rows = [];
  for (final t in tracks) {
    final n = counts[t['id']] ?? 0;
    if (n > 0) {
      rows.add({'title': t['title'], 'subtitle': t['artist'] ?? '', 'trailing': '$n 次', '_count': n});
    }
  }
  rows.sort((a, b) => b['_count'].compareTo(a['_count']));
  final out = [];
  for (final r in rows) {
    out.add({'title': r['title'], 'subtitle': r['subtitle'], 'trailing': r['trailing']});
  }
  return jsonEncode(out);
}
```

**`assets/plugins/theme_presets_plugin.dart`（主题预设）** —— 演示设置区块 + 修改宿主主题：

```dart
import 'dart:convert';

String manifest(Function call) {
  return jsonEncode({
    'id': 'com.achero.themePresets',
    'name': '主题预设',
    'version': '1.0.0',
    'description': '一键套用配色方案',
    'icon': 'palette',
    'settings': {'id': 'com.achero.themePresets.settings', 'title': '主题预设'},
  });
}

String settingsTiles(Function call) {
  return jsonEncode([
    {'title': '海洋蓝', 'subtitle': '默认风格', 'color': 0xFF0984E3, 'action': (0xFF0984E3).toString()},
    {'title': '赛博紫', 'subtitle': '深邃经典', 'color': 0xFF6C5CE7, 'action': (0xFF6C5CE7).toString()},
  ]);
}

void onSettingsAction(Function call, String action) {
  call('setSeedColor', jsonEncode({'argb': int.parse(action)}));
}
```

---

## 5. 图标名

`manifest` 与 `page` 的 `icon` 是 Material 图标名字符串，当前内置映射：
`extension` `bar_chart` `palette` `waving_hand` `music_note` `settings` `cloud`
`star` `favorite` `info` `insights` `history` `queue_music`。未知名回退到
`extension`。要增加图标，编辑 `script_plugin_adapter.dart` 的 `_icons` 映射。

---

## 6. 限制与注意

- **Dart 子集**：由 dart_eval 解释执行，不支持生成器、扩展方法等；只支持
  `dart:core` / `dart:convert` 的常用部分。
- **沙箱**：默认无法访问文件系统 / 网络，只能通过 `call` 使用宿主能力。
- **声明式 UI**：脚本不直接构造 Flutter widget，而是返回「行数据」，宿主渲染。
- **版本锁定**：dart_eval 与 Dart SDK 强绑定（当前锁 0.8.5 / SDK 3.12）。
- **写法注意**：给变量显式标注 `Map` / `List` 类型可能触发 dart_eval 的装箱
  问题，**请用 `var` / `dynamic`**（见上方示例）。
- **manifest 不要调用 `call`**：清单在宿主上下文就绪前执行。

---

## 7. 验证

纯 Dart 端到端验证（无需 Flutter 引擎）：

```bash
dart run tool/verify_dart_eval.dart
```

它会加载 `assets/plugins` 下的两个真实脚本，用 mock 宿主跑通「统计」「主题预设」，
断言行为正确后打印 `ALL OK`。
