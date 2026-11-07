import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

/// ═══════════════════════════════════════════════════════════════
/// GEMINI-STYLE BREATHING
/// One shared 9-second gradient phase (blue → violet → rose →
/// amber → violet → blue) used by the brand tile, screen titles
/// and the dynamic live island. All widgets read the same phase,
/// so every breathing element moves in step.
/// ═══════════════════════════════════════════════════════════════

class BreathingColors {
  /// 5 Gemini hues, doubled at the ends for a seamless orbit loop.
  static const List<Color> stops = [
    Color(0xFF4285F4), // Blue
    Color(0xFF9B72CB), // Violet
    Color(0xFFE86C8C), // Rose
    Color(0xFFF5A623), // Amber
    Color(0xFF9B72CB),
    Color(0xFF4285F4),
  ];

  static const Duration cycle = Duration(seconds: 9);

  /// The gradient at phase [t] (0..1). Begin/end alignments mirror
  /// each other around the centre, so a full cycle loops seamlessly.
  static LinearGradient gradientOf(double t) {
    final a = t * 2 * math.pi;
    return LinearGradient(
      begin: Alignment(-math.cos(a), -math.sin(a)),
      end: Alignment(math.cos(a), math.sin(a)),
      colors: stops,
      stops: const [0.0, 0.18, 0.42, 0.62, 0.82, 1.0],
    );
  }
}

/// App-wide single 9s heartbeat. Widgets listen to this instance so
/// the tile, titles and island breathe in sync instead of drifting.
class BreathingPhase extends ChangeNotifier {
  BreathingPhase._() {
    Ticker(_tick);
    _ticker.start();
  }

  static final BreathingPhase instance = BreathingPhase._();

  late final Ticker _ticker = Ticker(_tick);
  double _value = 0;

  double get value => _value;

  void _tick(Duration elapsed) {
    final v = (elapsed.inMicroseconds / BreathingColors.cycle.inMicroseconds) % 1;
    _value = v;
    notifyListeners();
  }
}

/// Rounded breathing tile — the brand logo box (crown on gradient).
class BreathingTile extends StatelessWidget {
  final Widget? child;
  final double size;
  final double radius;

  const BreathingTile({
    super.key,
    this.child,
    this.size = 34,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BreathingPhase.instance,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: BreathingColors.gradientOf(BreathingPhase.instance.value),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Screen-title text filled with the breathing gradient (dark-ink
/// replacement that slowly shifts hue).
class BreathingText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const BreathingText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BreathingPhase.instance,
      builder: (context, child) {
        final t = BreathingPhase.instance.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              BreathingColors.gradientOf(t).createShader(bounds),
          child: child,
        );
      },
      child: Text(
        text,
        style: style?.copyWith(color: Colors.white),
      ),
    );
  }
}

/// Thin breathing gradient rule used along the bottom edge of the
/// app headers (the "3px underline" from the light-theme mock).
class BreathingUnderline extends StatelessWidget {
  final double height;
  final double radius;

  const BreathingUnderline({
    super.key,
    this.height = 3,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BreathingPhase.instance,
      builder: (context, _) => Container(
        height: height,
        decoration: BoxDecoration(
          gradient: BreathingColors.gradientOf(BreathingPhase.instance.value),
          borderRadius:
              radius > 0 ? BorderRadius.circular(radius) : BorderRadius.zero,
        ),
      ),
    );
  }
}

/// A breathing gradient ring drawn *around* its child (used by the
/// dynamic live island). The child keeps its own decoration; the halo
/// floats just outside it.
class BreathingHalo extends StatelessWidget {
  final Widget child;
  final double inset; // distance between child edge and the ring
  final double strokeWidth;
  final BorderRadius borderRadius;

  const BreathingHalo({
    super.key,
    required this.child,
    this.inset = 4,
    this.strokeWidth = 2.5,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(inset + strokeWidth / 2),
      child: AnimatedBuilder(
        animation: BreathingPhase.instance,
        builder: (context, child) {
          return CustomPaint(
            painter: _HaloPainter(
              t: BreathingPhase.instance.value,
              borderRadius: borderRadius,
              strokeWidth: strokeWidth,
            ),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  final double t;
  final BorderRadius borderRadius;
  final double strokeWidth;

  _HaloPainter({
    required this.t,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader =
          BreathingColors.gradientOf(t).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.t != t;
}

/// Hand-drawn crown glyph (moved from the Settings PRO banner so the
/// brand tile and the banner share one rendering).
class CrownIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CrownIcon({super.key, this.size = 22, this.color = const Color(0xFF00D06C)});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.72),
      painter: _CrownPainter(color: color),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final Color color;
  _CrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.12, h * 0.88);
    path.lineTo(w * 0.88, h * 0.88);
    path.lineTo(w * 0.86, h * 0.38);
    path.lineTo(w * 0.66, h * 0.60);
    path.lineTo(w * 0.50, h * 0.18);
    path.lineTo(w * 0.34, h * 0.60);
    path.lineTo(w * 0.14, h * 0.38);
    path.close();

    canvas.drawPath(path, paint);

    final r = w * 0.055;
    canvas.drawCircle(Offset(w * 0.14, h * 0.34), r, paint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.14), r * 1.15, paint);
    canvas.drawCircle(Offset(w * 0.86, h * 0.34), r, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
