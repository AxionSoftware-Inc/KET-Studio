import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import '../../core/services/editor_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/ket_theme.dart';
import '../welcome/welcome_widget.dart';

class EditorWidget extends StatefulWidget {
  const EditorWidget({super.key});

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  final EditorService _editorService = EditorService();
  CodeController? _currentController;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _editorService.addListener(_update);
    SettingsService().addListener(_update);
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _currentController?.removeListener(_updateCursor);
    _editorService.removeListener(_update);
    SettingsService().removeListener(_update);
    super.dispose();
  }

  void _update() {
    final newActive = _editorService.activeFile;
    if (_currentController != newActive?.controller) {
      _currentController?.removeListener(_updateCursor);
      _currentController = newActive?.controller;
      _currentController?.addListener(_updateCursor);
    }
    if (mounted) setState(() {});
  }

  void _updateCursor() {
    _cursorTimer?.cancel();
    _cursorTimer = Timer(const Duration(milliseconds: 50), () {
      final active = _editorService.activeFile;
      if (active == null) return;

      final sel = active.controller.selection;
      if (!sel.isValid || !sel.isCollapsed) return;

      final text = active.controller.text;
      final offset = sel.baseOffset.clamp(0, text.length);

      // Column: count characters after last newline
      final lastNl = text.lastIndexOf('\n', offset == 0 ? 0 : offset - 1);
      final col = offset - (lastNl + 1) + 1;

      // Line: count newlines without string split (allocation-free)
      int line = 1;
      for (int i = 0; i < offset; i++) {
        if (text.codeUnitAt(i) == 10) line++; // ASCII 10 = '\n'
      }

      _editorService.updateCursorPosition(line, col);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    if (_editorService.files.isEmpty) {
      return const WelcomeWidget();
    }

    final activeFile = _editorService.activeFile!;

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
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: KetTheme.bgHeader,
                border: Border(bottom: BorderSide(color: KetTheme.border)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _editorService.files.length,
                itemBuilder: (context, index) {
                  final file = _editorService.files[index];
                  final isActive = index == _editorService.activeFileIndex;

                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: HoverButton(
                      onPressed: () => _editorService.setActiveIndex(index),
                      builder: (context, states) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? KetTheme.bgSelected
                                : (states.isHovered
                                      ? KetTheme.bgHover
                                      : Colors.transparent),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive
                                  ? KetTheme.accent.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                file.name.endsWith('.py')
                                    ? FluentIcons.code
                                    : FluentIcons.page_list,
                                size: 12,
                                color: isActive
                                    ? KetTheme.accent
                                    : KetTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                file.name,
                                style: KetTheme.bodyStyle.copyWith(
                                  color: isActive
                                      ? KetTheme.textMain
                                      : KetTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                              if (file.isModified) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: KetTheme.accent,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              HoverButton(
                                onPressed: () =>
                                    _editorService.closeFile(index),
                                builder: (context, closeStates) {
                                  return Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: closeStates.isHovered
                                          ? KetTheme.danger.withValues(
                                              alpha: 0.15,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Icon(
                                      FluentIcons.chrome_close,
                                      size: 8,
                                      color: closeStates.isHovered
                                          ? KetTheme.danger
                                          : KetTheme.textMuted,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: m.Material(
                type: m.MaterialType.transparency,
                child: CodeTheme(
                  data: CodeThemeData(styles: monokaiSublimeTheme),
                  child: CodeField(
                    controller: activeFile.controller,
                    textStyle: TextStyle(
                      fontFamily: KetTheme.isWindowsDesktop
                          ? 'Cascadia Mono'
                          : 'monospace',
                      fontSize: settings.fontSize,
                      height: settings.editorLineHeight,
                      color: KetTheme.textMain,
                    ),
                    expands: true,
                    wrap: settings.editorWordWrap,
                    background: KetTheme.bgCanvas.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
