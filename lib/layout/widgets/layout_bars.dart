import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/theme/ket_theme.dart';
import '../../core/services/menu_service.dart';
import '../../core/services/execution_service.dart';
import '../../core/services/editor_service.dart';
import '../../core/services/layout_service.dart';
import '../../core/services/python_setup_service.dart';
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
      height: 48, // Modern Windows 11 title bar height
      color: KetTheme.bgSidebar,
      child: Row(
        children: [
          // App Icon & Brand
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Image.asset(
              'assets/quantum.jpg',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          ),

          // INSTALLATIONS STATUS
          ValueListenableBuilder<String?>(
            valueListenable: PythonSetupService().currentTask,
            builder: (context, task, child) {
              if (task == null) return const SizedBox();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: ProgressRing(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
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
                listenable: MenuService(),
                builder: (context, _) {
                  return Row(
                    children: MenuService().menus.map((group) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: DropDownButton(
                          title: Text(
                            group.title,
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                          items: group.items.map((item) {
                            if (item.isSeparator) {
                              return const MenuFlyoutSeparator();
                            }
                            return MenuFlyoutItem(
                              leading: item.icon != null
                                  ? Icon(item.icon, size: 14)
                                  : null,
                              text: Text(item.label),
                              onPressed: item.onTap,
                              trailing: item.shortcut != null
                                  ? Text(
                                      item.shortcut!,
                                      style:
                                          (FluentTheme.maybeOf(
                                                    context,
                                                  )?.typography.caption ??
                                                  const TextStyle())
                                              .copyWith(color: Colors.grey),
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
      width: 48,
      decoration: BoxDecoration(
        color: KetTheme.bgActivityBar,
        border: Border(
          right: isLeft
              ? BorderSide(
                  color: Colors.black.withValues(alpha: 0.2),
                  width: 0.5,
                )
              : BorderSide.none,
          left: !isLeft
              ? BorderSide(
                  color: Colors.black.withValues(alpha: 0.2),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...panels.map((panel) {
            bool isActive = isLeft
                ? layout.activeLeftPanelId == panel.id
                : layout.activeRightPanelId == panel.id;

            return Stack(
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              children: [
                if (isActive)
                  Container(width: 2, height: 24, color: KetTheme.accent),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Tooltip(
                    message: panel.title,
                    child: IconButton(
                      icon: Icon(
                        panel.icon,
                        color: isActive ? Colors.white : KetTheme.textMuted,
                        size: 22,
                      ),
                      onPressed: () => isLeft
                          ? layout.toggleLeftPanel(panel.id)
                          : layout.toggleRightPanel(panel.id),
                    ),
                  ),
                ),
              ],
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
                Text(
                  panel.title.toUpperCase(),
                  style: const TextStyle(
                    color: KetTheme.textMain,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
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
