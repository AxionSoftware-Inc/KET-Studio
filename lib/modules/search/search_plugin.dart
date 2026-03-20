import 'package:fluent_ui/fluent_ui.dart';
import '../../core/plugin/plugin_system.dart';
import 'search_widget.dart';

class SearchPlugin implements ISidePanel {
  @override
  String get id => 'search';

  @override
  IconData get icon => FluentIcons.search;

  @override
  String get title => 'SEARCH';

  @override
  String get tooltip => 'Global Search';

  @override
  PanelPosition get position => PanelPosition.left;

  @override
  Widget buildContent(BuildContext context) {
    return const SearchWidget();
  }
}
