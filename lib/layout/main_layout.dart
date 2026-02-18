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
          SizedBox(
            width: 250,
            child: PanelHeader(panel: activeLeft, child: activeLeft.buildContent(context)),
          ),
        if (activeLeft != null) Container(width: 1, color: Colors.black),
        
        const Expanded(child: EditorWidget()),
        
        if (activeRight != null) Container(width: 1, color: Colors.black),
        if (activeRight != null)
          SizedBox(
            width: 300,
            child: PanelHeader(panel: activeRight, child: activeRight.buildContent(context)),
          ),
      ],
    );

    if (!_layout.isBottomPanelVisible) return horizontalView;

    // Vertical structure: [Horizontal View] [Divider] [Terminal]
    return Column(
      children: [
        Expanded(child: horizontalView),
        Container(height: 1, color: Colors.black),
        SizedBox(
          height: 200,
          child: TerminalWidget(layout: _layout),
        ),
      ],
    );
  }
}
