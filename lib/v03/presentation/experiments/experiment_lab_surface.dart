import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../application/workbench_controller.dart';

final class ExperimentLabSurface extends StatefulWidget {
  const ExperimentLabSurface({
    super.key,
    required this.controller,
    required this.onRefresh,
    required this.onCompare,
  });

  final WorkbenchController controller;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String leftId, String rightId) onCompare;

  @override
  State<ExperimentLabSurface> createState() => _ExperimentLabSurfaceState();
}

final class _ExperimentLabSurfaceState extends State<ExperimentLabSurface> {
  String? _left;
  String? _right;

  @override
  Widget build(BuildContext context) {
    final records = widget.controller.experimentHistory;
    final comparison = widget.controller.experimentComparison;
    return ColoredBox(
      color: const Color(0xFF0D1218),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 44,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 14),
                const Text('Experiment Lab', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Button(
                  onPressed: () => unawaited(widget.onRefresh()),
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _left == null || _right == null || _left == _right
                      ? null
                      : () => unawaited(widget.onCompare(_left!, _right!)),
                  child: const Text('Compare A ↔ B'),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          const Divider(size: 1),
          if (comparison != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111820),
                border: Border.all(color: const Color(0xFF263442)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                children: <Widget>[
                  _metric('TVD', comparison.totalVariationDistance.toStringAsFixed(6)),
                  _metric('Max ΔP', comparison.maxProbabilityDelta.toStringAsFixed(6)),
                  _metric('Source', comparison.sameSource ? 'same' : 'changed'),
                  _metric('Backend', comparison.sameBackend ? 'same' : 'changed'),
                  _metric('Shot Δ', '${comparison.shotDelta}'),
                  _metric('Artifact Δ', '${comparison.changedArtifacts.length}'),
                ],
              ),
            ),
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text(
                      'No experiments yet. Run a quantum document first.',
                      style: TextStyle(color: Color(0xFF7F8A96)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111820),
                          border: Border.all(color: const Color(0xFF202B36)),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(record.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${record.backendId}/${record.targetId} • ${record.shots} shots • '
                                    '${record.createdAt.toLocal()}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF83909D)),
                                  ),
                                ],
                              ),
                            ),
                            Button(
                              onPressed: () => setState(() => _left = record.id),
                              child: Text(_left == record.id ? 'A ✓' : 'Set A'),
                            ),
                            const SizedBox(width: 5),
                            Button(
                              onPressed: () => setState(() => _right = record.id),
                              child: Text(_right == record.id ? 'B ✓' : 'Set B'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF718091))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ],
      );
}
