import 'dart:async';
import 'dart:convert';

import '../../core/quantum/quantum_backend.dart';
import 'openqasm3_codec.dart';
import 'python_provider_bridge_client.dart';

final class PythonVendorBackend implements QuantumBackend {
  PythonVendorBackend({
    required this.vendor,
    required this.client,
    OpenQasm3Codec? openQasm3Codec,
    KetIrCodec? ketIrCodec,
  })  : _openQasm3 = openQasm3Codec ?? const OpenQasm3CodecImpl(),
        _ketIr = ketIrCodec ?? const KetJsonCodec();

  final String vendor;
  final PythonProviderBridgeClient client;
  final OpenQasm3Codec _openQasm3;
  final KetIrCodec _ketIr;
  final Map<String, _BridgeQuantumJob> _jobs = <String, _BridgeQuantumJob>{};
  int _counter = 0;

  @override
  String get id => 'ket.vendor.$vendor';

  @override
  String get displayName => switch (vendor) {
        'qiskit' => 'Qiskit',
        'pennylane' => 'PennyLane',
        'cirq' => 'Cirq',
        _ => vendor,
      };

  Future<ProviderProbe> _probe() async {
    final probes = await client.probe(vendor: vendor);
    if (probes.isEmpty || !probes.single.available) {
      throw ProviderBridgeException('$displayName is not installed in the selected Python environment.');
    }
    return probes.single;
  }

  @override
  Future<QuantumBackendCapabilities> capabilities() async {
    await _probe();
    return const QuantumBackendCapabilities(
      supportsSimulator: true,
      supportsHardware: false,
      supportsStatevector: true,
      supportsDensityMatrix: false,
      supportsNoiseModels: false,
      supportsOpenQasm3: true,
      supportsParameterizedCircuits: true,
      supportsRemoteJobs: false,
    );
  }

  @override
  Future<List<QuantumTarget>> listTargets() async {
    final probe = await _probe();
    return probe.targets.map((map) {
      return QuantumTarget(
        id: '${map['id'] ?? ''}',
        name: '${map['name'] ?? map['id'] ?? vendor}',
        qubitCount: map['qubitCount'] as int? ?? 0,
        isSimulator: map['isSimulator'] == true,
        metadata: map['metadata'] is Map
            ? <String, Object?>{
                ...Map<String, Object?>.from(map['metadata']! as Map),
                if (probe.version != null) 'vendorVersion': probe.version,
              }
            : <String, Object?>{
                if (probe.version != null) 'vendorVersion': probe.version,
              },
      );
    }).toList(growable: false);
  }

  @override
  Future<QuantumJob> submit(QuantumExecutionRequest request) async {
    final targetIds = (await listTargets()).map((target) => target.id).toSet();
    if (!targetIds.contains(request.targetId)) {
      throw ArgumentError.value(request.targetId, 'targetId', 'Unknown $displayName target');
    }
    final circuit = switch (request.format) {
      QuantumProgramFormat.openQasm3 => _openQasm3.decode(request.program),
      QuantumProgramFormat.ketIr => _ketIr.decode(request.program),
    };
    final ir = jsonDecode(_ketIr.encode(circuit));
    if (ir is! Map) throw StateError('KET IR encoder returned a non-object document.');

    final jobId = '$vendor-${DateTime.now().microsecondsSinceEpoch}-${++_counter}';
    final job = _BridgeQuantumJob(
      id: jobId,
      backendId: id,
      targetId: request.targetId,
      runner: () => client.request(<String, Object?>{
        'type': 'execute',
        'vendor': vendor,
        'targetId': request.targetId,
        'program': Map<String, Object?>.from(ir),
        'shots': request.shots,
        'seed': request.seed,
        'parameters': request.parameters,
      }, timeout: const Duration(minutes: 5)),
    );
    _jobs[jobId] = job;
    unawaited(job.start());
    return job;
  }

