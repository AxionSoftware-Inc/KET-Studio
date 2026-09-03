import 'dart:typed_data';

final class TerminalSize {
  const TerminalSize({required this.columns, required this.rows})
      : assert(columns > 0),
        assert(rows > 0);

  final int columns;
  final int rows;
}

final class TerminalLaunchRequest {
  const TerminalLaunchRequest({
    required this.executable,
    this.arguments = const <String>[],
    this.workingDirectory,
    this.environment = const <String, String>{},
    this.initialSize = const TerminalSize(columns: 120, rows: 32),
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final TerminalSize initialSize;
}

abstract interface class TerminalSession {
  String get id;
  Stream<Uint8List> get output;
  Future<int> get exitCode;

  Future<void> write(Uint8List bytes);
  Future<void> resize(TerminalSize size);
  Future<void> interrupt();
  Future<void> terminate({bool force = false});
  Future<void> dispose();
}

/// Native implementations must use ConPTY on Windows and a POSIX PTY on
/// Linux/macOS. Redirected stdio is explicitly not considered a terminal.
abstract interface class TerminalHost {
  Future<TerminalSession> open(TerminalLaunchRequest request);
}
