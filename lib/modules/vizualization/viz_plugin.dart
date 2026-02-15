import 'package:fluent_ui/fluent_ui.dart';
import '../../core/plugin/plugin_system.dart';
import 'viz_widget.dart';

class VisualizationPlugin implements ISidePanel {
  @override
  String get id => 'vizualization';

  @override
  IconData get icon => FluentIcons.view_dashboard;

  @override
  String get title => 'Quantum Viz';

  @override
  String get tooltip => 'Visualization Dashboard';

  @override
  PanelPosition get position => PanelPosition.right;

  @override
  Widget buildContent(BuildContext context) {
    return const VizualizationWidget();
  }
}
