final class TextPosition {
  const TextPosition(this.line, this.character);
  final int line;
  final int character;
}

final class TextRange {
  const TextRange(this.start, this.end);
  final TextPosition start;
  final TextPosition end;
}

enum DiagnosticSeverity { error, warning, information, hint }

final class LanguageDiagnostic {
  const LanguageDiagnostic({
    required this.range,
    required this.message,
    required this.severity,
    this.source,
    this.code,
  });

  final TextRange range;
  final String message;
  final DiagnosticSeverity severity;
  final String? source;
  final String? code;
}

final class CompletionEntry {
  const CompletionEntry({
    required this.label,
    this.detail,
    this.insertText,
    this.documentation,
  });

  final String label;
  final String? detail;
  final String? insertText;
  final String? documentation;
}

abstract interface class LanguageServiceSession {
  Stream<List<LanguageDiagnostic>> diagnosticsFor(Uri document);
  Future<List<CompletionEntry>> completion(Uri document, TextPosition position);
  Future<String?> hover(Uri document, TextPosition position);
  Future<Uri?> definition(Uri document, TextPosition position);
  Future<void> openDocument(Uri document, String text, int version);
  Future<void> changeDocument(Uri document, String text, int version);
  Future<void> closeDocument(Uri document);
  Future<void> dispose();
}

abstract interface class LanguageServiceHost {
  Future<LanguageServiceSession> start({
    required String languageId,
    required String executable,
    List<String> arguments = const <String>[],
    Uri? workspaceRoot,
  });
}
