import 'dart:async';
import 'dart:math' as math;

import '../../core/quantum/ket_ir.dart';
import '../../core/quantum/noise_model.dart';
import '../../core/quantum/quantum_backend.dart';
import 'local_statevector_backend.dart';
import 'openqasm3_codec.dart';

final class LocalDensityMatrixBackend implements QuantumBackend {
  LocalDensityMatrixBackend({
    OpenQasm3Codec? openQasm3Codec,
    KetIrCodec? ketIrCodec,
    this.maxQubits = 8,
  })  : _openQasm3 = openQasm3Codec ?? const OpenQasm3CodecImpl(),
        _ketIr = ketIrCodec ?? const KetJsonCodec(),
        _pure = LocalStatevectorBackend(
          openQasm3Codec: openQasm3Codec,
          ketIrCodec: ketIrCodec,
          maxQubits: maxQubits,
        );

  final OpenQasm3Codec _openQasm3;
  final KetIrCodec _ketIr;
  final LocalStatevectorBackend _pure;
  final int maxQubits;
  final Map<String, _DensityJob> _jobs = <String, _DensityJob>{};
  var _counter = 0;

  @override
  String get id => 'ket.local.density-matrix';

  @override
  String get displayName => 'KET Local Density Matrix';

  @override
  Future<QuantumBackendCapabilities> capabilities() async =>
      const QuantumBackendCapabilities(
        supportsSimulator: true,
        supportsHardware: false,
        supportsStatevector: false,
        supportsDensityMatrix: true,
        supportsNoiseModels: true,
        supportsOpenQasm3: true,
        supportsParameterizedCircuits: true,
        supportsRemoteJobs: false,
      );

  @override
  Future<List<QuantumTarget>> listTargets() async => <QuantumTarget>[
        QuantumTarget(
          id: 'local-density-matrix',
          name: 'Local density matrix + noise',
          qubitCount: maxQubits,
          isSimulator: true,
          metadata: const <String, Object?>{
            'noise': <String>['depolarizing', 'readout'],
            'relaxation': false,
          },
        ),
      ];

  @override
  Future<QuantumJob> submit(QuantumExecutionRequest request) async {
    if (request.targetId != 'local-density-matrix') {
      throw ArgumentError.value(request.targetId, 'targetId', 'Unknown density-matrix target');
    }
    final circuit = switch (request.format) {
      QuantumProgramFormat.openQasm3 => _openQasm3.decode(request.program),
      QuantumProgramFormat.ketIr => _ketIr.decode(request.program),
    };
    if (circuit.qubitCount > maxQubits) {
      throw LocalQuantumLimitException(
        'Density-matrix simulation is capped at $maxQubits qubits; received ${circuit.qubitCount}.',
      );
    }
    final noise = _noiseFrom(request.options['noise']);
    if (noise.relaxation.isNotEmpty) {
      throw UnsupportedError(
        'T1/T2 relaxation is not implemented in the v0.3 local density-matrix engine yet.',
      );
    }
    final id = 'density-${DateTime.now().microsecondsSinceEpoch}-${++_counter}';
    final job = _DensityJob(
      id: id,
      request: request,
      circuit: circuit,
      noise: noise,
      pureBackend: _pure,
      codec: _openQasm3,
    );
    _jobs[id] = job;
    unawaited(job.start());
    return job;
  }

  @override
  Future<QuantumJobSnapshot> getJob(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) throw StateError('Unknown density-matrix job: $jobId');
    return job.snapshot;
  }

  @override
  Stream<QuantumJobSnapshot> watchJob(String jobId) {
    final job = _jobs[jobId];
    if (job == null) return Stream<QuantumJobSnapshot>.error(StateError('Unknown job: $jobId'));
    return job.updates;
  }

  @override
  Future<void> cancelJob(String jobId) async => _jobs[jobId]?.cancel();

  NoiseModel _noiseFrom(Object? raw) {
    if (raw == null) return const NoiseModel();
    if (raw is NoiseModel) return raw;
    if (raw is! Map) throw ArgumentError('noise option must be a NoiseModel or object.');
    final map = Map<String, Object?>.from(raw);
    final depolarizing = <DepolarizingNoise>[];
    final readout = <ReadoutNoise>[];
    final relaxation = <RelaxationNoise>[];
    for (final item in (map['depolarizing'] as List? ?? const <Object?>[])) {
      if (item is! Map) continue;
      final value = Map<String, Object?>.from(item);
      depolarizing.add(DepolarizingNoise(
        qubits: (value['qubits'] as List).cast<int>(),
        probability: (value['probability'] as num).toDouble(),
      ));
    }
    for (final item in (map['readout'] as List? ?? const <Object?>[])) {
      if (item is! Map) continue;
      final value = Map<String, Object?>.from(item);
      readout.add(ReadoutNoise(
        qubit: value['qubit'] as int,
        p0To1: (value['p0To1'] as num).toDouble(),
        p1To0: (value['p1To0'] as num).toDouble(),
      ));
    }
    for (final item in (map['relaxation'] as List? ?? const <Object?>[])) {
      if (item is! Map) continue;
      final value = Map<String, Object?>.from(item);
      relaxation.add(RelaxationNoise(
        qubit: value['qubit'] as int,
        t1Microseconds: (value['t1Microseconds'] as num).toDouble(),
        t2Microseconds: (value['t2Microseconds'] as num).toDouble(),
        gateTimeNanoseconds: (value['gateTimeNanoseconds'] as num?)?.toDouble(),
      ));
    }
    return NoiseModel(
      depolarizing: depolarizing,
      readout: readout,
      relaxation: relaxation,
    );
  }
}

