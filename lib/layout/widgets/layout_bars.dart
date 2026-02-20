import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/theme/ket_theme.dart';
import '../../core/services/menu_service.dart';
import '../../core/services/execution_service.dart';
import '../../core/services/editor_service.dart';
import '../../core/services/layout_service.dart';
import '../../core/services/python_setup_service.dart';
import '../../core/services/command_service.dart';
import '../../core/plugin/plugin_system.dart';

// 1. TOP BAR (Custom Title Bar)
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  void _handleRun() async {
    final activeFile = EditorService().activeFile;
    if (activeFile == null) return;
    await EditorService().saveActiveFile();
    await ExecutionService().runPython(
      activeFile.path,
      content: activeFile.controller.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: KetTheme.bgSidebar,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // 1. LEFT - BRAND & MENUS (Interactive)
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 8.0),
            child: Image.asset('assets/quantum.jpg', width: 20, height: 20),
          ),

          // Main Menus
          ListenableBuilder(
            listenable: Listenable.merge([
              MenuService(),
              CommandService(),
              EditorService(),
              ExecutionService().isRunning,
            ]),
            builder: (context, _) {
              return Row(
                children: MenuService().menus.map((group) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: DropDownButton(
                      title: Text(group.title, style: KetTheme.menuStyle),
                      trailing: SizedBox.shrink(),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.isHovered) return KetTheme.bgHover;
                          return Colors.transparent;
                        }),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            side: BorderSide.none,
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                      items: group.items.map((item) {
                        if (item.isSeparator) {
                          return const MenuFlyoutSeparator();
                        }
                        final cmd = item.command;
                        if (cmd == null) {
                          return const MenuFlyoutSeparator();
                        }
                        return MenuFlyoutItem(
                          leading: cmd.icon != null
                              ? Icon(cmd.icon, size: 14)
                              : null,
                          text: Text(item.label, style: KetTheme.menuStyle),
                          onPressed: (cmd.isEnabled == null || cmd.isEnabled!())
                              ? cmd.action
                              : null,
                          trailing: cmd.shortcut != null
                              ? Text(
                                  cmd.shortcut!,
                                  style: KetTheme.menuStyle.copyWith(
                                    color: KetTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // 2. CENTER - DRAG AREA (Non-interactive)
          Expanded(child: MoveWindow(child: SizedBox.expand())),

          // 3. RIGHT - ACTIONS (Interactive)
          ValueListenableBuilder<bool>(
            valueListenable: ExecutionService().isRunning,
            builder: (context, running, child) {
              return Row(
                children: [
                  const SizedBox(width: 12),
                  if (running)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Tooltip(
                        message: "Stop Execution",
                        child: IconButton(
                          icon: const Icon(
                            FluentIcons.stop,
                            color: Color(0xFFFF0000),
                            size: 16,
                          ),
                          onPressed: () => ExecutionService().stop(),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilledButton(
                      onPressed: running ? null : _handleRun,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (running) {
                            return Colors.grey.withValues(alpha: 0.2);
                          }
                          if (states.isHovered) {
                            return Colors.green.withValues(alpha: 0.8);
                          }
                          return Colors.green;
                        }),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            running
                                ? FluentIcons.progress_ring_dots
                                : FluentIcons.play,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "RUN",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          Tooltip(
            message: "Settings (Ctrl+,)",
            child: IconButton(
              icon: const Icon(FluentIcons.settings, size: 14),
              onPressed: () => CommandService().execute("settings.open"),
            ),
          ),
          const SizedBox(width: 8),
          const Divider(direction: Axis.vertical),
          const SizedBox(width: 8),
          const WindowButtons(),
        ],
      ),
    );
  }
}

class MoveWindow extends StatelessWidget {
  final Widget child;
  const MoveWindow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(color: Colors.transparent, child: child),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        WindowButton(
          icon: FluentIcons.chrome_minimize,
          onPressed: () => windowManager.minimize(),
        ),
        WindowButton(
          icon: FluentIcons.chrome_full_screen,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        WindowButton(
          icon: FluentIcons.chrome_close,
          isClose: true,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const WindowButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final isHovered = states.isHovered;
        return Container(
          width: 45,
          height: 32,
          color: isHovered
              ? (isClose ? Colors.red : Colors.white.withValues(alpha: 0.1))
              : Colors.transparent,
          child: Center(child: Icon(icon, size: 12, color: Colors.white)),
        );
      },
    );
  }
}

class ActivityBar extends StatelessWidget {
  final bool isLeft;
  final LayoutService layout;

  const ActivityBar({super.key, required this.isLeft, required this.layout});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: layout,
      builder: (context, _) {
        final panels = isLeft
            ? PluginRegistry().leftPanels
            : PluginRegistry().rightPanels;
        if (panels.isEmpty) return const SizedBox();

        return Container(
          width: 48,
          decoration: BoxDecoration(
            color: KetTheme.bgActivityBar,
            border: Border(
              right: isLeft
                  ? BorderSide(
                      color: Colors.black.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : BorderSide.none,
              left: !isLeft
                  ? BorderSide(
                      color: Colors.black.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              ...panels.map((panel) {
                bool isActive = isLeft
                    ? layout.activeLeftPanelId == panel.id
                    : layout.activeRightPanelId == panel.id;

                return SizedBox(
                  height: 48,
                  width: 48,
                  child: Stack(
                    alignment: isLeft
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    children: [
                      if (isActive)
                        Container(width: 2, height: 28, color: KetTheme.accent),
                      Center(
                        child: Tooltip(
                          message: panel.title,
                          child: IconButton(
                            icon: Icon(
                              panel.icon,
                              color: isActive
                                  ? Colors.white
                                  : KetTheme.textMuted,
                              size: 18,
                            ),
                            onPressed: () {
                              if (isLeft) {
                                layout.toggleLeftPanel(panel.id);
                              } else {
                                layout.toggleRightPanel(panel.id);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class StatusBar extends StatelessWidget {
  final LayoutService layout;
  const StatusBar({super.key, required this.layout});

  Widget _buildSeparator() {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.24),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        EditorService(),
        ExecutionService().isRunning,
        PythonSetupService(),
      ]),
      builder: (context, _) {
        final editor = EditorService();
        final exec = ExecutionService();
        final setup = PythonSetupService();
        final activeFile = editor.activeFile;

        return Container(
          height: 24,
          color: KetTheme.accent,
          child: Row(
            children: [
              HoverButton(
                onPressed: () => layout.toggleBottomPanel(),
                builder: (context, states) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: states.isHovered
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        const Icon(
                          FluentIcons.command_prompt,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "TERMINAL",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(width: 10),

              if (activeFile != null)
                Text(
                  activeFile.path.startsWith('/fake')
                      ? activeFile.name
                      : activeFile.path,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),

              const Spacer(),

              _buildSeparator(),

              if (setup.isSetupComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        FluentIcons.product_variant,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Qiskit: ${setup.qiskitVersion}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              _buildSeparator(),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      setup.isSetupComplete
                          ? FluentIcons.completed
                          : FluentIcons.sync_status,
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<String?>(
                      valueListenable: setup.currentTask,
                      builder: (context, task, _) {
                        return Text(
                          task ??
                              (setup.isSetupComplete
                                  ? "Env: Ready"
                                  : "Env: Initializing"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              _buildSeparator(),

              if (activeFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    "Ln ${editor.cursorLine}, Col ${editor.cursorColumn}",
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),

              _buildSeparator(),

              ValueListenableBuilder<bool>(
                valueListenable: exec.isRunning,
                builder: (context, running, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        if (running) ...[
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: ProgressRing(
                              strokeWidth: 1.5,
                              value: null,
                              activeColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          running ? "Python Running" : "Engine: Idle",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              _buildSeparator(),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  "Alpha v1.0.0",
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PanelHeader extends StatelessWidget {
  final ISidePanel panel;
  final Widget child;
  const PanelHeader({super.key, required this.panel, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KetTheme.bgSidebar,
      child: Column(
        children: [
          Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(panel.title.toUpperCase(), style: KetTheme.headerStyle),
                Icon(FluentIcons.more, color: KetTheme.textMain, size: 14),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
