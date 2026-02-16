import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/viz_service.dart';
import '../../core/theme/ket_theme.dart';
import 'inspector_widget.dart';

class InspectorSidebarWidget extends StatefulWidget {
  const InspectorSidebarWidget({super.key});

  @override
  State<InspectorSidebarWidget> createState() => _InspectorSidebarWidgetState();
}

class _InspectorSidebarWidgetState extends State<InspectorSidebarWidget> {
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

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = VizService();
    final currentSession = service.currentSession;

    // Find the latest inspector event in the current session
    VizEvent? inspectorEvent;
    if (currentSession != null) {
      try {
        inspectorEvent = currentSession.events.lastWhere(
          (e) => e.type == VizType.inspector,
        );
      } catch (_) {
        // Not found
      }
    }

    if (inspectorEvent == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.reading_mode,
              size: 40,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              "No inspector data found.",
              style: TextStyle(color: KetTheme.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              "Run a circuit inspector template to see steps here.",
              style: TextStyle(color: KetTheme.textMuted, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return InspectorWidget(payload: inspectorEvent.payload);
  }
}
