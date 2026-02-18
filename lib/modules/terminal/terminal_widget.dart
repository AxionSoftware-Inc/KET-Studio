import 'package:fluent_ui/fluent_ui.dart';
import '../../core/theme/ket_theme.dart';
import '../../core/services/terminal_service.dart';
import '../../core/services/execution_service.dart';
import '../../core/services/layout_service.dart';

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
      // Using jumpTo instead of animateTo for performance during high-volume output
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

      Future.delayed(const Duration(milliseconds: 50), () {
        _isScrollThrottled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TerminalService(),
      builder: (context, _) {
        // Only trigger scroll if terminal panel is visible and active
        if (widget.layout.isBottomPanelVisible) {
          _scrollToBottom();
        }

        return Container(
          color: KetTheme.bgCanvas,
          child: Column(
            children: [
              // HEADER
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.black)),
                  color: KetTheme.bgSidebar,
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.command_prompt,
                      size: 12,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text("TERMINAL", style: KetTheme.headerStyle),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(FluentIcons.delete),
                      onPressed: () => TerminalService().clear(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(FluentIcons.chrome_close),
                      onPressed: () => widget.layout.toggleBottomPanel(),
                    ),
                  ],
                ),
              ),

              // LOGS
              Expanded(
                child: SelectionArea(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: TerminalService().logs.length,
                    itemBuilder: (context, index) {
                      final log = TerminalService().logs[index];
                      return Text(
                        log,
                        style: TextStyle(
                          color: log.startsWith('⚠️') || log.startsWith('❌')
                              ? Colors.red
                              : KetTheme.textMain,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.3,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // INPUT
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.black)),
                  color: KetTheme.bgSidebar,
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.chevron_right,
                      color: Colors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextBox(
                        controller: _inputController,
                        focusNode: _focusNode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Consolas',
                          fontSize: 13,
                        ),
                        cursorColor: Colors.green,
                        placeholder: "Python buyrug'ini yozing...",
                        placeholderStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                        decoration: WidgetStateProperty.all(
                          const BoxDecoration(),
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
        );
      },
    );
  }
}
