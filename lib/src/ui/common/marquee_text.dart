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
          //
          // OverflowBox 的 fit 默认为 max，会把自己撑到 `constraints.biggest`：
          // 在高度无界的容器（如竖向列表的 ListTile subtitle）里，那会让它的
          // 高度变成无穷大，触发 "RenderFlex ... infinite size"，并级联出
          // NaN / Matrix4 等报错；在高度有界但宽松的容器里，则会把这一行撑到
          // 可用高度的最大值，把下面的进度条挤乱。这里用 SizedBox 把高度固定
          // 为单行文本高度，只允许横向溢出，纵向保持与普通单行文本一致。
          child: SizedBox(
            height: painter.height,
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
          ),
        );
      },
    );
  }
}
