import 'package:fluent_ui/fluent_ui.dart';
import '../../core/theme/ket_theme.dart';
import 'dart:math' as math;

class InspectorWidget extends StatefulWidget {
  final dynamic payload;
  const InspectorWidget({super.key, required this.payload});

  @override
  State<InspectorWidget> createState() => _InspectorWidgetState();
}

class _InspectorWidgetState extends State<InspectorWidget> {
  int _currentFrame = 0;

  @override
  Widget build(BuildContext context) {
    final frames = widget.payload['frames'] as List<dynamic>? ?? [];
    if (frames.isEmpty) return const Center(child: Text("No inspector data"));

    final frame = frames[_currentFrame];
    final title = widget.payload['title'] ?? "Circuit Inspector";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: KetTheme.bgHeader,
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.reading_mode, size: 16, color: KetTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: KetTheme.headerStyle.copyWith(letterSpacing: 1.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: KetTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${_currentFrame + 1}/${frames.length}",
                  style: TextStyle(
                    color: KetTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.cube_shape,
                            size: 14,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            frame['gate'] ?? "Operation",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        frame['state_description'] ??
                            "No description provided for this step.",
                        style: TextStyle(
                          color: KetTheme.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  "STATE VISUALIZATION",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: KetTheme.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Qubit States
                Center(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: (frame['bloch'] as List<dynamic>? ?? [])
                        .asMap()
                        .entries
                        .map((entry) {
                          return _buildBlochSphere(entry.key, entry.value);
                        })
                        .toList(),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: KetTheme.bgHeader,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(FluentIcons.chevron_left_med, size: 14),
                onPressed: _currentFrame > 0
                    ? () => setState(() => _currentFrame--)
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Slider(
                    value: _currentFrame.toDouble(),
                    min: 0,
                    max: math.max(0, frames.length - 1).toDouble(),
                    onChanged: (v) => setState(() => _currentFrame = v.toInt()),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.chevron_right_med, size: 14),
                onPressed: _currentFrame < frames.length - 1
                    ? () => setState(() => _currentFrame++)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlochSphere(int index, dynamic data) {
    final theta = data['theta']?.toDouble() ?? 0.0;
    final phi = data['phi']?.toDouble() ?? 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "q[$index]",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: KetTheme.textMuted.withValues(alpha: 0.3),
            ),
            gradient: RadialGradient(
              colors: [
                KetTheme.accent.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: CustomPaint(
            painter: BlochPainter(theta, phi, KetTheme.accent),
          ),
        ),
      ],
    );
  }
}

class BlochPainter extends CustomPainter {
  final double theta;
  final double phi;
  final Color color;

  BlochPainter(this.theta, this.phi, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw Axes (Dash effect)
    final axisPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      axisPaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      axisPaint,
    );

    // Calculate projection (Simple 2D projection for a 3D sphere)
    // theta: 0 to pi (Z axis), phi: 0 to 2pi (XY plane)
    final z = math.cos(theta);
    final x = math.sin(theta) * math.cos(phi);
    // ignore: unused_local_variable
    final y = math.sin(theta) * math.sin(phi);

    // Vector point on 2D
    final vectorX = center.dx + (x * radius);
    final vectorY = center.dy - (z * radius); // Negative because UI Y is down

    canvas.drawLine(center, Offset(vectorX, vectorY), paint);
    canvas.drawCircle(
      Offset(vectorX, vectorY),
      4,
      paint..style = PaintingStyle.fill,
    );

    // Draw "ghost" indicator for Y/Depth if needed
    canvas.drawCircle(center, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
