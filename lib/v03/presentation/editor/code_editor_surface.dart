import 'package:flutter/material.dart' as material;
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/highlight.dart' show Mode;
import 'package:highlight/languages/json.dart' as highlight_json;
import 'package:highlight/languages/python.dart' as highlight_python;

import '../../application/workbench_controller.dart';

final class CodeEditorSurface extends material.StatefulWidget {
  const CodeEditorSurface({
    super.key,
    required this.document,
    required this.onChanged,
  });

  final WorkbenchDocument document;
  final material.ValueChanged<String> onChanged;

  @override
  material.State<CodeEditorSurface> createState() => _CodeEditorSurfaceState();
}

final class _CodeEditorSurfaceState extends material.State<CodeEditorSurface> {
  late CodeController _controller;
  bool _replacing = false;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.document);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CodeEditorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _controller = _createController(widget.document);
      _controller.addListener(_onControllerChanged);
    } else if (_controller.fullText != widget.document.text) {
      _replacing = true;
      _controller.fullText = widget.document.text;
      _replacing = false;
    }
  }

  CodeController _createController(WorkbenchDocument document) {
    return CodeController(
      text: document.text,
      language: _language(document.languageId),
    );
  }

  Mode? _language(String languageId) => switch (languageId) {
        'python' => highlight_python.python,
        'json' => highlight_json.json,
        _ => null,
      };

  void _onControllerChanged() {
    if (_replacing) return;
    final value = _controller.fullText;
    if (value != widget.document.text) widget.onChanged(value);
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Material(
      color: const material.Color(0xFF0D1218),
      child: CodeTheme(
        data: CodeThemeData(styles: vs2015Theme),
        child: CodeField(
          controller: _controller,
          expands: true,
          wrap: false,
          textStyle: const material.TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.45,
          ),
          gutterStyle: const GutterStyle(
            showLineNumbers: true,
            showFoldingHandles: true,
            showErrors: false,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }
}
