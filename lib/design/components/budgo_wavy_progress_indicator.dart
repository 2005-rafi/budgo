import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 Expressive linear wavy loading indicator scrolling continuously
/// along a horizontal path with track gap and end stop indicator.
class BudgoWavyProgressIndicator extends StatefulWidget {
  final double? value;
  final double height;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;
  final double trackGap;
  final Color? color;
  final Color? trackColor;
  final String? semanticsLabel;

  const BudgoWavyProgressIndicator({
    super.key,
    this.value,
    this.height = 14.0,
    this.strokeWidth = 3.5,
    this.amplitude = 3.0,
    this.wavelength = 50.0,
    this.trackGap = 6.0,
    this.color,
    this.trackColor,
    this.semanticsLabel,
  });

  @override
  State<BudgoWavyProgressIndicator> createState() =>
      _BudgoWavyProgressIndicatorState();
}

class _BudgoWavyProgressIndicatorState extends State<BudgoWavyProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phaseController;

  @override
  void initState() {
    super.initState();
    // Soft, comfortable wave pace (1700ms) prevents frantic visual motion
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _phaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = widget.color ?? colorScheme.primary;
    final trackColor =
        widget.trackColor ?? colorScheme.surfaceContainerHighest;

    final clampedTarget = widget.value?.clamp(0.0, 1.0);

    return Semantics(
      label: widget.semanticsLabel ?? 'Loading progress',
      value: clampedTarget != null ? '${(clampedTarget * 100).round()}%' : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: clampedTarget ?? 0.45),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return AnimatedBuilder(
            animation: _phaseController,
            builder: (context, _) {
              final phase = _phaseController.value * 2 * math.pi;
              return SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WavyLinearPainter(
                    progress: clampedTarget == null ? null : animatedValue,
                    phase: phase,
                    activeColor: activeColor,
                    trackColor: trackColor,
                    strokeWidth: widget.strokeWidth,
                    amplitude: widget.amplitude,
                    wavelength: widget.wavelength,
                    trackGap: widget.trackGap,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WavyLinearPainter extends CustomPainter {
  final double? progress;
  final double phase;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;
  final double trackGap;

  _WavyLinearPainter({
    required this.progress,
    required this.phase,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
    required this.amplitude,
    required this.wavelength,
    required this.trackGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final leftPad = strokeWidth / 2;
    final rightPad = size.width - strokeWidth / 2;
    final usableWidth = math.max(1.0, rightPad - leftPad);

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    double waveStart;
    double waveEnd;

    if (progress != null) {
      waveStart = leftPad;
      waveEnd = leftPad + usableWidth * progress!;
    } else {
      // Smooth indeterminate traveling span cycling gently left-to-right
      final t = phase / (2 * math.pi);
      final span = usableWidth * 0.36;
      waveStart = leftPad + (usableWidth - span) * t;
      waveEnd = waveStart + span;
    }

    // Draw inactive trailing/leading flat track segments with M3 track gap
    if (progress != null) {
      final trailStart = math.min(rightPad, waveEnd + trackGap);
      if (trailStart < rightPad - 2) {
        canvas.drawLine(
          Offset(trailStart, centerY),
          Offset(rightPad, centerY),
          trackPaint,
        );
      }
      // M3 Expressive end stop indicator dot
      if (progress! < 0.98) {
        final stopPaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(rightPad, centerY),
          strokeWidth * 0.52,
          stopPaint,
        );
      }
    } else {
      canvas.drawLine(
        Offset(leftPad, centerY),
        Offset(rightPad, centerY),
        trackPaint,
      );
    }

    // Draw continuous sinusoidal active wave with zero heap bloat
    final activeLen = waveEnd - waveStart;
    if (activeLen <= 0.5) return;

    final path = Path();
    const double stepPx = 1.5;
    final int steps = math.max(2, (activeLen / stepPx).ceil());
    final twoPiOverLambda = (2 * math.pi) / wavelength;

    // Gentle edge taper so rounded ends sit aligned vertically at centerY
    double taper(double dx) {
      const edgePx = 5.0;
      if (activeLen < edgePx * 2) return math.min(1.0, activeLen / (edgePx * 2));
      if (dx < edgePx) return dx / edgePx;
      if (activeLen - dx < edgePx) return (activeLen - dx) / edgePx;
      return 1.0;
    }

    for (int i = 0; i <= steps; i++) {
      final dx = (i / steps) * activeLen;
      final x = waveStart + dx;
      final envelope = taper(dx);
      final y = centerY +
          math.sin((x * twoPiOverLambda) - phase) * amplitude * envelope;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, activePaint);
  }

  @override
  bool shouldRepaint(covariant _WavyLinearPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}

