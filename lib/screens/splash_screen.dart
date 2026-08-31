import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Drop this widget in as your app's home / initial route.
/// It plays: ring sweep-in -> continuous pulse -> letter-by-letter text
/// reveal, then calls [onFinished] (e.g. to navigate to your home screen).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.appName = 'FITRYBE',
    this.onFinished,
  });

  final String appName;
  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF0C0F16);
  static const _orange = Color(0xFFFE6A2B);

  late final AnimationController _drawCtrl; // ring sweep-in
  late final AnimationController _pulseCtrl; // continuous breathing scale
  late final AnimationController _textCtrl; // letter-by-letter reveal

  late final Animation<double> _drawAnim;
  late final Animation<double> _pulseAnim;

  int _visibleLetters = 0;

  @override
  void initState() {
    super.initState();

    _drawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _drawAnim = CurvedAnimation(parent: _drawCtrl, curve: Curves.easeOutCubic);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseCtrl);

    _textCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 110 * widget.appName.length),
    )..addListener(() {
        final letters = (_textCtrl.value * widget.appName.length)
            .floor()
            .clamp(0, widget.appName.length);
        if (letters != _visibleLetters) setState(() => _visibleLetters = letters);
      });

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _drawCtrl.forward();
    _pulseCtrl.repeat(reverse: true); // keeps pulsing for the rest of the splash
    await Future.delayed(const Duration(milliseconds: 200));
    await _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_drawAnim, _pulseAnim]),
              builder: (context, _) {
                final scale = _drawCtrl.isCompleted ? _pulseAnim.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: CustomPaint(
                    size: const Size(120, 120),
                    painter: _RingLogoPainter(
                      progress: _drawAnim.value,
                      color: _orange,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            Text(
              widget.appName.substring(0, _visibleLetters),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the 3-blade "broken ring" logo: each arc spans ~93° with a ~27°
/// gap between blades, matching the source animation's proportions.
class _RingLogoPainter extends CustomPainter {
  _RingLogoPainter({required this.progress, required this.color});

  final double progress; // 0 -> 1 sweep-in progress
  final Color color;

  static const _arcSweepDeg = 93.0; // (93 + 27) * 3 == 360
  static const _startAnglesDeg = [210.0, 330.0, 90.0]; // top, right, bottom-left

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final strokeWidth = size.width * 0.16; // ring thickness ratio from source
    final meanRadius = outerRadius - strokeWidth / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: meanRadius);
    final sweepRad = _arcSweepDeg * math.pi / 180 * progress;

    for (final startDeg in _startAnglesDeg) {
      canvas.drawArc(rect, startDeg * math.pi / 180, sweepRad, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingLogoPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
