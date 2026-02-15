import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/viz_service.dart';
import '../../core/theme/ket_theme.dart';
import 'dart:math' as math;
import 'dart:io';

class VizualizationWidget extends StatefulWidget {
  const VizualizationWidget({super.key});

  @override
  State<VizualizationWidget> createState() => _VizualizationWidgetState();
}

class _VizualizationWidgetState extends State<VizualizationWidget> {
  @override
  void initState() {
    super.initState();
    VizService().addListener(_refresh);
  }

  @override
  void dispose() {
    VizService().removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final viz = VizService().currentData;

    if (viz == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildHeader(viz),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildVizContent(viz),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.waitlist_confirm,
            size: 48,
            color: KetTheme.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            "Waiting for Quantum Data...",
            style: TextStyle(color: KetTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "IDE Qiskit natijalarini (IMAGE, BLOCH, __DATA__) avtomatik aniqlaydi.",
              textAlign: TextAlign.center,
              style: TextStyle(color: KetTheme.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(VizData viz) {
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: KetTheme.bgHeader,
      child: Row(
        children: [
          Icon(_getIconForType(viz.type), size: 14, color: KetTheme.accent),
          const SizedBox(width: 8),
          Text(
            viz.type.toString().split('.').last.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: KetTheme.textMain,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(FluentIcons.clear, size: 12),
            onPressed: () => VizService().clear(),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(VizType type) {
    switch (type) {
      case VizType.bloch:
        return FluentIcons.product;
      case VizType.matrix:
        return FluentIcons.table_group;
      case VizType.chart:
        return FluentIcons.line_chart;
      case VizType.quantum:
        return FluentIcons.iot;
      case VizType.image:
      case VizType.circuit:
        return FluentIcons.picture;
      default:
        return FluentIcons.info;
    }
  }

  Widget _buildVizContent(VizData viz) {
    switch (viz.type) {
      case VizType.bloch:
        return _BlochSpherePainter(data: viz.data);
      case VizType.matrix:
        return _MatrixHeatmap(data: viz.data);
      case VizType.chart:
        return _SimpleChart(data: viz.data);
      case VizType.quantum:
        return _QuantumDashboard(data: viz.data);
      case VizType.image:
      case VizType.circuit:
        return _ImageDisplay(path: viz.data.toString());
      default:
        return const Text("Unknown Visualization");
    }
  }
}

class _ImageDisplay extends StatelessWidget {
  final String path;
  const _ImageDisplay({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return Center(
        child: Text(
          "Image not found: $path",
          style: const TextStyle(color: Color(0xFFFF0000), fontSize: 10),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              // Cache-tagini o'chirib yangi rasmni ko'ramiz
              key: ValueKey(file.lastModifiedSync()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          path.split(Platform.pathSeparator).last,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ],
    );
  }
}

class _QuantumDashboard extends StatelessWidget {
  final dynamic data;
  const _QuantumDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final histogram = data?['histogram'];
    final matrix = data?['matrix'];

    return Column(
      children: [
        if (histogram != null) ...[
          const _SubHeader(title: "HISTOGRAM / PROBABILITIES"),
          const SizedBox(height: 8),
          Expanded(flex: 2, child: _HistogramChart(data: histogram)),
          const SizedBox(height: 16),
        ],
        if (matrix != null) ...[
          const _SubHeader(title: "QUANTUM STATE MATRIX"),
          const SizedBox(height: 8),
          Expanded(flex: 3, child: _MatrixHeatmap(data: matrix)),
        ],
      ],
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String title;
  const _SubHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: KetTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: KetTheme.accent,
        ),
      ),
    );
  }
}

class _HistogramChart extends StatelessWidget {
  final dynamic data;
  const _HistogramChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data is! Map) return const Text("Invalid Histogram Data");
    final map = data as Map;
    final keys = map.keys.toList();
    final values = map.values.map((v) => (v as num).toDouble()).toList();
    final maxVal = values.isNotEmpty ? values.reduce(math.max) : 1.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(keys.length, (index) {
        final val = values[index];
        final ratio = maxVal > 0 ? val / maxVal : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Tooltip(
              message: "${keys[index]}: $val",
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    val.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 7, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: ratio * 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          KetTheme.accent,
                          KetTheme.accent.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    keys[index].toString(),
                    style: const TextStyle(fontSize: 8, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MatrixHeatmap extends StatelessWidget {
  final dynamic data;
  const _MatrixHeatmap({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data is List) {
      List matrix = data;
      int rows = matrix.length;
      int cols = rows > 0 ? (matrix[0] as List).length : 0;

      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols > 0 ? cols : 1,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: rows * cols,
        itemBuilder: (context, index) {
          int r = index ~/ cols;
          int c = index % cols;
          double val = (matrix[r][c] ?? 0.0).toDouble();
          return _HeatBox(value: val);
        },
      );
    } else if (data is Map) {
      final map = data as Map;
      int maxIdx = 0;
      for (var k in map.keys) {
        final parts = k.toString().split(',');
        if (parts.length == 2) {
          maxIdx = math.max(maxIdx, int.parse(parts[0]));
          maxIdx = math.max(maxIdx, int.parse(parts[1]));
        }
      }
      int size = maxIdx + 1;

      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: size,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: size * size,
        itemBuilder: (context, index) {
          int r = index ~/ size;
          int c = index % size;
          double val = (map["$r,$c"] ?? 0.0).toDouble();
          return _HeatBox(value: val);
        },
      );
    }
    return const Text("Invalid Matrix Data");
  }
}

class _HeatBox extends StatelessWidget {
  final double value;
  const _HeatBox({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFF121212),
          KetTheme.accent,
          value.clamp(0.0, 1.0),
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          value > 0.1 ? value.toStringAsFixed(1) : "",
          style: const TextStyle(fontSize: 6, color: Colors.white),
        ),
      ),
    );
  }
}

class _BlochSpherePainter extends StatelessWidget {
  final dynamic data;
  const _BlochSpherePainter({required this.data});

  @override
  Widget build(BuildContext context) {
    double x = 0, y = 0, z = 0;

    if (data is Map) {
      if (data.containsKey('x')) {
        x = (data?['x'] ?? 0.0).toDouble();
        y = (data?['y'] ?? 0.0).toDouble();
        z = (data?['z'] ?? 0.0).toDouble();
      } else if (data.containsKey('theta')) {
        double theta = (data['theta'] ?? 0.0).toDouble();
        double phi = (data['phi'] ?? 0.0).toDouble();
        // Convert Spherical to Cartesian
        x = math.sin(theta) * math.cos(phi);
        y = math.sin(theta) * math.sin(phi);
        z = math.cos(theta);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double size =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.8;
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: BlochPainter(x: x, y: y, z: z),
            ),
          ),
        );
      },
    );
  }
}

class BlochPainter extends CustomPainter {
  final double x, y, z;
  BlochPainter({required this.x, required this.y, required this.z});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paintCircle = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final paintAxis = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawCircle(center, radius, paintCircle);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paintAxis,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paintAxis,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 0.4),
      paintAxis,
    );

    final vectorPaint = Paint()
      ..color = KetTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final vectorEnd = Offset(
      center.dx + x * radius * 0.8,
      center.dy - z * radius * 0.8,
    );

    canvas.drawLine(center, vectorEnd, vectorPaint);
    canvas.drawCircle(vectorEnd, 4, Paint()..color = KetTheme.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SimpleChart extends StatelessWidget {
  final dynamic data;
  const _SimpleChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data is! List) return const Text("Invalid Chart Data");
    List<double> points = (data as List)
        .map((e) => (e as num).toDouble())
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points.map((p) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: math.max(10, p * 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    KetTheme.accent,
                    KetTheme.accent.withValues(alpha: 0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
