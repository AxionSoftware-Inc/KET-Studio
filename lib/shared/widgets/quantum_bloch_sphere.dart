import 'package:fluent_ui/fluent_ui.dart';
import 'dart:math' as math;
import '../../core/theme/ket_theme.dart';

class InteractiveBlochSphere extends StatefulWidget {
  final double theta;
  final double phi;
  final double size;
  final int? index;

  const InteractiveBlochSphere({
    super.key,
    required this.theta,
    required this.phi,
    this.size = 120,
    this.index,
  });

  @override
  State<InteractiveBlochSphere> createState() => _InteractiveBlochSphereState();
}

class _InteractiveBlochSphereState extends State<InteractiveBlochSphere> {
  double _rotX = -0.4;
  double _rotY = 0.5;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _rotY += details.delta.dx * 0.01;
          _rotX -= details.delta.dy * 0.01;
        });
      },
      child: RepaintBoundary(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.02),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: CustomPaint(
            painter: BlochPainter(
              theta: widget.theta,
              phi: widget.phi,
              rotX: _rotX,
              rotY: _rotY,
              color: KetTheme.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class BlochPainter extends CustomPainter {
  final double theta;
  final double phi;
  final double rotX;
  final double rotY;
  final Color color;

  BlochPainter({
    required this.theta,
    required this.phi,
    required this.rotX,
    required this.rotY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    final paintMain = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final paintDashed = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 1. Project 3D axes
    void drawAxis(double x, double y, double z) {
      final p = _project(x * radius, y * radius, z * radius);
      canvas.drawLine(center, center + p, paintDashed);
    }

    drawAxis(1, 0, 0); // x
    drawAxis(0, 1, 0); // y
    drawAxis(0, 0, 1); // z

    // Outer circle
    canvas.drawCircle(center, radius, paintDashed); 
    
    // Equatorial circle (XY plane)
    final tilt = math.cos(rotX).abs();
    final rect = Rect.fromCenter(center: center, width: radius * 2, height: radius * 0.5 * tilt);
    canvas.drawOval(rect, paintDashed);

    // 2. State Vector
    final qX = math.sin(theta) * math.cos(phi);
    final qY = math.sin(theta) * math.sin(phi);
    final qZ = math.cos(theta);

    final vecPos = _project(qX * radius, qY * radius, qZ * radius);
    
    // Vector line
    canvas.drawLine(center, center + vecPos, paintMain);
    
    // Vector head
    canvas.drawCircle(center + vecPos, 5, paintMain..style = PaintingStyle.fill);
    
    // Glow
    canvas.drawCircle(
      center + vecPos, 
      8, 
      Paint()..color = color.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
    );
  }

  Offset _project(double x, double y, double z) {
    double y1 = y * math.cos(rotX) - z * math.sin(rotX);
    double z1 = y * math.sin(rotX) + z * math.cos(rotX);
    double x2 = x * math.cos(rotY) + z1 * math.sin(rotY);
    return Offset(x2, y1);
  }

  @override
  bool shouldRepaint(covariant BlochPainter oldDelegate) => 
    oldDelegate.rotX != rotX || oldDelegate.rotY != rotY || oldDelegate.theta != theta || oldDelegate.phi != phi;
}
