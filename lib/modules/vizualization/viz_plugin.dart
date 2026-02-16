import 'package:fluent_ui/fluent_ui.dart';
import '../../core/plugin/plugin_system.dart';
import 'viz_widget.dart';
import 'history_widget.dart';

class VisualizationPlugin implements ISidePanel {
  @override
  String get id => 'vizualization';

  @override
  IconData get icon => FluentIcons.view_dashboard;

  @override
  String get title => 'VISUALIZER';

  @override
  String get tooltip => 'Quantum Visualizer';

  @override
  PanelPosition get position => PanelPosition.right;

  @override
  Widget buildContent(BuildContext context) {
    return const VizualizationWidget();
  }
}

class VizHistoryPlugin implements ISidePanel {
  @override
  String get id => 'viz_history';

  @override
  IconData get icon => FluentIcons.history;

  @override
  String get title => 'HISTORY';

  @override
  String get tooltip => 'Execution History';

  @override
  PanelPosition get position => PanelPosition.right;

  @override
  Widget buildContent(BuildContext context) {
    return const VizHistoryWidget();
  }
}
