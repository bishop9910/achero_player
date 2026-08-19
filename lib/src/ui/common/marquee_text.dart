import 'package:flutter/material.dart';

/// 单行文本：放得下就正常显示，放不下就左右往复滚动（marquee），
/// 让用户能看到完整内容，而不是被省略号截断。
class MarqueeText extends StatefulWidget {
  const MarqueeText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 与实际渲染的 Text 用同一套样式（合并 DefaultTextStyle）测量，
        // 并采用系统字体缩放，保证滚动距离和真实渲染宽度一致。
        final style = DefaultTextStyle.of(context).style.merge(widget.style);
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();

        final overflows = painter.width > constraints.maxWidth;
        if (!overflows) {
          _controller.stop();
          _controller.value = 0;
          return Text(widget.text, maxLines: 1, style: widget.style);
        }

        // 幂等启动往复滚动。
        if (!_controller.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_controller.isAnimating) {
              _controller.repeat(reverse: true);
            }
          });
        }

        final maxOffset = painter.width - constraints.maxWidth;
        return ClipRect(
          // 关键：让 Text 按完整内容宽度排版。若不加 OverflowBox，Text 会被
          // 父级 maxWidth 约束直接裁掉，滚动的就只是被截断的片段。
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(-maxOffset * _controller.value, 0),
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    softWrap: false,
                    style: widget.style,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
