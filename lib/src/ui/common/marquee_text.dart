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
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          // 用实际环境的方向与字体缩放来测量，保证与下方 Text 的渲染宽度一致；
          // 否则在手机端系统字体放大时，marquee 的滚动距离算小，末尾字符被截断。
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
        );
      },
    );
  }
}
