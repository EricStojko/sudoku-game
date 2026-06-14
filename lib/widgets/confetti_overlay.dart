import 'dart:math';
import 'package:flutter/material.dart';

enum ConfettiShape { circle, square, triangle }

/// A full-screen confetti animation overlay. Pass [showConfetti] = true to
/// trigger the animation. It is non-interactive ([IgnorePointer] wrapped).
class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool showConfetti;

  const ConfettiOverlay({
    super.key,
    required this.child,
    required this.showConfetti,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  List<ConfettiParticle> _particles = [];
  final Random _rand = Random();
  double _lastWidth = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4));
    // REMOVED: _ctrl.addListener(() => setState(() {})); to avoid rebuilding the entire stack.
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showConfetti && !oldWidget.showConfetti) {
      if (_lastWidth > 0) _generateParticles(_lastWidth);
      _ctrl.forward(from: 0);
    }
  }

  void _generateParticles(double width) {
    final pastelColors = [
      const Color(0xFFC4B5FD), // Soft purple
      const Color(0xFFA7F3D0), // Soft mint green
      const Color(0xFFFBCFE8), // Soft pink
      const Color(0xFFFDA4AF), // Soft red
      const Color(0xFFFDE047), // Soft yellow
      const Color(0xFF93C5FD), // Soft blue
    ];
    _particles = List.generate(150, (_) {
      return ConfettiParticle(
        x: _rand.nextDouble() * width,
        y: -50.0 - _rand.nextDouble() * 200,
        dx: _rand.nextDouble() * 200 - 100,
        dy: _rand.nextDouble() * 400 + 200,
        size: _rand.nextDouble() * 6 + 4,
        color: pastelColors[_rand.nextInt(pastelColors.length)],
        shape: ConfettiShape.values[_rand.nextInt(ConfettiShape.values.length)],
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child, // The rest of the app - never rebuilt by the confetti ticker
        if (widget.showConfetti)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(builder: (context, constraints) {
                if (_lastWidth != constraints.maxWidth) {
                  _lastWidth = constraints.maxWidth;
                  _generateParticles(_lastWidth);
                }
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, child) {
                    if (!_ctrl.isAnimating) return const SizedBox.shrink();
                    return CustomPaint(
                      painter: ConfettiPainter(_particles, _ctrl.value),
                    );
                  },
                );
              }),
            ),
          ),
      ],
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color;
      final x = p.x + p.dx * progress;
      // Parabolic gravity: y increases quadratically over time.
      final y = p.y + p.dy * progress + 400 * progress * progress;

      canvas.save();
      canvas.translate(x, y);
      // Rotate shapes as they fall
      canvas.rotate(progress * pi * 4 + p.x); // use p.x as a random starting angle offset
      
      switch (p.shape) {
        case ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, p.size, paint);
          break;
        case ConfettiShape.square:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size * 2, height: p.size * 2),
            paint,
          );
          break;
        case ConfettiShape.triangle:
          final path = Path()
            ..moveTo(0, -p.size)
            ..lineTo(p.size, p.size)
            ..lineTo(-p.size, p.size)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class ConfettiParticle {
  final double x, y, dx, dy, size;
  final Color color;
  final ConfettiShape shape;

  const ConfettiParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    required this.shape,
  });
}
