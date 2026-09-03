import 'dart:async';
import 'dart:io';

import '../../core/language/language_services.dart';
import '../workbench_controller.dart';

final class EditorIntelligenceCoordinator {
  EditorIntelligenceCoordinator({
    required this.host,
    this.executable = 'pyright-langserver',
  });

  final LanguageServiceHost host;
  final String executable;

  LanguageServiceSession? _session;
  Uri? _workspaceRoot;
  Uri? _openDocument;
  StreamSubscription<List<LanguageDiagnostic>>? _diagnosticSubscription;
  Timer? _changeDebounce;
  bool _disabled = false;
  String? _disabledReason;

  bool get available => !_disabled;
  String? get unavailableReason => _disabledReason;

  Future<void> activate(
    WorkbenchDocument document, {
    required void Function(List<LanguageDiagnostic>) onDiagnostics,
  }) async {
    if (_disabled || document.languageId != 'python' || document.uri == null) return;
    final uri = document.uri!;
    final workspace = File(document.path!).parent.absolute.uri;
    try {
      if (_session == null || _workspaceRoot != workspace) {
        await _session?.dispose();
        _session = await host.start(
          languageId: 'python',
          executable: executable,
          workspaceRoot: workspace,
        );
        _workspaceRoot = workspace;
        _openDocument = null;
      }
      if (_openDocument != null && _openDocument != uri) {
        await _diagnosticSubscription?.cancel();
        await _session!.closeDocument(_openDocument!);
      }
      if (_openDocument != uri) {
        await _session!.openDocument(uri, document.text, document.version);
        _openDocument = uri;
        await _diagnosticSubscription?.cancel();
        _diagnosticSubscription = _session!.diagnosticsFor(uri).listen(onDiagnostics);
      }
    } on ProcessException catch (error) {
      _disable('Pyright could not start: ${error.message}');
    } catch (error) {
      _disable('Language service unavailable: $error');
    }
  }

  void scheduleChange(WorkbenchDocument document) {
    if (_disabled || _session == null || document.uri != _openDocument) return;
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 180), () {
      unawaited(_session!.changeDocument(
        document.uri!,
        document.text,
        document.version,
      ));
    });
  }

  Future<List<CompletionEntry>> completion(
    WorkbenchDocument document,
    TextPosition position,
  ) async {
    if (_session == null || document.uri != _openDocument) return const <CompletionEntry>[];
    return _session!.completion(document.uri!, position);
  }

  Future<String?> hover(WorkbenchDocument document, TextPosition position) async {
    if (_session == null || document.uri != _openDocument) return null;
    return _session!.hover(document.uri!, position);
  }

  void _disable(String reason) {
    _disabled = true;
    _disabledReason = reason;
  }

  Future<void> dispose() async {
    _changeDebounce?.cancel();
    await _diagnosticSubscription?.cancel();
    await _session?.dispose();
    _session = null;
  }
}

void unawaited(Future<void> future) {}
