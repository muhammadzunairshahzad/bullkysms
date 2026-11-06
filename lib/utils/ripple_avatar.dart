import 'package:flutter/material.dart';

class RippleAvatar extends StatefulWidget {
  final String imageUrl;
  final double radius;
  final Color rippleColor;

  const RippleAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 50.0,
    this.rippleColor = Colors.blue,
  });

  @override
  State<RippleAvatar> createState() => _RippleAvatarState();
}

class _RippleAvatarState extends State<RippleAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RipplePainter(animation: _controller, color: widget.rippleColor),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipOval(
          child: Container(
            width: widget.radius * 2,
            height: widget.radius * 2,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(widget.radius * 0.15),
              child: Image.asset(
                widget.imageUrl,
                fit: BoxFit.contain, // ensures image isn't stretched/cropped
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  RipplePainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = size.width / 2 + 35.0;

    // Draw 3 staggered ripple waves
    for (int wave = 3; wave >= 0; wave--) {
      final double progress = (animation.value + (wave * 0.25)) % 1.0;
      final double radius =
          (size.width / 2) + (progress * (maxRadius - (size.width / 2)));
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);

      final Paint paint = Paint()
        ..color = color.withOpacity(opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}
