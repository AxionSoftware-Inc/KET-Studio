import 'package:fluent_ui/fluent_ui.dart';
import '../../core/plugin/plugin_system.dart';
import 'viz_widget.dart';
import 'history_widget.dart';
import 'history_widget.dart';
import 'inspector_sidebar_widget.dart';
import 'metrics_widget.dart';
import 'resource_estimator_widget.dart';

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

class CircuitInspectorPlugin implements ISidePanel {
  @override
  String get id => 'inspector';

  @override
  IconData get icon => FluentIcons.reading_mode;

  @override
  String get title => 'INSPECTOR';

  @override
  String get tooltip => 'Circuit Inspector';

  @override
  PanelPosition get position => PanelPosition.right;

  @override
  Widget buildContent(BuildContext context) {
    return const InspectorSidebarWidget();
  }
}

class MetricsPlugin implements ISidePanel {
  @override
  String get id => 'metrics';

  @override
  IconData get icon => FluentIcons.analytics_report;

  @override
  String get title => 'METRICS';

  @override
  String get tooltip => 'Execution Metrics';

  @override
  PanelPosition get position => PanelPosition.right;

  @override
  Widget buildContent(BuildContext context) {
    return const MetricsSidebarWidget();
  }
}

class ResourceEstimatorPlugin implements ISidePanel {
  @override
  String get id => 'estimator';

  @override
  IconData get icon => FluentIcons.speed_high;

  @override
  String get title => 'ESTIMATOR';

  @override
  String get tooltip => 'Resource Estimator';

  @override
  PanelPosition get position => PanelPosition.right;

  @override
  Widget buildContent(BuildContext context) {
    return const ResourceEstimatorWidget();
  }
}
