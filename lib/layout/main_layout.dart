import 'package:fluent_ui/fluent_ui.dart';

// CONFIG & THEME
import '../config/menu_setup.dart';
import '../config/command_registry.dart';
import '../core/theme/ket_theme.dart';

// SERVICES
import '../core/plugin/plugin_system.dart';
import '../core/services/layout_service.dart';
import '../core/services/menu_service.dart';
import '../core/services/python_setup_service.dart';
import '../core/services/app_service.dart';

// MODULES
import '../modules/editor/editor_widget.dart';
import '../modules/terminal/terminal_widget.dart';

// WIDGETS
import 'widgets/layout_bars.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final LayoutService _layout = LayoutService();

  @override
  void initState() {
    super.initState();
    _layout.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupCommands(context);
      if (MenuService().menus.isEmpty) setupMenus(context);
      PythonSetupService().checkAndInstallDependencies();
      AppService().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KetTheme.bgCanvas,
      child: Column(
        children: [
          const TopBar(),
          Expanded(
            child: Row(
              children: [
                ActivityBar(isLeft: true, layout: _layout),
                Expanded(child: _buildMainContent()),
                ActivityBar(isLeft: false, layout: _layout),
              ],
            ),
          ),
          StatusBar(layout: _layout),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final activeLeft = _layout.activeLeftPanelId != null
        ? PluginRegistry().getPanel(_layout.activeLeftPanelId!)
        : null;
    final activeRight = _layout.activeRightPanelId != null
        ? PluginRegistry().getPanel(_layout.activeRightPanelId!)
        : null;

    // Horizontal structure: [Left Panel] [Divider] [Editor] [Divider] [Right Panel]
    Widget horizontalView = Row(
      children: [
        if (activeLeft != null)
          _buildSidePanel(
            panel: activeLeft,
            width: 272,
            padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
          ),
        const Expanded(
          child: Padding(padding: EdgeInsets.all(10), child: EditorWidget()),
        ),
        if (activeRight != null)
          _buildSidePanel(
            panel: activeRight,
            width: 320,
            padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
          ),
      ],
    );

    if (!_layout.isBottomPanelVisible) return horizontalView;

    // Vertical structure: [Horizontal View] [Divider] [Terminal]
    return Column(
      children: [
        Expanded(child: horizontalView),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: SizedBox(height: 220, child: TerminalWidget(layout: _layout)),
        ),
      ],
    );
  }

  Widget _buildSidePanel({
    required ISidePanel panel,
    required double width,
    required EdgeInsets padding,
  }) {
    return Padding(
      padding: padding,
      child: SizedBox(
        width: width,
        child: KeyedSubtree(
          key: ValueKey(panel.id),
          child: PanelHeader(panel: panel, child: panel.buildContent(context)),
        ),
      ),
    );
  }
}
