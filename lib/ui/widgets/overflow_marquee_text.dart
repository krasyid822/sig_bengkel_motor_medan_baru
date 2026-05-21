import 'package:flutter/material.dart';

class OverflowMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final double gap;
  final double pixelsPerSecond;
  final int maxLines;

  const OverflowMarqueeText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.gap = 32,
    this.pixelsPerSecond = 36,
    this.maxLines = 1,
  });

  @override
  State<OverflowMarqueeText> createState() => _OverflowMarqueeTextState();
}

class _OverflowMarqueeTextState extends State<OverflowMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Duration? _lastDuration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = DefaultTextStyle.of(context).style.merge(widget.style);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: resolvedStyle),
          textDirection: direction,
          textScaler: scaler,
          maxLines: widget.maxLines,
        )..layout(maxWidth: double.infinity);

        final textWidth = painter.width;
        final textHeight = painter.height;
        final shouldScroll = maxWidth.isFinite && textWidth > maxWidth;

        if (!shouldScroll) {
          _controller.stop();
          return Text(
            widget.text,
            style: resolvedStyle,
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            softWrap: false,
          );
        }

        final travelDistance = textWidth + widget.gap;
        final durationMs = (travelDistance / widget.pixelsPerSecond * 1000).round().clamp(1, 600000);
        final duration = Duration(milliseconds: durationMs);

        if (_lastDuration != duration || !_controller.isAnimating) {
          _lastDuration = duration;
          _controller
            ..duration = duration
            ..repeat();
        }

        final textWidget = Text(
          widget.text,
          style: resolvedStyle,
          maxLines: 1,
          softWrap: false,
        );

        return ClipRect(
          child: SizedBox(
            height: textHeight,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = -travelDistance * _controller.value;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                children: [
                  textWidget,
                  SizedBox(width: widget.gap),
                  textWidget,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
