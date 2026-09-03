import '../protocol/ket_event.dart';

enum KernelState {
  created,
  starting,
  idle,
  busy,
  restarting,
  stopping,
  stopped,
  failed,
}

final class KernelLaunchRequest {
  const KernelLaunchRequest({
    required this.interpreter,
    this.workingDirectory,
    this.environment = const <String, String>{},
    this.arguments = const <String>[],
  });

  final String interpreter;
  final String? workingDirectory;
  final Map<String, String> environment;
  final List<String> arguments;
}

final class KernelExecutionRequest {
  const KernelExecutionRequest({
    required this.code,
    required this.executionId,
    this.fileName,
    this.metadata = const <String, Object?>{},
  });

  final String code;
  final String executionId;
  final String? fileName;
  final Map<String, Object?> metadata;
}

abstract interface class KernelSession {
  String get id;
  KernelState get state;
  Stream<KetEvent> get events;

  Future<void> execute(KernelExecutionRequest request);
  Future<void> provideInput(String value);
  Future<void> interrupt();
  Future<void> restart();
  Future<void> shutdown({bool force = false});
  Future<void> dispose();
}

abstract interface class KernelHost {
  Future<KernelSession> launch(KernelLaunchRequest request);
}
