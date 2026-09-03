import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/experiments/experiment_record.dart';
import '../../core/quantum/ket_ir.dart';
import '../../core/quantum/quantum_backend.dart';
import '../../core/quantum/quantum_debugger.dart';
import '../../infrastructure/experiments/file_experiment_store.dart';

final class QuantumExecutionReport {
  const QuantumExecutionReport({
    required this.circuit,
    required this.job,
    required this.result,
    required this.record,
    required this.debugSnapshot,
  });

  final KetCircuit circuit;
  final QuantumJobSnapshot job;
  final QuantumResult result;
  final ExperimentRecord record;
  final QuantumDebugSnapshot debugSnapshot;
}

final class QuantumExecutionService {
  QuantumExecutionService({
    required OpenQasm3Codec openQasm3Codec,
    required QuantumBackend backend,
    required QuantumDebugger debugger,
    required FileExperimentStore experimentStore,
  })  : _openQasm3Codec = openQasm3Codec,
        _defaultBackend = backend,
        _debugger = debugger,
        _experimentStore = experimentStore;

  final OpenQasm3Codec _openQasm3Codec;
  final QuantumBackend _defaultBackend;
  final QuantumDebugger _debugger;
  final FileExperimentStore _experimentStore;

  QuantumJob? _activeJob;
  QuantumDebugSession? _debugSession;

  QuantumJob? get activeJob => _activeJob;
  QuantumDebugSession? get debugSession => _debugSession;

  Future<QuantumExecutionReport> runOpenQasm({
    required String source,
    required String projectId,
    QuantumBackend? backend,
    String targetId = 'local-statevector',
    int shots = 1024,
    int? seed,
    Map<String, double> parameters = const <String, double>{},
    Map<String, Object?> options = const <String, Object?>{},
  }) async {
    final circuit = _openQasm3Codec.decode(source);
    final canonical = _openQasm3Codec.encode(circuit);
    final selectedBackend = backend ?? _defaultBackend;
    final job = await selectedBackend.submit(QuantumExecutionRequest(
      targetId: targetId,
      program: canonical,
      format: QuantumProgramFormat.openQasm3,
      shots: shots,
      seed: seed,
      parameters: parameters,
      options: options,
    ));
    _activeJob = job;
    final snapshot = await job.completion;
    if (snapshot.state != QuantumJobState.succeeded || snapshot.result == null) {
      throw StateError(snapshot.errorMessage ?? 'Quantum execution did not succeed.');
    }
    final result = snapshot.result!;

    final recordId = 'exp-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final resultArtifact = await _experimentStore.persistJsonArtifact(
      recordId: recordId,
      kind: 'quantum-result',
      value: _encodeResult(result),
    );
    final circuitArtifact = await _experimentStore.persistJsonArtifact(
      recordId: recordId,
      kind: 'canonical-openqasm3',
      value: <String, Object?>{'source': canonical},
    );
    final record = ExperimentRecord(
      id: recordId,
      createdAt: DateTime.now().toUtc(),
      projectId: projectId,
      sourceRevision: sha256.convert(utf8.encode(canonical)).toString(),
      environmentFingerprint: _environmentFingerprint(),
      backendId: snapshot.backendId,
      targetId: snapshot.targetId,
      programFormat: QuantumProgramFormat.openQasm3,
      shots: shots,
      seed: seed,
      parameters: parameters,
      dependencies: <String, String>{
        'ket-protocol': '1',
        'execution-backend': snapshot.backendId,
      },
      backendMetadata: <String, Object?>{
        ...snapshot.metadata,
        if (options.isNotEmpty) 'executionOptions': _jsonSafe(options),
      },
      artifacts: <ExperimentArtifact>[resultArtifact, circuitArtifact],
    );
    await _experimentStore.save(record);

    await _debugSession?.dispose();
    final debug = await _debugger.start(QuantumDebugRequest(
      circuit: circuit,
      parameters: parameters,
    ));
    _debugSession = debug;
    final debugSnapshot = await debug.current();

    return QuantumExecutionReport(
      circuit: circuit,
      job: snapshot,
      result: result,
      record: record,
      debugSnapshot: debugSnapshot,
    );
  }

  Future<QuantumDebugSnapshot> stepForward() async {
    final session = _debugSession;
    if (session == null) throw StateError('No active quantum debug session.');
    return session.stepForward();
  }

  Future<QuantumDebugSnapshot> stepBackward() async {
    final session = _debugSession;
    if (session == null) throw StateError('No active quantum debug session.');
    return session.stepBackward();
  }

  Future<QuantumDebugSnapshot> seek(int operationIndex) async {
    final session = _debugSession;
    if (session == null) throw StateError('No active quantum debug session.');
    return session.seek(operationIndex);
  }

  Future<void> cancel() async {
    await _activeJob?.cancel();
  }

  Map<String, Object?> _encodeResult(QuantumResult result) => <String, Object?>{
        'counts': result.counts,
        'probabilities': result.probabilities,
        'statevector': result.statevector
            ?.map((value) => <double>[value.real, value.imaginary])
            .toList(),
        'densityMatrix': result.densityMatrix
            ?.map(
              (row) => row
                  .map((value) => <double>[value.real, value.imaginary])
                  .toList(),
            )
            .toList(),
        'metadata': result.metadata,
      };

  Object? _jsonSafe(Object? value) {
    if (value == null || value is String || value is num || value is bool) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', _jsonSafe(item)));
    }
    if (value is Iterable) return value.map(_jsonSafe).toList(growable: false);
    return '$value';
  }

  String _environmentFingerprint() {
    final source = <String>[
      Platform.operatingSystem,
      Platform.operatingSystemVersion,
      Platform.version,
      Platform.resolvedExecutable,
    ].join('|');
    return sha256.convert(utf8.encode(source)).toString();
  }

  Future<void> dispose() async {
    await _debugSession?.dispose();
    _debugSession = null;
    await _experimentStore.dispose();
  }
}
