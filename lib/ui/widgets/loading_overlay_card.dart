import 'package:flutter/material.dart';

class LoadingOverlayCard extends StatelessWidget {
  final double progress;
  final String message;
  final Color color;
  final Color? barrierColor;
  final Color? cardColor;
  final Color? progressBackgroundColor;
  final Color? textColor;

  const LoadingOverlayCard({
    super.key,
    required this.progress,
    required this.message,
    required this.color,
    this.barrierColor,
    this.cardColor,
    this.progressBackgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final resolvedTextColor = textColor ?? const Color(0xFF111827);

    return Positioned.fill(
      child: ColoredBox(
        color: barrierColor ?? Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: Container(
            width: 320,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: cardColor ?? Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${(clampedProgress * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: resolvedTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: clampedProgress,
                    minHeight: 14,
                    backgroundColor: progressBackgroundColor ?? color.withValues(alpha: 0.18),
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
