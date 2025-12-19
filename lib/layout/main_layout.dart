import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

// 1. CONFIG & THEME
import '../config/menu_setup.dart';
import '../core/theme/ket_theme.dart';

// 2. SERVICES
import '../core/plugin/plugin_system.dart';
import '../core/services/layout_service.dart';
import '../core/services/menu_service.dart'; // <--- Menyular shu yerdan keladi
import '../core/services/terminal_service.dart';
import '../core/services/execution_service.dart';
import '../core/services/editor_service.dart';

// 3. MODULES
import '../modules/editor/editor_widget.dart';

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

    // Layout o'zgarsa (masalan panel ochilsa) qayta chizish
    _layout.addListener(() => setState(() {}));

    // Dastur boshlanishi bilan MENYULARNI yuklaymiz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupMenus(context);
    });
  }

  // Run tugmasi uchun tezkor funksiya
  void _handleRun() async {
    final activeFile = EditorService().activeFile;
    if (activeFile == null) return;

    await EditorService().saveActiveFile();
    if (!_layout.isBottomPanelVisible) _layout.toggleBottomPanel();
    await ExecutionService().runPython(activeFile.path);
  }

  @override
  Widget build(BuildContext context) {
    if (MenuService().menus.isEmpty) {
      setupMenus(context);
    }
    // Ochiq panellarni aniqlash
    final activeLeft = _layout.activeLeftPanelId != null
        ? PluginRegistry().getPanel(_layout.activeLeftPanelId!) : null;
    final activeRight = _layout.activeRightPanelId != null
        ? PluginRegistry().getPanel(_layout.activeRightPanelId!) : null;

    // Asosiy tanani qurish
    Widget bodyContent = _buildCentralSplit(activeLeft, activeRight);

    return Scaffold(
      backgroundColor: KetTheme.bgCanvas,
      body: Column(
        children: [
          // 1. TEPA MENU (Dinamik)
          _buildTopBar(),

          // 2. O'RTA QISM (Explorer + Editor + Vizualizatsiya)
          Expanded(
            child: Row(
              children: [
                _buildActivityBar(isLeft: true), // Chap tugmalar
                Expanded(child: bodyContent),    // Asosiy ish stoli
                _buildActivityBar(isLeft: false), // O'ng tugmalar
              ],
            ),
          ),

          // 3. PASTKI QISM (Status Bar)
          _buildStatusBar(),
        ],
      ),
    );
  }

  // --- SPLIT VIEW QURUVCHI (Eng muhim qism) ---
  Widget _buildCentralSplit(ISidePanel? left, ISidePanel? right) {
    List<Area> hAreas = [];

    // A. Chap Panel
    if (left != null) {
      hAreas.add(Area(
          data: _buildSidePanelHeader(left, left.buildContent(context)),
          size: 250, min: 50
      ));
    }

    // B. Editor (Markaz)
    hAreas.add(Area(
        data: const EditorWidget(),
        flex: 1
    ));

    // C. O'ng Panel
    if (right != null) {
      hAreas.add(Area(
          data: _buildSidePanelHeader(right, right.buildContent(context)),
          size: 300, min: 50
      ));
    }

    // Gorizontal ko'rinishni yig'ish
    Widget horizontalView;
    if (hAreas.length == 1) {
      horizontalView = hAreas.first.data as Widget;
    } else {
      horizontalView = MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerThickness: 1, // Ingichka professional chiziq
          dividerPainter: DividerPainters.background(color: Colors.black),
        ),
        child: MultiSplitView(
          key: ValueKey("H-${hAreas.length}"), // Qayta chizish kaliti
          controller: MultiSplitViewController(areas: hAreas),
          builder: (context, area) => area.data as Widget,
        ),
      );
    }

    // D. Vertikal (Terminal qo'shish)
    if (!_layout.isBottomPanelVisible) return horizontalView;

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 1,
        dividerPainter: DividerPainters.background(color: Colors.black),
      ),
      child: MultiSplitView(
        axis: Axis.vertical,
        controller: MultiSplitViewController(areas: [
          Area(data: horizontalView, flex: 1),
          Area(data: _buildTerminal(), size: 200, min: 50),
        ]),
        builder: (context, area) => area.data as Widget,
      ),
    );
  }

  // --- UI ELEMENTLAR ---

  // 1. Dinamik Top Bar (MenuService orqali)
  Widget _buildTopBar() {
    return Container(
      height: 35,
      color: const Color(0xFF3C3C3C), // Title Bar rangi
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.code, color: KetTheme.accent, size: 18),
          const SizedBox(width: 10),

          // MENYU BAR (Bu qism MenuService dan avtomatik oladi)
          Expanded(
            child: ListenableBuilder(
              listenable: MenuService(),
              builder: (context, _) {
                return MenuBar(
                  style: const MenuStyle(
                    backgroundColor: MaterialStatePropertyAll(Colors.transparent),
                    elevation: MaterialStatePropertyAll(0),
                    padding: MaterialStatePropertyAll(EdgeInsets.zero),
                  ),
                  children: MenuService().menus.map((group) {
                    return SubmenuButton(
                      style: const ButtonStyle(
                        foregroundColor: MaterialStatePropertyAll(KetTheme.textMain),
                        overlayColor: MaterialStatePropertyAll(Colors.white10),
                      ),
                      menuChildren: group.items.map((item) {
                        return MenuItemButton(
                          onPressed: item.onTap,

                          // --- TUZATILGAN JOY ---
                          // shortcut o'rniga trailingIcon ishlatamiz
                          trailingIcon: item.shortcut != null
                              ? Text(item.shortcut!, style: const TextStyle(color: Colors.white30, fontSize: 10))
                              : null,
                          // ----------------------

                          leadingIcon: item.icon != null
                              ? Icon(item.icon, size: 16, color: KetTheme.textMain)
                              : null,
                          child: Text(item.label, style: const TextStyle(color: KetTheme.textMain)),
                        );
                      }).toList(),
                      child: Text(group.title, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // Yashil Run Tugmasi
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green, size: 20),
            tooltip: "Run Code (F5)",
            onPressed: _handleRun,
          ),
        ],
      ),
    );
  }

  // 2. Activity Bar (Chap/O'ng panellar)
  Widget _buildActivityBar({required bool isLeft}) {
    final panels = isLeft ? PluginRegistry().leftPanels : PluginRegistry().rightPanels;
    if (panels.isEmpty) return const SizedBox();

    return Container(
      width: 50,
      color: KetTheme.bgActivityBar,
      child: Column(
        children: [
          const SizedBox(height: 10),
          ...panels.map((panel) {
            bool isActive = isLeft ? _layout.activeLeftPanelId == panel.id : _layout.activeRightPanelId == panel.id;
            return InkWell(
              onTap: () => isLeft ? _layout.toggleLeftPanel(panel.id) : _layout.toggleRightPanel(panel.id),
              child: Container(
                width: 50, height: 50,
                decoration: isActive
                    ? const BoxDecoration(border: Border(left: BorderSide(color: KetTheme.accent, width: 2)))
                    : null,
                child: Icon(panel.icon, color: isActive ? Colors.white : KetTheme.textMuted, size: 24),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // 3. Panel Header
  Widget _buildSidePanelHeader(ISidePanel panel, Widget content) {
    return Container(
      color: KetTheme.bgSidebar,
      child: Column(
        children: [
          Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            color: KetTheme.bgSidebar,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(panel.title.toUpperCase(), style: const TextStyle(color: KetTheme.textMain, fontSize: 11, fontWeight: FontWeight.bold)),
                const Icon(Icons.more_horiz, color: KetTheme.textMain, size: 16)
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  // 4. Terminal
  Widget _buildTerminal() {
    return ListenableBuilder(
      listenable: TerminalService(),
      builder: (context, _) {
        return Container(
          color: KetTheme.bgCanvas,
          child: Column(
            children: [
              // Terminal Tabs
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black))),
                child: Row(
                  children: [
                    const Text("OUTPUT", style: TextStyle(color: KetTheme.textMain, fontSize: 11, decoration: TextDecoration.underline)),
                    const Spacer(),
                    InkWell(onTap: () => TerminalService().clear(), child: const Icon(Icons.block, size: 14, color: KetTheme.textMain)),
                    const SizedBox(width: 15),
                    InkWell(onTap: () => _layout.toggleBottomPanel(), child: const Icon(Icons.close, size: 14, color: KetTheme.textMain)),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: ListView.builder(
                    itemCount: TerminalService().logs.length,
                    itemBuilder: (c, i) => Text(
                        TerminalService().logs[i],
                        style: const TextStyle(color: KetTheme.textMain, fontFamily: 'Consolas', fontSize: 13)
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 5. Status Bar
  Widget _buildStatusBar() {
    return Container(
      height: 22,
      color: KetTheme.accent,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => _layout.toggleBottomPanel(),
            child: Row(
              children: const [
                Icon(Icons.terminal, size: 12, color: Colors.white),
                SizedBox(width: 5),
                Text("TERMINAL", style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
          const Text("Ready", style: TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}