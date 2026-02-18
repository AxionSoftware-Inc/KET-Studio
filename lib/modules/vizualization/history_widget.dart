import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/viz_service.dart';
import '../../core/theme/ket_theme.dart';

class VizHistoryWidget extends StatelessWidget {
  const VizHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VizService(),
      builder: (context, _) {
        final service = VizService();
        final sessions = service.sessions;

        if (sessions.isEmpty) {
          return Center(
            child: Text(
              "No execution history",
              style: TextStyle(color: KetTheme.textMuted, fontSize: 12),
            ),
          );
        }

        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, sIndex) {
            final session = sessions[sIndex];
            // If we have many events, restrict height to improve performance and usability
            final bool useScrollableList = session.events.length > 5;

            return Expander(
              initiallyExpanded: sIndex == 0,
              header: Row(
                children: [
                  _getStatusIcon(session.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Session ${session.id.replaceFirst('v_', '')} (${session.events.length})",
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: useScrollableList
                  ? SizedBox(
                      height: 300,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(right: 12),
                        itemCount: session.events.length,
                        itemBuilder: (ctx, i) =>
                            _buildEventTile(service, session.events[i]),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: session.events
                          .map((e) => _buildEventTile(service, e))
                          .toList(),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventTile(VizService service, VizEvent e) {
    final isSelected = e == service.selectedEvent;
    return ListTile(
      onPressed: () => service.selectEvent(e),
      tileColor: isSelected
          ? WidgetStatePropertyAll(KetTheme.accent.withValues(alpha: 0.1))
          : null,
      leading: Icon(
        _getIconForType(e.type),
        size: 12,
        color: isSelected ? KetTheme.accent : Colors.grey,
      ),
      title: Text(
        e.type.toString().split('.').last.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? KetTheme.textMain : KetTheme.textMuted,
        ),
      ),
      subtitle: Text(
        e.timeStr,
        style: const TextStyle(fontSize: 9, color: Colors.grey),
      ),
    );
  }

  Widget _getStatusIcon(VizStatus status) {
    switch (status) {
      case VizStatus.running:
        return SizedBox(
          width: 8,
          height: 8,
          child: ProgressRing(strokeWidth: 2),
        );
      case VizStatus.error:
        return Icon(FluentIcons.error_badge, color: Colors.red, size: 10);
      case VizStatus.hasOutput:
        return Icon(FluentIcons.completed, color: Colors.green, size: 10);
      default:
        return Icon(FluentIcons.full_history, color: Colors.grey, size: 10);
    }
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
}
