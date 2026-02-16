import 'package:fluent_ui/fluent_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';

// CONFIG & THEME
import '../config/menu_setup.dart';
import '../core/theme/ket_theme.dart';

// SERVICES
import '../core/plugin/plugin_system.dart';
import '../core/services/layout_service.dart';
import '../core/services/menu_service.dart';
import '../core/services/python_setup_service.dart';

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
      if (MenuService().menus.isEmpty) setupMenus(context);

      // Auto-setup Qiskit environment
      if (!_layout.isBottomPanelVisible) {
        _layout.toggleBottomPanel();
      }
      PythonSetupService().checkAndInstallDependencies();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MenuService().menus.isEmpty) setupMenus(context);

    final activeLeft = _layout.activeLeftPanelId != null
        ? PluginRegistry().getPanel(_layout.activeLeftPanelId!)
        : null;
    final activeRight = _layout.activeRightPanelId != null
        ? PluginRegistry().getPanel(_layout.activeRightPanelId!)
        : null;

    return Container(
      color: KetTheme.bgCanvas,
      child: Column(
        children: [
          TopBar(),

          Expanded(
            child: Row(
              children: [
                ActivityBar(isLeft: true, layout: _layout),
                Expanded(child: _buildCentralSplit(activeLeft, activeRight)),
                ActivityBar(isLeft: false, layout: _layout),
              ],
            ),
          ),

          StatusBar(layout: _layout),
        ],
      ),
    );
  }

  Widget _buildCentralSplit(ISidePanel? left, ISidePanel? right) {
    List<Area> hAreas = [];

    if (left != null) {
      hAreas.add(
        Area(
          data: PanelHeader(panel: left, child: left.buildContent(context)),
          size: 250,
          min: 50,
        ),
      );
    }

    hAreas.add(Area(data: const EditorWidget(), flex: 1));

    if (right != null) {
      hAreas.add(
        Area(
          data: PanelHeader(panel: right, child: right.buildContent(context)),
          size: 300,
          min: 50,
        ),
      );
    }

    Widget horizontalView;
    if (hAreas.length == 1) {
      horizontalView = hAreas.first.data as Widget;
    } else {
      horizontalView = MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerThickness: 1,
          dividerPainter: DividerPainters.background(color: Colors.black),
        ),
        child: MultiSplitView(
          key: ValueKey("H-${hAreas.length}"),
          controller: MultiSplitViewController(areas: hAreas),
          builder: (context, area) => area.data as Widget,
        ),
      );
    }

    if (!_layout.isBottomPanelVisible) return horizontalView;

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 1,
        dividerPainter: DividerPainters.background(color: Colors.black),
      ),
      child: MultiSplitView(
        axis: Axis.vertical,
        controller: MultiSplitViewController(
          areas: [
            Area(data: horizontalView, flex: 1),
            Area(data: TerminalWidget(layout: _layout), size: 180, min: 50),
          ],
        ),
        builder: (context, area) => area.data as Widget,
      ),
    );
  }
}
