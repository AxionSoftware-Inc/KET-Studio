final class SourceBreakpoint {
  const SourceBreakpoint({required this.line, this.condition});
  final int line;
  final String? condition;
}

final class DebugStackFrame {
  const DebugStackFrame({
    required this.id,
    required this.name,
    required this.line,
    this.sourcePath,
  });

  final int id;
  final String name;
  final int line;
  final String? sourcePath;
}

final class DebugVariable {
  const DebugVariable({
    required this.name,
    required this.value,
    this.type,
    this.variablesReference = 0,
  });

  final String name;
  final String value;
  final String? type;
  final int variablesReference;
}

abstract interface class DebugSession {
  Stream<String> get output;
  Stream<DebugStackFrame> get stoppedFrames;

  Future<void> setBreakpoints(String sourcePath, List<SourceBreakpoint> points);
  Future<void> continueExecution();
  Future<void> pause();
  Future<void> stepOver();
  Future<void> stepInto();
  Future<void> stepOut();
  Future<List<DebugStackFrame>> stackTrace();
  Future<List<DebugVariable>> variables(int variablesReference);
  Future<String> evaluate(String expression, {int? frameId});
  Future<void> terminate();
  Future<void> dispose();
}

abstract interface class DebugAdapterHost {
  Future<DebugSession> launch({
    required String adapterExecutable,
    required String program,
    List<String> adapterArguments = const <String>[],
    List<String> programArguments = const <String>[],
    String? workingDirectory,
    Map<String, String> environment = const <String, String>{},
  });
}
