import 'package:flutter/material.dart';

class ScannerOverlay extends StatefulWidget {
  final Rect? scanWindow;
  final double overlayAspectRatio; // 1.0 = Square, >1.0 = Wide, <1.0 = Tall
  
  const ScannerOverlay({
    super.key,
    this.scanWindow,
    this.overlayAspectRatio = 1.0,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: ScannerOverlayPainter(
              scanWindow: widget.scanWindow,
              value: _animation.value,
              overlayAspectRatio: widget.overlayAspectRatio,
            ),
          ),
        );
      },
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Rect? scanWindow;
  final double value;
  final double overlayAspectRatio;

  ScannerOverlayPainter({
    this.scanWindow,
    required this.value,
    required this.overlayAspectRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;
    
    // Default scan window if not provided
    // Calculate based on aspect ratio
    final double scanWidth = width * 0.7;
    final double scanHeight = scanWidth / overlayAspectRatio;

    final scanRect = scanWindow ?? Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: scanWidth,
      height: scanHeight,
    );

    // Draw darkened background with a hole
    // Top
    canvas.drawRect(Rect.fromLTRB(0, 0, width, scanRect.top), overlayPaint);
    // Bottom
    canvas.drawRect(Rect.fromLTRB(0, scanRect.bottom, width, height), overlayPaint);
    // Left
    canvas.drawRect(Rect.fromLTRB(0, scanRect.top, scanRect.left, scanRect.bottom), overlayPaint);
    // Right
    canvas.drawRect(Rect.fromLTRB(scanRect.right, scanRect.top, width, scanRect.bottom), overlayPaint);

    // Draw Corner Borders
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final cornerSize = 30.0;
    
    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.top + cornerSize)
        ..lineTo(scanRect.left, scanRect.top)
        ..lineTo(scanRect.left + cornerSize, scanRect.top),
      borderPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerSize, scanRect.top)
        ..lineTo(scanRect.right, scanRect.top)
        ..lineTo(scanRect.right, scanRect.top + cornerSize),
      borderPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.bottom - cornerSize)
        ..lineTo(scanRect.left, scanRect.bottom)
        ..lineTo(scanRect.left + cornerSize, scanRect.bottom),
      borderPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerSize, scanRect.bottom)
        ..lineTo(scanRect.right, scanRect.bottom)
        ..lineTo(scanRect.right, scanRect.bottom - cornerSize),
      borderPaint,
    );

    // Draw Laser Line
    final laserPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        colors: [
          Colors.redAccent.withValues(alpha: 0.0),
          Colors.redAccent,
          Colors.redAccent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(scanRect);

    final double laserY = scanRect.top + (scanRect.height * value);
    canvas.drawLine(
      Offset(scanRect.left + 10, laserY),
      Offset(scanRect.right - 10, laserY),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.scanWindow != scanWindow;
  }
}
