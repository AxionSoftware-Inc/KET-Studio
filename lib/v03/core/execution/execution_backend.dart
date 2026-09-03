import '../protocol/ket_event.dart';

final class ExecutionRequest {
  const ExecutionRequest({
    required this.entrypoint,
    this.arguments = const <String>[],
    this.workingDirectory,
    this.environment = const <String, String>{},
  });

  final String entrypoint;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
}

abstract interface class ExecutionHandle {
  String get id;
  Stream<KetEvent> get events;
  Future<int> get exitCode;

  Future<void> interrupt();
  Future<void> stop({bool force = false});
  Future<void> dispose();
}

abstract interface class ExecutionBackend {
  Future<ExecutionHandle> start(ExecutionRequest request);
}
