import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/player/player_controller.dart';
import '../../core/plugins/plugin_registry.dart';
import '../library/library_page.dart';
import '../player/now_playing_bar.dart';
import '../player/player_page.dart';
import '../playlists/playlists_page.dart';
import '../settings/settings_page.dart';

/// 应用根壳层：响应式导航 + 迷你播放条。
///
/// 宽屏（>= 840px）使用左侧 NavigationRail，窄屏使用底部 NavigationBar；
/// 两种形态底部都停靠 [NowPlayingBar]，点击跳转到「正在播放」页。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  int _playerIndex = 1;
  PlayerController? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = context.read<PlayerController>();
    if (!identical(player, _player)) {
      _player?.playbackError.removeListener(_onPlaybackError);
      _player = player..playbackError.addListener(_onPlaybackError);
    }
  }

  @override
  void dispose() {
    _player?.playbackError.removeListener(_onPlaybackError);
    super.dispose();
  }

  void _onPlaybackError() {
    final message = _player?.playbackError.value;
    if (message == null || !mounted) return;
    _player?.playbackError.value = null; // 展示一次后清空，避免重复弹出
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<PluginRegistry>();
    final destinations = _buildDestinations(registry);
    _playerIndex = _indexOfPlayer(destinations);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final selectedIndex = _index.clamp(0, destinations.length - 1);
            final content = IndexedStack(
              index: selectedIndex,
              children: [
                // 非当前页用 TickerMode 停掉动画 ticker，避免隐藏页（如极光）
                // 的常驻动画持续消耗帧预算，导致主题切换等场景卡顿。
                for (var i = 0; i < destinations.length; i++)
                  TickerMode(
                    enabled: i == selectedIndex,
                    child: destinations[i].builder(context),
                  ),
              ],
            );

            if (wide) {
              return Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index.clamp(0, destinations.length - 1),
                    onDestinationSelected: (i) => setState(() => _index = i),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: content),
                        NowPlayingBar(onTap: _openPlayer),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: content),
                NowPlayingBar(onTap: _openPlayer),
                NavigationBar(
                  selectedIndex: _index.clamp(0, destinations.length - 1),
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final d in destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: d.label,
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openPlayer() {
    if (_playerIndex >= 0) setState(() => _index = _playerIndex);
  }

  int _indexOfPlayer(List<_Destination> destinations) {
    final i = destinations.indexWhere((d) => d.isPlayer);
    return i < 0 ? 0 : i;
  }

  List<_Destination> _buildDestinations(PluginRegistry registry) {
    return [
      _Destination(
        label: '曲库',
        icon: Icons.library_music_outlined,
        selectedIcon: Icons.library_music,
        builder: (_) => const LibraryPage(),
      ),
      _Destination(
        label: '正在播放',
        icon: Icons.album_outlined,
        selectedIcon: Icons.album,
        isPlayer: true,
        builder: (_) => const PlayerPage(),
      ),
      _Destination(
        label: '播放列表',
        icon: Icons.queue_music_outlined,
        selectedIcon: Icons.queue_music,
        builder: (_) => const PlaylistsPage(),
      ),
      for (final page in registry.pages)
        _Destination(
          label: page.title,
          icon: page.icon,
          selectedIcon: page.icon,
          builder: page.builder,
        ),
      _Destination(
        label: '设置',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        builder: (_) => const SettingsPage(),
      ),
    ];
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.isPlayer = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
  final bool isPlayer;
}
