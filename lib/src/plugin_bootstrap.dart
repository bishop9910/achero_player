import 'builtin_plugins/aurora_plugin.dart';
import 'builtin_plugins/desktop_lyrics_plugin.dart';
import 'builtin_plugins/music_server_plugin.dart';
import 'builtin_plugins/subsonic_plugin.dart';
import 'builtin_plugins/tags_plugin.dart';
import 'builtin_plugins/visualizer_plugin.dart';
import 'core/plugins/plugin_registry.dart';

/// 插件注册入口（编译进应用的部分）。
///
/// 说明：Achero 有两类插件——
/// 1. **运行时脚本插件**：放在插件目录里的独立 `.dart` 文件，启动时由
///    `ScriptPluginLoader` 扫描并执行（无需重新编译）。见 `docs/RUNTIME_PLUGINS.md`。
/// 2. **编译侧插件**：下方这些需要依赖 `http` / `crypto` / 动画等重能力的插件，
///    随应用一起编译。它们与脚本插件统一接入同一个 [PluginRegistry]。
///
/// 要新增编译侧插件：新建一个继承 `AcheroPlugin` 的类（参考 `builtin_plugins/`），
/// 在下方 `registry.register(你的插件())`。完整指南见 `docs/PLUGINS.md`。
void registerAllPlugins(PluginRegistry registry) {
  registry
    ..register(VisualizerPlugin())
    ..register(MusicServerPlugin())
    ..register(SubsonicPlugin())
    ..register(TagsPlugin())
    ..register(AuroraPlugin())
    ..register(DesktopLyricsPlugin());

  // ── 在此添加你的编译侧插件 ────────────────────────────────────────
  // registry.register(MyPlugin());
}
