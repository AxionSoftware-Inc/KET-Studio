import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/viz_service.dart';
import '../../core/theme/ket_theme.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'inspector_widget.dart';

class VizualizationWidget extends StatefulWidget {
  const VizualizationWidget({super.key});

  @override
  State<VizualizationWidget> createState() => _VizualizationWidgetState();
}

class _VizualizationWidgetState extends State<VizualizationWidget> {
  DateTime? _runStartTime;
  bool _showNoOutputHint = false;
  Timer? _hintTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    VizService().addListener(_refresh);
  }

  @override
  void dispose() {
    VizService().removeListener(_refresh);
    _hintTimer?.cancel();
    _scrollController.dispose();
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

    // Auto-scroll logic safely
    if (service.selectedEvent == null && _scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
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
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVizCard(event, isSingle: true),
            const SizedBox(height: 12),
            Button(
              child: const Text("View Full Session Stream"),
              onPressed: () => service.selectEvent(null),
            ),
          ],
        ),
      );
    }

    final currentSession = service.currentSession;
    if (currentSession != null && currentSession.events.isNotEmpty) {
      return ListView.separated(
        controller: _scrollController,
        itemCount: currentSession.events.length,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          return _buildVizCard(currentSession.events[index]);
        },
      );
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
        return _buildIdleState(message: "Process Finished.");
      default:
        return _buildIdleState();
    }
  }

  Widget _buildVizCard(VizEvent event, {bool isSingle = false}) {
    return Container(
      decoration: BoxDecoration(
        color: KetTheme.bgHeader.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getIconForType(event.type),
                  size: 12,
                  color: KetTheme.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  event.type.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                  event.timeStr,
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildVizContent(event, isSingle: isSingle),
          ),
        ],
      ),
    );
  }

  Widget _buildVizContent(VizEvent event, {bool isSingle = false}) {
    final payload = event.payload;
    switch (event.type) {
      case VizType.bloch:
        return SizedBox(height: 250, child: _BlochSpherePainter(data: payload));
      case VizType.matrix:
      case VizType.heatmap:
        final actualData = (payload is Map && payload.containsKey('data'))
            ? payload['data']
            : payload;
        final title = (payload is Map && payload.containsKey('title'))
            ? payload['title']
            : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              _SubHeader(title: title.toString().toUpperCase()),
            const SizedBox(height: 8),
            _MatrixHeatmap(data: actualData),
          ],
        );
      case VizType.chart:
        return SizedBox(height: 200, child: _SimpleChart(data: payload));
      case VizType.dashboard:
        return _QuantumDashboard(data: payload);
      case VizType.image:
      case VizType.circuit:
        return _ImageDisplay(
          path: payload is Map
              ? (payload['path'] ?? "").toString()
              : payload.toString(),
          title: payload is Map ? (payload['title'] ?? "").toString() : null,
          isSingle: isSingle,
        );
      case VizType.table:
        return _TableDisplay(data: payload);
      case VizType.text:
        return _TextDisplay(data: payload);
      case VizType.error:
        return _ErrorDisplay(error: payload.toString());
      case VizType.inspector:
        return InspectorWidget(payload: payload);
      default:
        return const Text("Unknown Visualization");
    }
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
            Text("DETAILED VIEW", style: KetTheme.headerStyle),
            IconButton(
              icon: const Icon(FluentIcons.back, size: 12),
              onPressed: () => service.selectEvent(null),
            ),
          ] else if (service.status == VizStatus.running) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: ProgressRing(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              "STREAMING DATA...",
              style: KetTheme.headerStyle.copyWith(color: KetTheme.accent),
            ),
          ] else ...[
            const Icon(
              FluentIcons.view_dashboard,
              size: 14,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            Text("SESSION OUTPUT", style: KetTheme.headerStyle),
          ],
          const Spacer(),
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
      case VizType.dashboard:
        return FluentIcons.iot;
      case VizType.matrix:
        return FluentIcons.table_group;
      case VizType.table:
        return FluentIcons.list;
      case VizType.inspector:
        return FluentIcons.processing_run;
      default:
        return FluentIcons.info;
    }
  }

  Widget _buildIdleState({String? message}) {
    return Center(
      child: Text(
        message ?? "Run a script to see results here.",
        style: TextStyle(color: KetTheme.textMuted),
      ),
    );
  }

  Widget _buildRunningState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
          const SizedBox(height: 16),
          Text(
            _showNoOutputHint
                ? "Running... (no visual output yet)"
                : "Capturing quantum data...",
            style: TextStyle(color: KetTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return _ErrorDisplay(error: error);
  }
}

class _QuantumDashboard extends StatelessWidget {
  final dynamic data;
  const _QuantumDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final hist = data?['histogram'];
    final matrix = data?['matrix'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hist != null) ...[
          const _SubHeader(title: "HISTOGRAM"),
          const SizedBox(height: 8),
          SizedBox(height: 120, child: _HistogramChart(data: hist)),
          const SizedBox(height: 12),
        ],
        if (matrix != null) ...[
          const _SubHeader(title: "DENSITY MATRIX"),
          const SizedBox(height: 8),
          _MatrixHeatmap(data: matrix),
        ],
      ],
    );
  }
}

class _MatrixHeatmap extends StatelessWidget {
  final dynamic data;
  const _MatrixHeatmap({required this.data});

