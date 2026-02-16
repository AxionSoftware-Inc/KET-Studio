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
    await ExecutionService().runPython(activeFile.path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35, // macOS-like compact height
      decoration: BoxDecoration(
        color: KetTheme.bgSidebar,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // App Icon & Brand
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 8.0),
            child: Image.asset(
              'assets/quantum.jpg',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ),

          // INSTALLATIONS STATUS (stays visible when active)
          ValueListenableBuilder<String?>(
            valueListenable: PythonSetupService().currentTask,
            builder: (context, task, child) {
              if (task == null) return const SizedBox();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: ProgressRing(strokeWidth: 1.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      task.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Main Menu Section
          Expanded(
            child: MoveWindow(
              child: ListenableBuilder(
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
                          trailing:
                              const SizedBox.shrink(), // No arrow (macOS style)
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.isHovered) return KetTheme.bgHover;
                              return Colors.transparent;
                            }),
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
                            if (cmd == null) return const MenuFlyoutSeparator();

                            return MenuFlyoutItem(
                              leading: cmd.icon != null
                                  ? Icon(cmd.icon, size: 14)
                                  : null,
                              text: Text(item.label, style: KetTheme.menuStyle),
                              onPressed:
                                  (cmd.isEnabled == null || cmd.isEnabled!())
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
            ),
          ),

          // PRO RUN BUTTON & CONTROLS
          ValueListenableBuilder<bool>(
            valueListenable: ExecutionService().isRunning,
            builder: (context, running, child) {
              return Row(
                children: [
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

                  // Primary Run Button
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
                        mainAxisSize: MainAxisSize.min,
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

          const SizedBox(width: 8),
          const Divider(direction: Axis.vertical),
          const SizedBox(width: 8),

          // Window Buttons
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
    return GestureDetector(
      onPanStart: (details) => windowManager.startDragging(),
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
          icon: FluentIcons.chrome_full_screen, // Alternative to maximize
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
          child: Center(
            child: Icon(
              icon,
              size: 12,
              color: isHovered && isClose ? Colors.white : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

// 2. ACTIVITY BAR (Side selection)
class ActivityBar extends StatelessWidget {
  final bool isLeft;
  final LayoutService layout;

  const ActivityBar({super.key, required this.isLeft, required this.layout});

  @override
  Widget build(BuildContext context) {
    final panels = isLeft
        ? PluginRegistry().leftPanels
        : PluginRegistry().rightPanels;
    if (panels.isEmpty) return const SizedBox();

    return Container(
      width: 48, // Compact width
      decoration: BoxDecoration(
        color: KetTheme.bgActivityBar,
        border: Border(
          right: isLeft
              ? BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 1)
              : BorderSide.none,
          left: !isLeft
              ? BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 1)
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
                          color: isActive ? Colors.white : KetTheme.textMuted,
                          size: 18, // Professional VS Code-like size
                        ),
                        onPressed: () => isLeft
                            ? layout.toggleLeftPanel(panel.id)
                            : layout.toggleRightPanel(panel.id),
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(EdgeInsets.zero),
                        ),
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
  }
}

// 3. STATUS BAR
class StatusBar extends StatelessWidget {
  final LayoutService layout;
  const StatusBar({super.key, required this.layout});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      color: KetTheme.accent,
      child: Row(
        children: [
          // Toggle Terminal Button
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
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "TERMINAL",
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

          const Spacer(),

          // STATUS INDICATORS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Text(
                  "UTF-8",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  "Alpha v1.0.0",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 15),
                const Icon(
                  FluentIcons.check_mark,
                  size: 10,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  "Ready",
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 4. PANEL HEADER
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
                const Icon(
                  FluentIcons.more,
                  color: KetTheme.textMain,
                  size: 14,
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
