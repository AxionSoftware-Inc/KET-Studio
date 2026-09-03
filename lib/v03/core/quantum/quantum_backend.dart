import 'dart:async';

/// Provider-neutral quantum execution contract.
///
/// KET Studio must never expose vendor SDK objects across this boundary.
/// Adapters translate Qiskit, PennyLane, Cirq, Braket, or future providers
/// into these stable domain types.
abstract interface class QuantumBackend {
  String get id;
  String get displayName;

  Future<QuantumBackendCapabilities> capabilities();
  Future<List<QuantumTarget>> listTargets();
  Future<QuantumJob> submit(QuantumExecutionRequest request);
  Future<QuantumJobSnapshot> getJob(String jobId);
  Stream<QuantumJobSnapshot> watchJob(String jobId);
  Future<void> cancelJob(String jobId);
}

final class QuantumBackendCapabilities {
  const QuantumBackendCapabilities({
    required this.supportsSimulator,
    required this.supportsHardware,
    required this.supportsStatevector,
    required this.supportsDensityMatrix,
    required this.supportsNoiseModels,
    required this.supportsOpenQasm3,
    required this.supportsParameterizedCircuits,
    required this.supportsRemoteJobs,
  });

  final bool supportsSimulator;
  final bool supportsHardware;
  final bool supportsStatevector;
  final bool supportsDensityMatrix;
  final bool supportsNoiseModels;
  final bool supportsOpenQasm3;
  final bool supportsParameterizedCircuits;
  final bool supportsRemoteJobs;
}

final class QuantumTarget {
  const QuantumTarget({
    required this.id,
    required this.name,
    required this.qubitCount,
    required this.isSimulator,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String name;
  final int qubitCount;
  final bool isSimulator;
  final Map<String, Object?> metadata;
}

enum QuantumProgramFormat { openQasm3, ketIr }

final class QuantumExecutionRequest {
  const QuantumExecutionRequest({
    required this.targetId,
    required this.program,
    required this.format,
    this.shots = 1024,
    this.seed,
    this.parameters = const <String, double>{},
    this.options = const <String, Object?>{},
  }) : assert(shots > 0);

  final String targetId;
  final String program;
  final QuantumProgramFormat format;
  final int shots;
  final int? seed;
  final Map<String, double> parameters;
  final Map<String, Object?> options;
}

abstract interface class QuantumJob {
  String get id;
  Future<QuantumJobSnapshot> get completion;
  Stream<QuantumJobSnapshot> get updates;
  Future<void> cancel();
}

enum QuantumJobState {
  queued,
  running,
  succeeded,
  failed,
  cancelled,
}

final class QuantumJobSnapshot {
  const QuantumJobSnapshot({
    required this.id,
    required this.backendId,
    required this.targetId,
    required this.state,
    required this.updatedAt,
    this.result,
    this.errorMessage,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String backendId;
  final String targetId;
  final QuantumJobState state;
  final DateTime updatedAt;
  final QuantumResult? result;
  final String? errorMessage;
  final Map<String, Object?> metadata;
}

final class QuantumResult {
  const QuantumResult({
    this.counts = const <String, int>{},
    this.probabilities = const <String, double>{},
    this.statevector,
    this.densityMatrix,
    this.metadata = const <String, Object?>{},
  });

  final Map<String, int> counts;
  final Map<String, double> probabilities;
  final List<ComplexValue>? statevector;
  final List<List<ComplexValue>>? densityMatrix;
  final Map<String, Object?> metadata;
}

final class ComplexValue {
  const ComplexValue(this.real, this.imaginary);

  final double real;
  final double imaginary;
}