  @override
  Widget build(BuildContext context) {
    int rows = 0;
    int cols = 0;
    List<List<double>> matrix = [];

    if (data is List) {
      rows = (data as List).length;
      cols = rows > 0 ? (data[0] as List).length : 0;
      matrix = (data as List)
          .map((r) => (r as List).map((c) => (c as num).toDouble()).toList())
          .toList();
    } else if (data is Map) {
      final map = data as Map;
      int maxIdx = 0;
      for (var k in map.keys) {
        final p = k.toString().split(',');
        if (p.length == 2) {
          maxIdx = math.max(maxIdx, math.max(int.parse(p[0]), int.parse(p[1])));
        }
      }
      rows = cols = maxIdx + 1;
    }

    if (rows == 0) return const Text("No matrix data");

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (r) {
        return Row(
          children: List.generate(cols, (c) {
            double val = 0;
            if (data is List) {
              val = matrix[r][c];
            } else {
              val = (data["$r,$c"] ?? 0.0).toDouble();
            }
            return Expanded(
              child: AspectRatio(aspectRatio: 1, child: _HeatBox(value: val)),
            );
          }),
        );
      }),
    );
  }
}

class _HeatBox extends StatelessWidget {
  final double value;
  const _HeatBox({required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFF1A1A1A),
          KetTheme.accent,
          value.clamp(0.0, 1.0),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Center(
        child: Text(
          value > 0.05 ? value.toStringAsFixed(1) : "",
          style: const TextStyle(fontSize: 7, color: Colors.white),
        ),
      ),
    );
  }
}

class _TableDisplay extends StatelessWidget {
  final dynamic data;
  const _TableDisplay({required this.data});
  @override
  Widget build(BuildContext context) {
    final title = data?['title'] ?? "Table";
    final rowsList = data?['rows'] as List? ?? [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubHeader(title: title.toString().toUpperCase()),
        const SizedBox(height: 8),
        Column(
          children: rowsList.map((row) {
            final cells = row as List;
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
                children: cells
                    .map(
                      (c) => Expanded(
                        child: Text(
                          c.toString(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }).toList(),
        ),
      ],
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
      if (data.containsKey('theta')) {
        double theta = (data['theta'] ?? 0.0).toDouble();
        double phi = (data['phi'] ?? 0.0).toDouble();
        x = math.sin(theta) * math.cos(phi);
        y = math.sin(theta) * math.sin(phi);
        z = math.cos(theta);
      } else {
        x = (data['x'] ?? 0.0).toDouble();
        y = (data['y'] ?? 0.0).toDouble();
        z = (data['z'] ?? 0.0).toDouble();
      }
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: BlochPainter(x: x, y: y, z: z),
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
    if (data is! Map) return const SizedBox();
    final map = data as Map;
    final keys = map.keys.toList();
    final values = map.values.map((v) => (v as num).toDouble()).toList();
    final maxVal = values.isEmpty ? 1.0 : values.reduce(math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(keys.length, (index) {
        final ratio = values[index] / (maxVal == 0 ? 1 : maxVal);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  values[index].toStringAsFixed(0),
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                ),
                Container(
                  height: ratio * 80,
                  decoration: BoxDecoration(
                    color: KetTheme.accent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  keys[index].toString(),
                  style: const TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
        );
      }),
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
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      color: KetTheme.accent.withValues(alpha: 0.1),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: KetTheme.accent,
        ),
      ),
    );
  }
}

class _ErrorDisplay extends StatelessWidget {
  final String error;
  const _ErrorDisplay({required this.error});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D0000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        error,
        style: const TextStyle(
          color: Color(0xFFFF9999),
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TextDisplay extends StatelessWidget {
  final dynamic data;
  const _TextDisplay({required this.data});
  @override
  Widget build(BuildContext context) {
    final t = data?['content'] ?? data.toString();
    return Text(
      t,
      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
    );
  }
}

class _ImageDisplay extends StatelessWidget {
  final String path;
  final String? title;
  final bool isSingle;
  const _ImageDisplay({required this.path, this.title, this.isSingle = false});
  @override
  Widget build(BuildContext context) {
    final f = File(path);
    if (!f.existsSync()) return const Text("Image not found");
    return Column(
      children: [
        if (title != null)
          Text(
            title!,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        SizedBox(
          height: isSingle ? null : 300,
          child: Image.file(f, fit: BoxFit.contain),
        ),
      ],
    );
  }
}

class _SimpleChart extends StatelessWidget {
  final dynamic data;
  const _SimpleChart({required this.data});
  @override
  Widget build(BuildContext context) {
    if (data is! List) return const SizedBox();
    List<double> pts = (data as List)
        .map((e) => (e as num).toDouble())
        .toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: pts
          .map(
            (p) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: (p * 180).clamp(5.0, 180.0),
                color: KetTheme.accent,
              ),
            ),
          )
          .toList(),
    );
  }
}

class BlochPainter extends CustomPainter {
  final double x, y, z;
  BlochPainter({required this.x, required this.y, required this.z});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(c.dx - r, c.dy),
      Offset(c.dx + r, c.dy),
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    canvas.drawLine(
      Offset(c.dx, c.dy - r),
      Offset(c.dx, c.dy + r),
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    canvas.drawLine(
      c,
      Offset(c.dx + x * r * 0.8, c.dy - z * r * 0.8),
      Paint()
        ..color = KetTheme.accent
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(c.dx + x * r * 0.8, c.dy - z * r * 0.8),
      3,
      Paint()..color = KetTheme.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
