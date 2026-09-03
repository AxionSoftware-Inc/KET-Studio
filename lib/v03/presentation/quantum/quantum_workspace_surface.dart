import 'package:flutter/material.dart' as material;

import '../../application/quantum/provider_registry.dart';
import '../../application/workbench_controller.dart';
import '../../core/quantum/circuit_diagram.dart';

final class QuantumWorkspaceSurface extends material.StatefulWidget {
  const QuantumWorkspaceSurface({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final WorkbenchController controller;
  final material.ValueChanged<CircuitEdit> onEdit;

  @override
  material.State<QuantumWorkspaceSurface> createState() => _QuantumWorkspaceSurfaceState();
}

final class _QuantumWorkspaceSurfaceState extends material.State<QuantumWorkspaceSurface> {
  int? _selectedOperation;

  @override
  material.Widget build(material.BuildContext context) {
    final diagram = widget.controller.circuitDiagram;
    if (diagram == null) {
      return const material.Center(
        child: material.Text(
          'Run an OpenQASM document to build the visual circuit workspace.',
          style: material.TextStyle(color: material.Color(0xFF81909F)),
        ),
      );
    }
    final selected = _findNode(diagram, _selectedOperation);
    final trace = widget.controller.transpilationTrace;
    final graph = widget.controller.workspaceGraph;
    return material.Container(
      color: const material.Color(0xFF0D1218),
      child: material.Column(
        crossAxisAlignment: material.CrossAxisAlignment.stretch,
        children: <material.Widget>[
          material.Container(
            height: 42,
            padding: const material.EdgeInsets.symmetric(horizontal: 12),
            decoration: const material.BoxDecoration(
              color: material.Color(0xFF10161E),
              border: material.Border(
                bottom: material.BorderSide(color: material.Color(0xFF222D38)),
              ),
            ),
            child: material.Row(
              children: <material.Widget>[
                const material.Text(
                  'VISUAL CIRCUIT',
                  style: material.TextStyle(fontSize: 11, fontWeight: material.FontWeight.w700),
                ),
                const material.SizedBox(width: 16),
                material.Text(
                  '${diagram.qubitCount} qubits • depth ${diagram.depth}',
                  style: const material.TextStyle(fontSize: 11, color: material.Color(0xFF82909D)),
                ),
                const material.Spacer(),
                if (selected != null) ...<material.Widget>[
                  material.Text(
                    'op ${selected.operationIndex}: ${selected.label}',
                    style: const material.TextStyle(fontSize: 11, color: material.Color(0xFFAAB5C2)),
                  ),
                  const material.SizedBox(width: 8),
                  material.TextButton(
                    onPressed: () => widget.onEdit(RemoveCircuitOperation(selected.operationIndex)),
                    child: const material.Text('Delete'),
                  ),
                  if (selected.kind == CircuitNodeKind.gate && selected.qubits.length == 1)
                    material.TextButton(
                      onPressed: () => widget.onEdit(ReplaceCircuitGate(
                        operationIndex: selected.operationIndex,
                        name: 'x',
                        qubits: selected.qubits,
                        controls: selected.controls,
                      )),
                      child: const material.Text('Replace X'),
                    ),
                ],
              ],
            ),
          ),
          material.Expanded(
            flex: 3,
            child: CircuitCanvas(
              diagram: diagram,
              selectedOperation: _selectedOperation,
              onSelected: (value) => setState(() => _selectedOperation = value),
            ),
          ),
          const material.Divider(height: 1, color: material.Color(0xFF222D38)),
          material.Expanded(
            flex: 2,
            child: material.Row(
              crossAxisAlignment: material.CrossAxisAlignment.stretch,
              children: <material.Widget>[
                material.Expanded(
                  flex: 3,
                  child: material.ListView(
                    padding: const material.EdgeInsets.all(10),
                    children: <material.Widget>[
                      const material.Text(
                        'COMPILER TRACE',
                        style: material.TextStyle(fontSize: 10, fontWeight: material.FontWeight.w700),
                      ),
                      const material.SizedBox(height: 8),
                      if (trace == null)
                        const material.Text(
                          'Run the circuit to generate pass-by-pass compiler metrics.',
                          style: material.TextStyle(fontSize: 11, color: material.Color(0xFF7F8A96)),
                        )
                      else
                        for (final stage in trace.stages)
                          material.Container(
                            margin: const material.EdgeInsets.only(bottom: 7),
                            padding: const material.EdgeInsets.all(9),
                            decoration: material.BoxDecoration(
                              color: const material.Color(0xFF111820),
                              border: material.Border.all(color: const material.Color(0xFF222D38)),
                              borderRadius: material.BorderRadius.circular(5),
                            ),
                            child: material.Row(
                              children: <material.Widget>[
                                material.Expanded(
                                  child: material.Column(
                                    crossAxisAlignment: material.CrossAxisAlignment.start,
                                    children: <material.Widget>[
                                      material.Text(
                                        stage.name,
                                        style: const material.TextStyle(fontSize: 11, fontWeight: material.FontWeight.w600),
                                      ),
                                      const material.SizedBox(height: 3),
                                      material.Text(
                                        stage.notes.join(' '),
                                        style: const material.TextStyle(fontSize: 10, color: material.Color(0xFF778492)),
                                      ),
                                    ],
                                  ),
                                ),
                                material.Text(
                                  'depth ${stage.metrics.depthBefore}→${stage.metrics.depthAfter}   '
                                  'gates ${stage.metrics.gateCountBefore}→${stage.metrics.gateCountAfter}',
                                  style: const material.TextStyle(fontSize: 10, color: material.Color(0xFF9BA8B6)),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
                const material.VerticalDivider(width: 1, color: material.Color(0xFF222D38)),
                material.Expanded(
                  flex: 2,
                  child: material.ListView(
                    padding: const material.EdgeInsets.all(10),
                    children: <material.Widget>[
                      const material.Text(
                        'PROVIDERS',
                        style: material.TextStyle(fontSize: 10, fontWeight: material.FontWeight.w700),
                      ),
                      const material.SizedBox(height: 8),
                      for (final provider in widget.controller.providers)
                        material.Padding(
                          padding: const material.EdgeInsets.only(bottom: 7),
                          child: material.Row(
                            children: <material.Widget>[
                              material.Container(
                                width: 7,
                                height: 7,
                                decoration: material.BoxDecoration(
                                  shape: material.BoxShape.circle,
                                  color: switch (provider.health) {
                                    ProviderHealth.ready => const material.Color(0xFF45C486),
                                    ProviderHealth.degraded => const material.Color(0xFFE6A23C),
                                    ProviderHealth.unavailable => const material.Color(0xFFE05A5A),
                                    ProviderHealth.unknown => const material.Color(0xFF73808D),
                                  },
                                ),
                              ),
                              const material.SizedBox(width: 7),
                              material.Expanded(
                                child: material.Text(provider.displayName, style: const material.TextStyle(fontSize: 10)),
                              ),
                              material.Text(
                                '${provider.targets.length} targets',
                                style: const material.TextStyle(fontSize: 9, color: material.Color(0xFF778492)),
                              ),
                            ],
                          ),
                        ),
                      const material.SizedBox(height: 12),
                      const material.Text(
                        'WORKSPACE GRAPH',
                        style: material.TextStyle(fontSize: 10, fontWeight: material.FontWeight.w700),
                      ),
                      const material.SizedBox(height: 7),
                      material.Text(
                        graph == null
                            ? 'No graph yet.'
                            : '${graph.nodes.length} nodes • ${graph.edges.length} edges\n'
                              '${graph.nodes.map((node) => node.kind.name).join(' → ')}',
                        style: const material.TextStyle(fontSize: 10, height: 1.45, color: material.Color(0xFF8D99A7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  CircuitNode? _findNode(CircuitDiagram diagram, int? operationIndex) {
    if (operationIndex == null) return null;
    for (final column in diagram.columns) {
      for (final node in column.nodes) {
        if (node.operationIndex == operationIndex) return node;
      }
    }
    return null;
  }
}

final class CircuitCanvas extends material.StatelessWidget {
  const CircuitCanvas({
    super.key,
    required this.diagram,
    required this.selectedOperation,
    required this.onSelected,
  });

  final CircuitDiagram diagram;
  final int? selectedOperation;
  final material.ValueChanged<int?> onSelected;

  @override
  material.Widget build(material.BuildContext context) {
    final width = _max(520.0, 130.0 + diagram.depth * 86.0);
    final height = _max(180.0, 80.0 + diagram.qubitCount * 58.0);
    return material.SingleChildScrollView(
      scrollDirection: material.Axis.horizontal,
      child: material.SingleChildScrollView(
        child: material.GestureDetector(
          onTapUp: (details) => onSelected(_hitTest(details.localPosition)),
          child: material.CustomPaint(
            size: material.Size(width, height),
            painter: _CircuitPainter(diagram, selectedOperation),
          ),
        ),
      ),
    );
  }

  int? _hitTest(material.Offset point) {
    for (final column in diagram.columns) {
      for (final node in column.nodes) {
        final x = 92.0 + node.column * 86.0;
        for (final qubit in node.qubits) {
          final y = 52.0 + qubit * 58.0;
          if (material.Rect.fromCenter(
            center: material.Offset(x, y),
            width: 48,
            height: 34,
          ).contains(point)) {
            return node.operationIndex;
          }
        }
      }
    }
    return null;
  }
}

final class _CircuitPainter extends material.CustomPainter {
  _CircuitPainter(this.diagram, this.selectedOperation);

  final CircuitDiagram diagram;
  final int? selectedOperation;

  @override
  void paint(material.Canvas canvas, material.Size size) {
    final wire = material.Paint()
      ..color = const material.Color(0xFF465461)
      ..strokeWidth = 1.2;
    final link = material.Paint()
      ..color = const material.Color(0xFF82909D)
      ..strokeWidth = 1.3;
    for (var q = 0; q < diagram.qubitCount; q++) {
      final y = 52.0 + q * 58.0;
      canvas.drawLine(material.Offset(56, y), material.Offset(size.width - 24, y), wire);
      _text(canvas, 'q$q', material.Offset(20, y - 7), const material.Color(0xFF8C99A7));
    }
    for (final column in diagram.columns) {
      for (final node in column.nodes) {
        final x = 92.0 + node.column * 86.0;
        final touched = <int>{...node.controls, ...node.qubits}.toList()..sort();
        if (touched.length > 1) {
          canvas.drawLine(
            material.Offset(x, 52.0 + touched.first * 58.0),
            material.Offset(x, 52.0 + touched.last * 58.0),
            link,
          );
        }
        for (final control in node.controls) {
          canvas.drawCircle(
            material.Offset(x, 52.0 + control * 58.0),
            4.5,
            material.Paint()..color = const material.Color(0xFF82909D),
          );
        }
        for (final qubit in node.qubits) {
          final center = material.Offset(x, 52.0 + qubit * 58.0);
          final rect = material.Rect.fromCenter(center: center, width: 48, height: 34);
          final selected = node.operationIndex == selectedOperation;
          canvas.drawRRect(
            material.RRect.fromRectAndRadius(rect, const material.Radius.circular(5)),
            material.Paint()
              ..color = selected ? const material.Color(0xFF164E78) : const material.Color(0xFF17212B),
          );
          canvas.drawRRect(
            material.RRect.fromRectAndRadius(rect, const material.Radius.circular(5)),
            material.Paint()
              ..color = selected ? const material.Color(0xFF4EA1FF) : const material.Color(0xFF44515E)
              ..style = material.PaintingStyle.stroke
              ..strokeWidth = selected ? 1.7 : 1.0,
          );
          _text(canvas, node.label, material.Offset(x - 18, center.dy - 7), const material.Color(0xFFE0E8F1));
        }
      }
    }
  }

  void _text(material.Canvas canvas, String value, material.Offset offset, material.Color color) {
    final painter = material.TextPainter(
      text: material.TextSpan(
        text: value,
        style: material.TextStyle(fontSize: 10, color: color, fontFamily: 'monospace'),
      ),
      textDirection: material.TextDirection.ltr,
    )..layout(maxWidth: 70);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) =>
      oldDelegate.diagram != diagram || oldDelegate.selectedOperation != selectedOperation;
}

double _max(double a, double b) => a > b ? a : b;
