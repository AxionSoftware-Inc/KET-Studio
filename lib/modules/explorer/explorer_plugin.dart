import 'package:fluent_ui/fluent_ui.dart';
import '../../core/plugin/plugin_system.dart';
import 'explorer_widget.dart'; // <--- Import qiling

class ExplorerPlugin implements ISidePanel {
  @override
  String get id => 'explorer';

  @override
  IconData get icon => FluentIcons.fabric_folder_search;

  @override
  String get title => 'Explorer';

  @override
  String get tooltip => 'Project Explorer';

  @override
  PanelPosition get position => PanelPosition.left;

  @override
  Widget buildContent(BuildContext context) {
    return const ExplorerWidget(); // <--- O'zgartirildi
  }
}
