import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/player/player_controller.dart';
import '../core/plugins/plugin_types.dart';

/// 内置插件：极光 · 炫彩（沉浸式播放视觉）。
///
/// 一个自绘的唱片 + 流动渐变背景 + 频谱条组成的全屏视觉页，
/// 随播放状态旋转、随进度流动。演示编译侧插件能做「脚本插件做不了」的自定义 UI。
class AuroraPlugin extends AcheroPlugin {
  @override
  String get id => 'com.achero.aurora';

  @override
  String get name => '极光 · 炫彩';

  @override
  String get version => '1.0.1';

  @override
  String get description => '沉浸式自绘唱片与流动频谱视觉。';

  @override
  IconData get icon => Icons.auto_awesome;

  @override
  bool get enabledByDefault => false;

  @override
  List<PluginPage> get pages => [
        PluginPage(
          id: '$id.page',
          title: name,
          icon: icon,
          builder: (_) => const _AuroraPage(),
        ),
      ];
}

class _AuroraPage extends StatefulWidget {
  const _AuroraPage();

  @override
  State<_AuroraPage> createState() => _AuroraPageState();
}

class _AuroraPageState extends State<_AuroraPage> with TickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  PlayerController? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = context.read<PlayerController>();
    if (!identical(player, _player)) {
      _player?.removeListener(_sync);
      _player = player..addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    final playing = _player?.isPlaying ?? false;
    if (playing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!playing && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_sync);
    _flow.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.currentTrack;

    return AnimatedBuilder(
      animation: _flow,
      builder: (context, _) {
        final t = _flow.value;
        final hue = (215 + t * 360) % 360;
        final top = HSVColor.fromAHSV(1, hue, 0.62, 0.55).toColor();
        final mid = HSVColor.fromAHSV(1, (hue + 45) % 360, 0.72, 0.32).toColor();
        final bottom = HSVColor.fromAHSV(1, (hue + 95) % 360, 0.82, 0.16).toColor();

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, mid, bottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                if (track != null) ...[
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (track.artist != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        track.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('去曲库挑一首歌，开始炫彩之旅',
                        style: TextStyle(color: Colors.white70)),
                  ),
                Expanded(
                  child: Center(
                    child: RotationTransition(
                      turns: _spin,
                      child: CustomPaint(
                        size: const Size(260, 260),
                        painter: _VinylPainter(
                          labelText: track?.title ?? 'ACHERO',
                          accent: HSVColor.fromAHSV(1, hue, 0.55, 0.85).toColor(),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 96,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _BarsPainter(t: t, color: Colors.white),
                  ),
                ),
                _Controls(player: player),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '上一首',
          iconSize: 36,
          color: Colors.white,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: player.previous,
        ),
        const SizedBox(width: 16),
        IconButton.filled(
          tooltip: player.isPlaying ? '暂停' : '播放',
          iconSize: 48,
          icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          onPressed: player.togglePlayPause,
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: '下一首',
          iconSize: 36,
          color: Colors.white,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: player.next,
        ),
      ],
    );
  }
}

/// 自绘唱片：深色盘面 + 一圈圈密纹 + 中央彩色标签与曲名。
class _VinylPainter extends CustomPainter {
  _VinylPainter({required this.labelText, required this.accent});

  final String labelText;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF14171C));

    for (var r = radius * 0.20; r < radius * 0.93; r += radius * 0.025) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }

    canvas.drawCircle(center, radius * 0.44, Paint()..color = accent);
    canvas.drawCircle(
      center,
      radius * 0.44,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, radius * 0.055, Paint()..color = const Color(0xFF14171C));

    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.14,
          fontWeight: FontWeight.w700,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: radius * 0.72);

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_VinylPainter oldDelegate) =>
      oldDelegate.labelText != labelText || oldDelegate.accent != accent;
}

/// 自绘频谱条：高度随相位正弦波动。
class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.t, required this.color});

  final double t;
  final Color color;

  static const int _count = 36;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / _count;
    final paint = Paint()..color = color.withValues(alpha: 0.9);
    for (var i = 0; i < _count; i++) {
      final wave = 0.5 + 0.5 * sin(t * 2 * pi + i * 0.55);
      final h = size.height * (0.10 + 0.85 * wave);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * slot + slot * 0.28, size.height - h, slot * 0.44, h),
        Radius.circular(slot * 0.22),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
