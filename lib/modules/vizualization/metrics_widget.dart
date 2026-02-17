import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/viz_service.dart';
import '../../core/theme/ket_theme.dart';
import '../../core/services/export_service.dart';

class MetricsSidebarWidget extends StatelessWidget {
  const MetricsSidebarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VizService(),
      builder: (context, _) {
        final service = VizService();
        final currentSession = service.currentSession;
        final status = service.status;
        
        // 1. Check if we are currently running but have no metrics yet
        bool isRunning = status == VizStatus.running;

        VizEvent? metricsEvent;
        if (currentSession != null) {
          try {
            metricsEvent = currentSession.events.lastWhere(
              (e) => e.type == VizType.metrics,
            );
          } catch (_) {}
        }

        if (metricsEvent == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRunning) ...[
                  const ProgressRing(),
                  const SizedBox(height: 16),
                  Text("Executing script...", style: TextStyle(color: KetTheme.textMuted)),
                  const SizedBox(height: 4),
                  const Text("Waiting for metrics data...", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ] else ...[
                  Icon(
                    FluentIcons.analytics_report,
                    size: 40,
                    color: Colors.grey.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  Text("No metrics available", style: TextStyle(color: KetTheme.textMuted)),
                  const SizedBox(height: 8),
                  const Text("Run a script to see analytics here", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ],
            ),
          );
        }

        final data = metricsEvent.payload;
        if (data is! Map) return const Center(child: Text("Invalid data format"));
        final Map<String, dynamic> map = Map<String, dynamic>.from(data);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Icon(FluentIcons.analytics_report, size: 14, color: KetTheme.accent),
                const SizedBox(width: 10),
                Text(
                  "EXECUTION REPORT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: KetTheme.textMain,
                    letterSpacing: 1.0,
                  ),
                ),
                Tooltip(
                  message: "Export to CSV",
                  child: IconButton(
                    icon: const Icon(FluentIcons.download, size: 12),
                    onPressed: () => ExportService().exportMetricsToCsv(
                      Map<String, dynamic>.from(data),
                      fileName: "metrics_${currentSession?.id ?? 'export'}.csv",
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: "Clear Metrics",
                  child: IconButton(
                    icon: const Icon(FluentIcons.delete, size: 12),
                    onPressed: () => service.clear(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...map.entries.map((e) => _buildDynamicMetric(e.key, e.value)),
            
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SESSION INFO", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text("ID: ${currentSession?.id}", style: const TextStyle(fontSize: 9, fontFamily: 'monospace')),
                  Text("Completed: ${metricsEvent.timeStr}", style: const TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDynamicMetric(String key, dynamic value) {
    String displayValue = value.toString();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              color: KetTheme.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            displayValue,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}
