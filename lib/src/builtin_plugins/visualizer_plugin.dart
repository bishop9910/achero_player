import 'dart:math';

import 'package:flutter/material.dart';

import '../core/player/player_controller.dart';
import '../core/plugins/plugin_types.dart';

/// 内置示例插件：播放页可视化频谱条。
///
/// 说明：当前引擎（media_kit）不暴露音频采样数据，因此无法在纯 Dart 下做真正的 FFT。
/// 这里改用「播放上下文」驱动——曲目 id 生成确定性种子（每首歌频谱形态不同），
/// 实际播放进度影响相位与节拍（随歌曲推进而演变、暂停即静止），
/// 同时用 AnimationController 保证 60fps 平滑。
class VisualizerPlugin extends AcheroPlugin {
  @override
  String get id => 'com.achero.visualizer';

  @override
  String get name => '可视化频谱';

  @override
  String get version => '1.0.5';

  @override
  String get description => '随播放进度与曲目变化的频谱条。';

  @override
  IconData get icon => Icons.graphic_eq;

  PluginContext? _context;

  @override
  Future<void> onLoad(PluginContext context) async {
    _context = context;
  }

  @override
  Future<void> onUnload() async {
    _context = null;
  }

  @override
  List<PlayerWidget> get playerWidgets => [
        PlayerWidget(
          id: '$id.spectrum',
          title: '频谱',
          builder: (context) => _SpectrumBars(player: _context!.player),
        ),
      ];
}

class _SpectrumBars extends StatefulWidget {
  const _SpectrumBars({required this.player});

  final PlayerController player;

  @override
  State<_SpectrumBars> createState() => _SpectrumBarsState();
}

class _SpectrumBarsState extends State<_SpectrumBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  static const int _barCount = 28;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_sync);
    _sync();
  }

  void _sync() {
    final playing = widget.player.isPlaying;
    if (playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!playing && _controller.isAnimating) {
      _controller.stop();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.player.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.player.isPlaying;
    final track = widget.player.currentTrack;
    final seed = track == null ? 0.0 : _seedOf(track.id);
    final pos = widget.player.position.inMilliseconds / 1000.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.value * 2 * pi;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (i) {
            final height = active ? _barHeight(phase, pos, i, seed) : 4.0;
            return Container(
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: active ? 0.9 : 0.35),
                borderRadius: BorderRadius.circular(2.5),
              ),
            );
          }),
        );
      },
    );
  }

  double _barHeight(double phase, double pos, int i, double seed) {
    // 多频率叠加，制造类似频谱的起伏。
    final v = 0.5 +
        0.28 * sin(phase * 2.6 + i * 0.75 + seed * 6.28) +
        0.18 * sin(phase * 4.1 + i * 1.4 + seed * 12.5) +
        0.08 * sin((phase + pos) * 6.7 + i * 2.1);
    // 低频节拍包络，随实际播放进度推进。
    final beat = 0.75 + 0.25 * sin((phase + pos) * 4.4);
    return 6 + (v * beat).clamp(0.0, 1.0) * 42;
  }

  double _seedOf(String id) {
    var h = 0;
    for (final unit in id.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return (h % 1000) / 1000.0;
  }
}
