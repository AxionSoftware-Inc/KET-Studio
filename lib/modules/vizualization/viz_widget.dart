import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/viz_service.dart';
import '../../core/theme/ket_theme.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:async';

class VizualizationWidget extends StatefulWidget {
  const VizualizationWidget({super.key});

  @override
  State<VizualizationWidget> createState() => _VizualizationWidgetState();
}

class _VizualizationWidgetState extends State<VizualizationWidget> {
  DateTime? _runStartTime;
  bool _showNoOutputHint = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    VizService().addListener(_refresh);
  }

  @override
  void dispose() {
    VizService().removeListener(_refresh);
    _hintTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final service = VizService();
    if (service.status == VizStatus.running) {
      if (_runStartTime == null) {
        _runStartTime = DateTime.now();
        _showNoOutputHint = false;
        _hintTimer?.cancel();
        _hintTimer = Timer(const Duration(seconds: 3), () {
          if (mounted &&
              VizService().status == VizStatus.running &&
              VizService().selectedEvent == null) {
            setState(() => _showNoOutputHint = true);
          }
        });
      }
    } else {
      _runStartTime = null;
      _showNoOutputHint = false;
      _hintTimer?.cancel();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = VizService();
    final status = service.status;
    final event = service.selectedEvent;

    return Column(
      children: [
        _buildHeader(service),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildMainContent(status, event, service),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(
    VizStatus status,
    VizEvent? event,
    VizService service,
  ) {
    if (event != null) {
      return _buildVizContent(event);
    }

    switch (status) {
      case VizStatus.idle:
        return _buildIdleState();
      case VizStatus.running:
        return _buildRunningState();
      case VizStatus.error:
        return _buildErrorState(
          service.currentSession?.errorMessage ?? "Unknown error",
        );
      case VizStatus.stopped:
        return _buildIdleState(message: "Process Stopped.");
      default:
        return _buildIdleState();
    }
  }

  Widget _buildIdleState({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.waitlist_confirm,
            size: 40,
            color: KetTheme.textMuted.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message ?? "No output yet. Run a script to see results.",
            style: TextStyle(color: KetTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProgressRing(),
          const SizedBox(height: 20),
          const Text(
            "Running quantum script...",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _showNoOutputHint
                ? "Running... (no visual output yet). Show logs in terminal if needed."
                : "Visualizing data as it arrives via ket_viz protocol.",
            style: TextStyle(color: KetTheme.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return _ErrorDisplay(error: error);
  }

  Widget _buildHeader(VizService service) {
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: KetTheme.bgHeader,
      child: Row(
        children: [
          if (service.selectedEvent != null) ...[
            Icon(
              _getIconForType(service.selectedEvent!.type),
              size: 14,
              color: KetTheme.accent,
            ),
            const SizedBox(width: 8),
            Text(
              service.selectedEvent!.type
                  .toString()
                  .split('.')
                  .last
                  .toUpperCase(),
              style: KetTheme.headerStyle,
            ),
          ] else if (service.status == VizStatus.running) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: ProgressRing(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              "EXECUTING...",
              style: KetTheme.headerStyle.copyWith(color: KetTheme.accent),
            ),
          ] else ...[
            const Icon(
              FluentIcons.view_dashboard,
              size: 14,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            Text("QUANTUM VIZ", style: KetTheme.headerStyle),
          ],
          const Spacer(),
          if (service.sessions.isNotEmpty)
            IconButton(
              icon: const Icon(FluentIcons.delete, size: 12),
              onPressed: () => service.clear(),
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
      case VizType.dashboard:
        return FluentIcons.iot;
      case VizType.image:
      case VizType.circuit:
        return FluentIcons.picture;
      case VizType.table:
        return FluentIcons.table_group;
      case VizType.text:
        return FluentIcons.text_document;
      case VizType.heatmap:
        return FluentIcons.iot;
      case VizType.error:
        return FluentIcons.error;
      default:
        return FluentIcons.info;
    }
  }

  Widget _buildVizContent(VizEvent event) {
    final payload = event.payload;
    switch (event.type) {
      case VizType.bloch:
        return _BlochSpherePainter(data: payload);
      case VizType.matrix:
      case VizType.heatmap:
        final actualData = (payload is Map && payload.containsKey('data'))
            ? payload['data']
            : payload;
        final title = (payload is Map && payload.containsKey('title'))
            ? payload['title']
            : null;
        return Column(
          children: [
            if (title != null)
              _SubHeader(title: title.toString().toUpperCase()),
            Expanded(child: _MatrixHeatmap(data: actualData)),
          ],
        );
      case VizType.chart:
        return _SimpleChart(data: payload);
      case VizType.dashboard:
        return _QuantumDashboard(data: payload);
      case VizType.image:
      case VizType.circuit:
        return _ImageDisplay(
          path: payload is Map
              ? (payload['path'] ?? "").toString()
              : payload.toString(),
          title: payload is Map ? (payload['title'] ?? "").toString() : null,
        );
      case VizType.table:
        return _TableDisplay(data: payload);
      case VizType.text:
        return _TextDisplay(data: payload);
      case VizType.error:
        return _ErrorDisplay(error: payload.toString());
      default:
        return const Text("Unknown Visualization");
    }
  }
}

class _ErrorDisplay extends StatelessWidget {
  final String error;
  const _ErrorDisplay({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D0000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF0000), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.error, color: Color(0xFFFF4444), size: 18),
              const SizedBox(width: 8),
              Text(
                "PYTHON TERMINATED WITH ERROR",
                style: TextStyle(
                  color: const Color(0xFFFF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                error,
                style: const TextStyle(
                  color: Color(0xFFFF9999),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(FluentIcons.info, size: 10, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                "Check Terminal for full stack trace. Press F5 to retry.",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableDisplay extends StatelessWidget {
  final dynamic data;
  const _TableDisplay({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data?['title'] ?? "Data Table";
    final rows = data?['rows'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubHeader(title: title.toString().toUpperCase()),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index] as List;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: row
                      .map(
                        (cell) => Text(
                          cell.toString(),
                          style: const TextStyle(
                            color: KetTheme.textMain,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TextDisplay extends StatelessWidget {
  final dynamic data;
  const _TextDisplay({required this.data});

  @override
  Widget build(BuildContext context) {
    final text = data?['content'] ?? data?['text'] ?? data.toString();
    return SingleChildScrollView(
      child: Text(
        text.toString(),
        style: const TextStyle(
          color: KetTheme.textMain,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _ImageDisplay extends StatelessWidget {
  final String path;
  final String? title;
  const _ImageDisplay({required this.path, this.title});

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
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              title!,
              style: const TextStyle(
                color: KetTheme.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        Expanded(
          child: InteractiveViewer(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              key: ValueKey(
                path +
                    (file.existsSync()
                        ? file.lastModifiedSync().toString()
                        : ""),
              ),
            ),
          ),
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
          crossAxisCount: cols > 1 ? cols : 2,
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
          maxIdx = math.max(maxIdx, math.min(15, int.parse(parts[0])));
          maxIdx = math.max(maxIdx, math.min(15, int.parse(parts[1])));
        }
      }
      int size = maxIdx + 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: size > 1 ? size : 2,
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
      children: points
          .map(
            (p) => Expanded(
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
            ),
          )
          .toList(),
    );
  }
}
