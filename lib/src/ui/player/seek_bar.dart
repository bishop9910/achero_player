import 'package:flutter/material.dart';

import '../common/formats.dart';

/// 可拖动的播放进度条。
///
/// 拖动期间显示临时位置，松手后回调 [onSeek] 真正跳转，
/// 避免进度条与播放器互相打架。
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final value = totalMs <= 0
        ? 0.0
        : ((_dragValue ??
                    widget.position.inMilliseconds.toDouble()) /
                totalMs)
            .clamp(0.0, 1.0);

    final shown = _dragValue == null
        ? widget.position
        : Duration(milliseconds: (_dragValue! * totalMs).round());

    return Row(
      children: [
        Text(
          formatDuration(shown),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Expanded(
          child: Slider(
            value: value,
            onChangeStart: (v) => setState(() => _dragValue = v),
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              setState(() => _dragValue = null);
              if (totalMs > 0) {
                widget.onSeek(Duration(milliseconds: (v * totalMs).round()));
              }
            },
          ),
        ),
        Text(
          formatDuration(widget.duration),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}