final class _DensityJob implements QuantumJob {
  _DensityJob({
    required this.id,
    required this.request,
    required this.circuit,
    required this.noise,
    required this.pureBackend,
    required this.codec,
  }) : _snapshot = QuantumJobSnapshot(
          id: id,
          backendId: 'ket.local.density-matrix',
          targetId: 'local-density-matrix',
          state: QuantumJobState.queued,
          updatedAt: DateTime.now().toUtc(),
        );

  @override
  final String id;
  final QuantumExecutionRequest request;
  final KetCircuit circuit;
  final NoiseModel noise;
  final LocalStatevectorBackend pureBackend;
  final OpenQasm3Codec codec;
  final StreamController<QuantumJobSnapshot> _updates =
      StreamController<QuantumJobSnapshot>.broadcast(sync: true);
  final Completer<QuantumJobSnapshot> _completion = Completer<QuantumJobSnapshot>();
  QuantumJobSnapshot _snapshot;
  QuantumJob? _pureJob;
  bool _cancelled = false;

  QuantumJobSnapshot get snapshot => _snapshot;

  @override
  Stream<QuantumJobSnapshot> get updates => _updates.stream;

  @override
  Future<QuantumJobSnapshot> get completion => _completion.future;

  Future<void> start() async {
    _emit(QuantumJobState.running);
    try {
      _pureJob = await pureBackend.submit(QuantumExecutionRequest(
        targetId: 'local-statevector',
        program: codec.encode(circuit),
        format: QuantumProgramFormat.openQasm3,
        shots: 1,
        seed: request.seed,
        parameters: request.parameters,
      ));
      final pureSnapshot = await _pureJob!.completion;
      if (_cancelled) return;
      final state = pureSnapshot.result?.statevector;
      if (state == null) throw StateError('Pure backend did not return a statevector.');
      var density = _outerProduct(state);
      for (final channel in noise.depolarizing) {
        for (final qubit in channel.qubits) {
          density = _depolarize(density, qubit, channel.probability);
        }
      }
      final probabilities = _diagonalProbabilities(density, circuit.qubitCount);
      final counts = _sample(probabilities, request.shots, request.seed, circuit, noise.readout);
      _snapshot = QuantumJobSnapshot(
        id: id,
        backendId: 'ket.local.density-matrix',
        targetId: 'local-density-matrix',
        state: QuantumJobState.succeeded,
        updatedAt: DateTime.now().toUtc(),
        result: QuantumResult(
          counts: counts,
          probabilities: probabilities,
          densityMatrix: density,
          metadata: <String, Object?>{
            'mixedState': noise.depolarizing.isNotEmpty,
            'depolarizingChannels': noise.depolarizing.length,
            'readoutChannels': noise.readout.length,
          },
        ),
      );
      _publish();
      if (!_completion.isCompleted) _completion.complete(_snapshot);
    } catch (error) {
      if (_cancelled) return;
      _snapshot = QuantumJobSnapshot(
        id: id,
        backendId: 'ket.local.density-matrix',
        targetId: 'local-density-matrix',
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
    if (_completion.isCompleted || _cancelled) return;
    _cancelled = true;
    await _pureJob?.cancel();
    _snapshot = QuantumJobSnapshot(
      id: id,
      backendId: 'ket.local.density-matrix',
      targetId: 'local-density-matrix',
      state: QuantumJobState.cancelled,
      updatedAt: DateTime.now().toUtc(),
    );
    _publish();
    if (!_completion.isCompleted) _completion.complete(_snapshot);
  }

  void _emit(QuantumJobState state) {
    _snapshot = QuantumJobSnapshot(
      id: id,
      backendId: 'ket.local.density-matrix',
      targetId: 'local-density-matrix',
      state: state,
      updatedAt: DateTime.now().toUtc(),
    );
    _publish();
  }

  void _publish() {
    if (!_updates.isClosed) _updates.add(_snapshot);
  }
}

List<List<ComplexValue>> _outerProduct(List<ComplexValue> state) => <List<ComplexValue>>[
      for (final a in state)
        <ComplexValue>[
          for (final b in state)
            ComplexValue(
              a.real * b.real + a.imaginary * b.imaginary,
              a.imaginary * b.real - a.real * b.imaginary,
            ),
        ],
    ];

List<List<ComplexValue>> _depolarize(
  List<List<ComplexValue>> rho,
  int qubit,
  double probability,
) {
  if (probability <= 0) return rho;
  final x = _pauliConjugate(rho, qubit, 'x');
  final y = _pauliConjugate(rho, qubit, 'y');
  final z = _pauliConjugate(rho, qubit, 'z');
  final weight = probability / 3;
  return <List<ComplexValue>>[
    for (var i = 0; i < rho.length; i++)
      <ComplexValue>[
        for (var j = 0; j < rho.length; j++)
          ComplexValue(
            (1 - probability) * rho[i][j].real +
                weight * (x[i][j].real + y[i][j].real + z[i][j].real),
            (1 - probability) * rho[i][j].imaginary +
                weight * (x[i][j].imaginary + y[i][j].imaginary + z[i][j].imaginary),
          ),
      ],
  ];
}

List<List<ComplexValue>> _pauliConjugate(
  List<List<ComplexValue>> rho,
  int qubit,
  String pauli,
) {
  final mask = 1 << qubit;
  final size = rho.length;
  return <List<ComplexValue>>[
    for (var i = 0; i < size; i++)
      <ComplexValue>[
        for (var j = 0; j < size; j++) _pauliElement(rho, i, j, mask, pauli),
      ],
  ];
}

ComplexValue _pauliElement(
  List<List<ComplexValue>> rho,
  int i,
  int j,
  int mask,
  String pauli,
) {
  if (pauli == 'z') {
    final sign = (((i & mask) == 0) == ((j & mask) == 0)) ? 1.0 : -1.0;
    final value = rho[i][j];
    return ComplexValue(sign * value.real, sign * value.imaginary);
  }
  final sourceI = i ^ mask;
  final sourceJ = j ^ mask;
  final value = rho[sourceI][sourceJ];
  if (pauli == 'x') return value;
  final phaseI = (sourceI & mask) == 0 ? const ComplexValue(0, 1) : const ComplexValue(0, -1);
  final phaseJ = (sourceJ & mask) == 0 ? const ComplexValue(0, 1) : const ComplexValue(0, -1);
  return _multiply(_multiply(phaseI, value), ComplexValue(phaseJ.real, -phaseJ.imaginary));
}

ComplexValue _multiply(ComplexValue a, ComplexValue b) => ComplexValue(
      a.real * b.real - a.imaginary * b.imaginary,
      a.real * b.imaginary + a.imaginary * b.real,
    );

Map<String, double> _diagonalProbabilities(List<List<ComplexValue>> rho, int qubits) {
  final result = <String, double>{};
  for (var i = 0; i < rho.length; i++) {
    final p = rho[i][i].real.clamp(0.0, 1.0).toDouble();
    if (p > 1e-14) result[i.toRadixString(2).padLeft(qubits, '0')] = p;
  }
  final sum = result.values.fold<double>(0, (a, b) => a + b);
  if ((sum - 1).abs() > 1e-7) throw StateError('Density matrix trace is not one: $sum');
  return result;
}

Map<String, int> _sample(
  Map<String, double> probabilities,
  int shots,
  int? seed,
  KetCircuit circuit,
  List<ReadoutNoise> readout,
) {
  final rng = math.Random(seed);
  final entries = probabilities.entries.toList(growable: false);
  final cumulative = <double>[];
  var sum = 0.0;
  for (final entry in entries) {
    sum += entry.value;
    cumulative.add(sum);
  }
  final counts = <String, int>{};
  final noiseByQubit = <int, ReadoutNoise>{for (final item in readout) item.qubit: item};
  final measurements = circuit.operations.whereType<KetMeasure>().toList(growable: false);
  for (var shot = 0; shot < shots; shot++) {
    final r = rng.nextDouble() * sum;
    var selected = entries.length - 1;
    for (var i = 0; i < cumulative.length; i++) {
      if (r < cumulative[i]) {
        selected = i;
        break;
      }
    }
    final basis = int.parse(entries[selected].key, radix: 2);
    if (measurements.isEmpty || circuit.classicalBitCount == 0) {
      final key = entries[selected].key;
      counts[key] = (counts[key] ?? 0) + 1;
      continue;
    }
    final bits = List<int>.filled(circuit.classicalBitCount, 0);
    for (final measurement in measurements) {
      var bit = (basis >> measurement.qubit) & 1;
      final noise = noiseByQubit[measurement.qubit];
      if (noise != null) {
        final probability = bit == 0 ? noise.p0To1 : noise.p1To0;
        if (rng.nextDouble() < probability) bit = 1 - bit;
      }
      bits[measurement.classicalBit] = bit;
    }
    final key = <int>[for (var i = bits.length - 1; i >= 0; i--) bits[i]].join();
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

void unawaited(Future<void> future) {}
