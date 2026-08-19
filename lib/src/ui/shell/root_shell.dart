import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/player/player_controller.dart';
import '../../core/plugins/plugin_registry.dart';
import '../downloads/download_fab.dart';
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
                        Expanded(
                          child: Stack(
                            children: [
                              content,
                              const Positioned(
                                right: 16,
                                bottom: 12,
                                child: DownloadFab(),
                              ),
                            ],
                          ),
                        ),
                        NowPlayingBar(onTap: _openPlayer),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      content,
                      const Positioned(
                        right: 16,
                        bottom: 12,
                        child: DownloadFab(),
                      ),
                    ],
                  ),
                ),
                NowPlayingBar(onTap: _openPlayer),
                _MobileNavBar(
                  destinations: destinations,
                  selectedIndex: _index.clamp(0, destinations.length - 1),
                  onSelected: (i) => setState(() => _index = i),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openPlayer() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: scheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 1.0,
        child: Column(
          children: [
            // 顶部：下拉把手（手机往下滑退出）+ 关闭按钮。
            SizedBox(
              height: 44,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        tooltip: '收起',
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: PlayerPage()),
          ],
        ),
      ),
    );
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

/// 手机端底部导航：单行文字 + 左右箭头横向滚动，避免文字换行挤压。
class _MobileNavBar extends StatefulWidget {
  const _MobileNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_MobileNavBar> createState() => _MobileNavBarState();
}

class _MobileNavBarState extends State<_MobileNavBar> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBy(double dx) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + dx)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _scrollBy(-140),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < widget.destinations.length; i++)
                      _MobileNavItem(
                        destination: widget.destinations[i],
                        selected: i == widget.selectedIndex,
                        onTap: () => widget.onSelected(i),
                      ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _scrollBy(140),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? destination.selectedIcon : destination.icon,
                color: color),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}
