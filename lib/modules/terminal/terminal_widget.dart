import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/execution_service.dart';
import '../../core/services/layout_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/terminal_service.dart';
import '../../core/theme/ket_theme.dart';

class TerminalWidget extends StatefulWidget {
  final LayoutService layout;
  const TerminalWidget({super.key, required this.layout});

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _isScrollThrottled = false;

  void _scrollToBottom() {
    if (_scrollController.hasClients && !_isScrollThrottled) {
      _isScrollThrottled = true;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

      Future.delayed(const Duration(milliseconds: 50), () {
        _isScrollThrottled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([TerminalService(), SettingsService()]),
      builder: (context, _) {
        final settings = SettingsService();
        if (widget.layout.isBottomPanelVisible && settings.terminalAutoScroll) {
          _scrollToBottom();
        }

        return DecoratedBox(
          decoration: KetTheme.panelSurface(
            elevated: true,
            radius: KetTheme.radiusLg,
          ),
          child: ClipRRect(
            borderRadius: KetTheme.radiusLg,
            child: Column(
              children: [
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: KetTheme.bgHeader,
                    border: Border(bottom: BorderSide(color: KetTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FluentIcons.command_prompt,
                        size: 13,
                        color: KetTheme.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Terminal",
                        style: KetTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Python output",
                        style: KetTheme.descriptionStyle.copyWith(fontSize: 11),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          FluentIcons.delete,
                          size: 14,
                          color: KetTheme.textMuted,
                        ),
                        onPressed: () => TerminalService().clear(),
                      ),
                      IconButton(
                        icon: Icon(
                          FluentIcons.chrome_close,
                          size: 13,
                          color: KetTheme.textMuted,
                        ),
                        onPressed: () => widget.layout.toggleBottomPanel(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SelectionArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(14),
                      itemCount: TerminalService().logs.length,
                      itemBuilder: (context, index) {
                        final log = TerminalService().logs[index];
                        final lower = log.toLowerCase();
                        final isError =
                            lower.contains('error') ||
                            lower.contains('exception') ||
                            lower.contains('traceback');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: isError
                                  ? KetTheme.danger
                                  : KetTheme.textMain,
                              fontFamily: KetTheme.isWindowsDesktop
                                  ? 'Cascadia Mono'
                                  : 'monospace',
                              fontSize: settings.terminalFontSize,
                              height: 1.28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: KetTheme.bgHeader,
                    border: Border(top: BorderSide(color: KetTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        ">",
                        style: KetTheme.statusStyle.copyWith(
                          color: KetTheme.accent,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextBox(
                          controller: _inputController,
                          focusNode: _focusNode,
                          style: TextStyle(
                            color: KetTheme.textMain,
                            fontFamily: KetTheme.isWindowsDesktop
                                ? 'Cascadia Mono'
                                : 'monospace',
                            fontSize: settings.terminalFontSize,
                          ),
                          cursorColor: KetTheme.accent,
                          placeholder: "Python buyrug'ini yozing...",
                          placeholderStyle: TextStyle(
                            color: KetTheme.textMuted,
                            fontFamily: KetTheme.isWindowsDesktop
                                ? 'Cascadia Mono'
                                : 'monospace',
                          ),
                          decoration: WidgetStateProperty.all(
                            BoxDecoration(
                              color: KetTheme.bgCanvas.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: KetTheme.border),
                            ),
                          ),
                          onSubmitted: (text) {
                            if (text.isNotEmpty) {
                              TerminalService().write("\$ $text");
                              ExecutionService().writeToStdin(text);
                              _inputController.clear();
                              _focusNode.requestFocus();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
