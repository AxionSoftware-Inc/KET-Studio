import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/viz_service.dart';
import '../../core/theme/ket_theme.dart';

class ResourceEstimatorWidget extends StatelessWidget {
  const ResourceEstimatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VizService(),
      builder: (context, _) {
        final service = VizService();
        final currentSession = service.currentSession;
        final isRunning = service.status == VizStatus.running;

        VizEvent? estimatorEvent;
        if (currentSession != null) {
          try {
            estimatorEvent = currentSession.events.lastWhere((e) => e.type == VizType.estimator);
          } catch (_) {}
        }

        if (estimatorEvent == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRunning) ...[
                  const ProgressRing(),
                  const SizedBox(height: 16),
                  Text("Estimating resources...", style: TextStyle(color: KetTheme.textMuted)),
                ] else ...[
                  Icon(
                    FluentIcons.speed_high,
                    size: 40,
                    color: Colors.grey.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  Text("No resource data", style: TextStyle(color: KetTheme.textMuted)),
                  const SizedBox(height: 8),
                  const Text("Run an estimator template to see data", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ],
            ),
          );
        }

        final data = estimatorEvent.payload;
        if (data is! Map) return const Center(child: Text("Invalid estimator data"));
        
        final qubits = data['qubits'] ?? 0;
        final depth = data['depth'] ?? 0;
        final totalGates = data['total_gates'] ?? 0;
        final gateCounts = data['gate_counts'] as Map? ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Icon(FluentIcons.speed_high, size: 14, color: KetTheme.accent),
                const SizedBox(width: 10),
                Text(
                  "RESOURCE ANALYSIS",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: KetTheme.textMain,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildMainStat("Quantum Memory", "$qubits Qubits", FluentIcons.iot),
            const SizedBox(height: 16),
            _buildMainStat("Circuit Depth", "$depth Layers", FluentIcons.line_chart),
            const SizedBox(height: 16),
            _buildMainStat("Complexity", "$totalGates Total Gates", FluentIcons.processing),
            
            const SizedBox(height: 32),
            const Text(
              "GATE DISTRIBUTION",
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...gateCounts.entries.map((e) => _buildGateRow(e.key.toString(), e.value as int, totalGates as int)),
            
            const SizedBox(height: 32),
            _buildResourceVerdict(qubits as int, depth as int),
          ],
        );
      },
    );
  }

  Widget _buildMainStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KetTheme.accent),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGateRow(String gate, int count, int total) {
    final percent = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(gate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text("$count", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: ProgressBar(
              value: percent * 100,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              activeColor: KetTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceVerdict(int qubits, int depth) {
    String verdict;
    Color color;
    IconData icon;

    if (qubits < 20 && depth < 50) {
      verdict = "SIMULATABLE (LOCAL)";
      color = Colors.green;
      icon = FluentIcons.completed;
    } else if (qubits < 35) {
      verdict = "HIGH-PERFORMANCE COMPUTE NEEDED";
      color = Colors.yellow;
      icon = FluentIcons.warning;
    } else {
      verdict = "QUANTUM HARDWARE REQUIRED";
      color = Colors.orange;
      icon = FluentIcons.lock;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              verdict,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