  @override
  Future<QuantumJobSnapshot> getJob(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) throw StateError('Unknown $displayName job: $jobId');
    return job.snapshot;
  }

  @override
  Stream<QuantumJobSnapshot> watchJob(String jobId) {
    final job = _jobs[jobId];
    if (job == null) return Stream<QuantumJobSnapshot>.error(StateError('Unknown job: $jobId'));
    return job.updates;
  }

  @override
  Future<void> cancelJob(String jobId) async {
    await _jobs[jobId]?.cancel();
  }
}

final class _BridgeQuantumJob implements QuantumJob {
  _BridgeQuantumJob({
    required this.id,
    required this.backendId,
    required this.targetId,
    required this.runner,
  }) : _snapshot = QuantumJobSnapshot(
          id: id,
          backendId: backendId,
          targetId: targetId,
          state: QuantumJobState.queued,
          updatedAt: DateTime.now().toUtc(),
        );

  @override
  final String id;
  final String backendId;
  final String targetId;
  final Future<Map<String, Object?>> Function() runner;

  final StreamController<QuantumJobSnapshot> _updates =
      StreamController<QuantumJobSnapshot>.broadcast(sync: true);
  final Completer<QuantumJobSnapshot> _completion = Completer<QuantumJobSnapshot>();
  QuantumJobSnapshot _snapshot;
  bool _cancelled = false;

  QuantumJobSnapshot get snapshot => _snapshot;

  @override
  Stream<QuantumJobSnapshot> get updates => _updates.stream;

  @override
  Future<QuantumJobSnapshot> get completion => _completion.future;

  Future<void> start() async {
    _emit(QuantumJobState.running);
    try {
      final response = await runner();
      if (_cancelled) return;
      final raw = response['result'];
      if (raw is! Map) throw const ProviderBridgeException('Execution result is malformed.');
      final resultMap = Map<String, Object?>.from(raw);
      final result = QuantumResult(
        counts: resultMap['counts'] is Map
            ? (resultMap['counts']! as Map).map((key, value) => MapEntry('$key', value as int))
            : const <String, int>{},
        probabilities: resultMap['probabilities'] is Map
            ? (resultMap['probabilities']! as Map)
                .map((key, value) => MapEntry('$key', (value as num).toDouble()))
            : const <String, double>{},
        statevector: resultMap['statevector'] is List
            ? (resultMap['statevector']! as List).map((pair) {
                final values = pair as List;
                return ComplexValue(
                  (values[0] as num).toDouble(),
                  (values[1] as num).toDouble(),
                );
              }).toList(growable: false)
            : null,
        metadata: resultMap['metadata'] is Map
            ? Map<String, Object?>.from(resultMap['metadata']! as Map)
            : const <String, Object?>{},
      );
      _snapshot = QuantumJobSnapshot(
        id: id,
        backendId: backendId,
        targetId: targetId,
        state: QuantumJobState.succeeded,
        updatedAt: DateTime.now().toUtc(),
        result: result,
        metadata: result.metadata,
      );
      _publish();
      if (!_completion.isCompleted) _completion.complete(_snapshot);
    } catch (error) {
      if (_cancelled) return;
      _snapshot = QuantumJobSnapshot(
        id: id,
        backendId: backendId,
        targetId: targetId,
        state: QuantumJobState.failed,
        updatedAt: DateTime.now().toUtc(),
        errorMessage: '$error',
      );
      _publish();
      if (!_completion.isCompleted) _completion.complete(_snapshot);
    }
  }

  @override
  Future<void> cancel() async {
    if (_cancelled || _completion.isCompleted) return;
    _cancelled = true;
    _snapshot = QuantumJobSnapshot(
      id: id,
      backendId: backendId,
      targetId: targetId,
      state: QuantumJobState.cancelled,
      updatedAt: DateTime.now().toUtc(),
      errorMessage: 'Cancellation is cooperative; vendor computation may finish in the bridge process.',
    );
    _publish();
    if (!_completion.isCompleted) _completion.complete(_snapshot);
  }

  void _emit(QuantumJobState state) {
    _snapshot = QuantumJobSnapshot(
      id: id,
      backendId: backendId,
      targetId: targetId,
      state: state,
      updatedAt: DateTime.now().toUtc(),
    );
    _publish();
  }

  void _publish() {
    if (!_updates.isClosed) _updates.add(_snapshot);
  }
}
