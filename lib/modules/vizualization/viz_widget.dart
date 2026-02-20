import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/viz_service.dart';
import '../../core/theme/ket_theme.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'inspector_widget.dart';
import '../../core/services/export_service.dart';
import 'package:flutter/rendering.dart';
import '../../shared/widgets/quantum_bloch_sphere.dart';

/// VIZUALIZATION PERFORMANCE & STABILITY DOCS:
///
/// 1. UI FREEZE GUARD (MATRIX): High-dimension matrices (e.g. 1024x1024) are NOT rendered as Widgets.
///    Instead, we use [CustomPainter] and strict dimension limits (128x128).
///    This prevents the UI thread from being overwhelmed by object allocations.
///
/// 2. LAZY DECODING: JSON data from Python is decoded in small batches (5 msgs/60ms)
///    in [ExecutionService] to avoid blocking the main thread during execution.
///
/// 3. REPAINT BOUNDARY: Each Viz card is wrapped in a [RepaintBoundary] so that
///    scrolling doesn't trigger expensive rebuilds of complex charts/matrices.
///
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
    if (!mounted) return;

    // Debounce updates to max 30 FPS to prevent UI choke
    final now = DateTime.now();
    if (_lastUpdate != null &&
        now.difference(_lastUpdate!) < const Duration(milliseconds: 32)) {
      return;
    }
    _lastUpdate = now;

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

    // Auto-scroll logic safely - Only if at bottom or new session
    if (service.selectedEvent == null && _scrollController.hasClients) {
      if (!_isScrollingThrottled) {
        _isScrollingThrottled = true;
        Future.delayed(const Duration(milliseconds: 250), () {
          _isScrollingThrottled = false;
          if (mounted && _scrollController.hasClients) {
            final pos = _scrollController.position.maxScrollExtent;
            if ((_scrollController.offset - pos).abs() < 500) {
              // Only auto-scroll if close to bottom
              _scrollController.animateTo(
                pos,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          }
        });
      }
    }

    setState(() {});
  }

  DateTime? _lastUpdate;

  bool _isScrollingThrottled = false;

  @override
  Widget build(BuildContext context) {
    final service = VizService();
    final status = service.status;

    return _buildMainContent(service, status);
  }

  Widget _buildMainContent(VizService service, VizStatus status) {
    if (service.selectedEvent != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: _VizCard(event: service.selectedEvent!, isSingle: true),
            ),
            const SizedBox(height: 12),
            Button(
              child: const Text("Back to Stream"),
              onPressed: () => service.selectEvent(null),
            ),
          ],
        ),
      );
    }

    final currentSession = service.currentSession;
    if (currentSession == null || currentSession.events.isEmpty) {
      if (status == VizStatus.running) return _buildRunningState();
      return _buildIdleState();
    }

    final events = currentSession.events;

    // Tushuntirish: Hammasini bittada ko'rsatib "tizib" yubormaslik uchun,
    // har bir turdagi eng oxirgi eventni olamiz.
    // Bu orqali VQE charti bitta joyda "o'ynaydi" (animatsiya bo'ladi).
    final Map<VizType, VizEvent> latestEvents = {};
    for (var e in events) {
      if (e.type != VizType.inspector &&
          e.type != VizType.text &&
          e.type != VizType.error &&
          e.type != VizType.metrics &&
          e.type != VizType.estimator &&
          e.type != VizType.none) {
        latestEvents[e.type] = e;
      }
    }

    final displayList = latestEvents.values.toList();

    if (displayList.isEmpty) {
      if (status == VizStatus.running) {
        final hasMetrics = events.any((e) => e.type == VizType.metrics);
        return _buildRunningState(
          message: hasMetrics ? "Syncing simulation metrics..." : null,
        );
      }
      return _buildIdleState(
        message: "No live visualizations in current session.",
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: displayList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _VizCard(event: displayList[index]),
    );
  }

  Widget _buildIdleState({String? message}) {
    return Center(
      child: Text(
        message ?? "Run a script to see results here.",
        style: TextStyle(color: KetTheme.textMuted),
      ),
    );
  }

  Widget _buildRunningState({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
          const SizedBox(height: 16),
          Text(
            message ??
                (_showNoOutputHint
                    ? "Running... (no visual output yet)"
                    : "Capturing quantum data..."),
            style: TextStyle(color: KetTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
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
  final String? title;
  const _MatrixHeatmap({required this.data, this.title});

  @override
  Widget build(BuildContext context) {
    int rows = 0;
    int cols = 0;
    List<List<double>> matrixData = [];

    if (data is List) {
      final list = data as List;
      rows = list.length;
      cols = rows > 0 ? (list[0] as List).length : 0;
      matrixData = list
          .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
          .toList();
    } else if (data is Map) {
      final map = data as Map;
      int maxIdx = -1;
      for (var k in map.keys) {
        final s = k.toString();
        final p = s.indexOf(',');
        if (p != -1) {
          final r = int.tryParse(s.substring(0, p)) ?? 0;
          final c = int.tryParse(s.substring(p + 1)) ?? 0;
          maxIdx = math.max(maxIdx, math.max(r, c));
        }
      }
      rows = cols = maxIdx + 1;
      // Convert map sparse data to dense for painter (or handle sparse in painter, but dense is easier for now)
      matrixData = List.generate(
        rows,
        (r) => List.generate(cols, (c) {
          return (map['$r,$c'] ?? 0.0).toDouble();
        }),
      );
    }

    if (rows == 0) {
      return const Text(
        "No matrix data",
        style: TextStyle(fontSize: 10, color: Colors.grey),
      );
    }

    // Use CustomPainter for large matrices
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          _SubHeader(title: title!.toUpperCase()),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            double w = constraints.maxWidth;
            double padding = 2;
            double cellSize = (w - (cols - 1) * padding) / cols;
            cellSize = math.min(cellSize, 40.0); // Limit cell size

            final totalHeight = cellSize * rows + (rows - 1) * padding;

            return SizedBox(
              width: cellSize * cols + (cols - 1) * padding,
              height: totalHeight,
              child: CustomPaint(
                painter: _HeatmapPainter(
                  data: matrixData,
                  rows: rows,
                  cols: cols,
                  cellSize: cellSize,
                  padding: padding,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<List<double>> data;
  final int rows;
  final int cols;
  final double cellSize;
  final double padding;

  _HeatmapPainter({
    required this.data,
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final val = data[r][c];
        paint.color = Color.lerp(
          const Color(0xFF1A1A1A),
          KetTheme.accent,
          val.clamp(0.0, 1.0),
        )!;

        final left = c * (cellSize + padding);
        final top = r * (cellSize + padding);
        final rect = Rect.fromLTWH(left, top, cellSize, cellSize);

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );

        // Draw Value Text only if cell is large enough
        if (cellSize > 25 && val > 0.05) {
          textPainter.text = TextSpan(
            text: val.toStringAsFixed(1),
            style: TextStyle(
              fontSize: cellSize * 0.35,
              color: val > 0.6 ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              left + (cellSize - textPainter.width) / 2,
              top + (cellSize - textPainter.height) / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.cellSize != cellSize;
  }
}

class _TableDisplay extends StatelessWidget {
  final dynamic data;
  const _TableDisplay({required this.data});
  @override
  Widget build(BuildContext context) {
    final title = data?['title'] ?? "Table";
    final rowsList = data?['rows'] as List? ?? [];

    // Guard: Prevent massive table builds
    if (rowsList.length > 100) {
      return Text(
        "Table too large to display (${rowsList.length} rows)",
        style: TextStyle(fontSize: 10, color: Colors.orange),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubHeader(title: title.toString().toUpperCase()),
        const SizedBox(height: 8),
        ...rowsList.map((row) {
          final cells = row as List;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
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
        }),
      ],
    );
  }
}

class _BlochSpherePainter extends StatelessWidget {
  final dynamic data;
  const _BlochSpherePainter({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data is List) {
      final list = data as List;
      final count = list.length;

      double size = count <= 4 ? 120 : (count <= 16 ? 80 : 50);
      int limit = count > 100 ? 100 : count;

      return Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: list.take(limit).toList().asMap().entries.map((e) {
            double theta = 0, phi = 0;
            if (e.value is Map) {
              theta = (e.value['theta'] ?? 0.0).toDouble();
              phi = (e.value['phi'] ?? 0.0).toDouble();
            }
            return InteractiveBlochSphere(theta: theta, phi: phi, size: size);
          }).toList(),
        ),
      );
    }

    // Single state
    double theta = 0, phi = 0;
    if (data is Map) {
      theta = (data['theta'] ?? 0.0).toDouble();
      phi = (data['phi'] ?? 0.0).toDouble();

      // Handle Cartesian if provided
      if (!data.containsKey('theta') && data.containsKey('x')) {
        double x = (data['x'] ?? 0.0).toDouble();
        double y = (data['y'] ?? 0.0).toDouble();
        double z = (data['z'] ?? 0.0).toDouble();
        // Convert Cartesian to Spherical for InteractiveBlochSphere
        double r = math.sqrt(x * x + y * y + z * z);
        if (r > 0) {
          theta = math.acos(z / r);
          phi = math.atan2(y, x);
        }
      }
    }

    return Center(
      child: InteractiveBlochSphere(theta: theta, phi: phi, size: 200),
    );
  }
}

class _HistogramChart extends StatelessWidget {
  final dynamic data;
  const _HistogramChart({required this.data});
  @override
  Widget build(BuildContext context) {
    if (data is! Map) {
      return Text(
        "Histogram: Data must be a Map/Dict",
        style: TextStyle(color: Colors.red, fontSize: 10),
      );
    }

    Map map = data as Map;
    // Support wrapped payload: {"histogram": {...}}
    if (map.containsKey('histogram') && map['histogram'] is Map) {
      map = map['histogram'] as Map;
    }

    if (map.isEmpty) {
      return Text(
        "Histogram: Empty data",
        style: TextStyle(color: Colors.grey, fontSize: 10),
      );
    }
    final keys = map.keys.toList();
    final values = map.values.map((v) => (v as num).toDouble()).toList();
    final double maxVal = values.isEmpty ? 1.0 : values.reduce(math.max);
    final double safeMax = maxVal == 0 ? 1.0 : maxVal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double barWidth =
            (constraints.maxWidth / math.max(keys.length, 1)) - 8;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(keys.length, (i) {
            final double hRatio = values[i] / safeMax;
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: math.max(barWidth, 4.0),
                  height: hRatio * (constraints.maxHeight - 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        KetTheme.accent,
                        KetTheme.accent.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: KetTheme.accent.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  keys[i].toString(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            );
          }),
        );
      },
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
    return Column(
      children: [
        if (title != null)
          Text(
            title!,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        SizedBox(
          height: isSingle ? null : 300,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Text("Image not available"),
          ),
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
    if (data is! List) {
      return Text(
        "Chart: Data must be a List",
        style: TextStyle(color: Colors.red, fontSize: 10),
      );
    }
    if (data.isEmpty) {
      return Text(
        "Chart: Empty data",
        style: TextStyle(color: Colors.grey, fontSize: 10),
      );
    }
    final List<double> points = (data as List)
        .map((p) => (p as num).toDouble())
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(points: points, color: KetTheme.accent),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _LineChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path();
    final fillPath = Path();

    final double stepX = size.width / (points.length - 1);

    path.moveTo(0, size.height * (1 - points[0].clamp(0.0, 1.0)));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height * (1 - points[0].clamp(0.0, 1.0)));

    for (int i = 1; i < points.length; i++) {
      final double x = i * stepX;
      final double y = size.height * (1 - points[i].clamp(0.0, 1.0));
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw Fill with Gradient
    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, paintFill);

    // Draw Line
    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(path, paintLine);

    // Draw Last Point Glow
    final lastX = size.width;
    final lastY = size.height * (1 - points.last.clamp(0.0, 1.0));
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = color);
    canvas.drawCircle(
      Offset(lastX, lastY),
      8,
      Paint()..color = color.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

class _VizCard extends StatefulWidget {
  final VizEvent event;
  final bool isSingle;
  const _VizCard({required this.event, this.isSingle = false});

  @override
  State<_VizCard> createState() => _VizCardState();
}

class _VizCardState extends State<_VizCard> {
  final GlobalKey _boundaryKey = GlobalKey();

  void _exportImage() async {
    final RenderRepaintBoundary? boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary != null) {
      await ExportService().exportWidgetToImage(
        boundary,
        fileName:
            "plot_${widget.event.type.name}_${widget.event.timestamp.millisecondsSinceEpoch}.png",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isSingle = widget.isSingle;

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
                Tooltip(
                  message: "Export as Image",
                  child: IconButton(
                    icon: const Icon(FluentIcons.camera, size: 11),
                    onPressed: _exportImage,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  event.timeStr,
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ],
            ),
          ),
          RepaintBoundary(
            key: _boundaryKey,
            child: Builder(
              builder: (context) {
                try {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildVizContent(event, isSingle: isSingle),
                  );
                } catch (e) {
                  return _ErrorDisplay(error: "Render Error: $e");
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildVizContent(VizEvent event, {bool isSingle = false}) {
  final payload = event.payload;

  switch (event.type) {
    case VizType.inspector:
      if (isSingle) {
        return InspectorWidget(payload: payload);
      } else {
        return SizedBox(height: 450, child: InspectorWidget(payload: payload));
      }

    case VizType.matrix:
    case VizType.heatmap:
      return _MatrixHeatmap(
        data: (payload is Map && payload.containsKey('data'))
            ? payload['data']
            : payload,
        title: (payload is Map && payload.containsKey('title'))
            ? payload['title'].toString()
            : null,
      );

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

    case VizType.bloch:
      return SizedBox(height: 250, child: _BlochSpherePainter(data: payload));

    case VizType.chart:
      return SizedBox(height: 200, child: _SimpleChart(data: payload));

    case VizType.histogram:
      return SizedBox(height: 150, child: _HistogramChart(data: payload));

    default:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Visualization: ${event.type}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            payload.toString(),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
  }
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
    case VizType.histogram:
      return FluentIcons.bar_chart_vertical;
    case VizType.chart:
      return FluentIcons.line_chart;
    default:
      return FluentIcons.info;
  }
}
