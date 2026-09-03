import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import '../../core/quantum/ket_ir.dart';
import '../../core/quantum/quantum_backend.dart';
import '../../core/quantum/quantum_debugger.dart';
import 'openqasm3_codec.dart';

final class LocalQuantumLimitException implements Exception {
  const LocalQuantumLimitException(this.message);
  final String message;

  @override
  String toString() => 'LocalQuantumLimitException: $message';
}

final class LocalStatevectorBackend implements QuantumBackend {
  LocalStatevectorBackend({
    OpenQasm3Codec? openQasm3Codec,
    KetIrCodec? ketIrCodec,
    this.maxQubits = 16,
  })  : _openQasm3 = openQasm3Codec ?? const OpenQasm3CodecImpl(),
        _ketIr = ketIrCodec ?? const KetJsonCodec();

  final OpenQasm3Codec _openQasm3;
  final KetIrCodec _ketIr;
  final int maxQubits;
  final Map<String, _LocalQuantumJob> _jobs = <String, _LocalQuantumJob>{};
  var _jobCounter = 0;

  @override
  String get id => 'ket.local.statevector';

  @override
  String get displayName => 'KET Local Statevector';

  @override
  Future<QuantumBackendCapabilities> capabilities() async {
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
  Future<List<QuantumTarget>> listTargets() async => <QuantumTarget>[
        QuantumTarget(
          id: 'local-statevector',
          name: 'Local exact statevector',
          qubitCount: maxQubits,
          isSimulator: true,
          metadata: const <String, Object?>{
            'engine': 'ket-dart-statevector',
            'isolate': true,
          },
        ),
      ];

  @override
  Future<QuantumJob> submit(QuantumExecutionRequest request) async {
    if (request.targetId != 'local-statevector') {
      throw ArgumentError.value(request.targetId, 'targetId', 'Unknown local target');
    }
    final circuit = switch (request.format) {
      QuantumProgramFormat.openQasm3 => _openQasm3.decode(request.program),
      QuantumProgramFormat.ketIr => _ketIr.decode(request.program),
    };
    if (circuit.qubitCount > maxQubits) {
      throw LocalQuantumLimitException(
        'Local exact simulation is capped at $maxQubits qubits; '
        'received ${circuit.qubitCount}. Use a provider adapter for larger jobs.',
      );
    }

    final jobId = 'local-${DateTime.now().microsecondsSinceEpoch}-${++_jobCounter}';
    final payload = <String, Object?>{
      'circuit': _ketIr.encode(circuit),
      'shots': request.shots,
      'seed': request.seed,
      'parameters': request.parameters,
    };
    final job = _LocalQuantumJob(
      id: jobId,
      backendId: id,
      targetId: request.targetId,
      payload: payload,
    );
    _jobs[jobId] = job;
    unawaited(job.start().whenComplete(() {
      // Retain completed jobs for snapshot lookups during the application session.
    }));
    return job;
  }

  @override
  Future<QuantumJobSnapshot> getJob(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) throw StateError('Unknown local quantum job: $jobId');
    return job.snapshot;
  }

  @override
  Stream<QuantumJobSnapshot> watchJob(String jobId) {
    final job = _jobs[jobId];
    if (job == null) return Stream<QuantumJobSnapshot>.error(
      StateError('Unknown local quantum job: $jobId'),
    );
    return job.updates;
  }

  @override
  Future<void> cancelJob(String jobId) async {
    final job = _jobs[jobId];
    if (job != null) await job.cancel();
  }
}

final class _LocalQuantumJob implements QuantumJob {
  _LocalQuantumJob({
    required this.id,
    required this.backendId,
    required this.targetId,
    required this.payload,
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
  final Map<String, Object?> payload;

  final StreamController<QuantumJobSnapshot> _updates =
      StreamController<QuantumJobSnapshot>.broadcast(sync: true);
  final Completer<QuantumJobSnapshot> _completion = Completer<QuantumJobSnapshot>();
  QuantumJobSnapshot _snapshot;
  Isolate? _isolate;
  ReceivePort? _port;
  bool _cancelled = false;

  QuantumJobSnapshot get snapshot => _snapshot;

  @override
  Stream<QuantumJobSnapshot> get updates => _updates.stream;

  @override
  Future<QuantumJobSnapshot> get completion => _completion.future;

  Future<void> start() async {
    if (_cancelled) return;
    _emit(QuantumJobState.running);
    final port = ReceivePort();
    _port = port;
    try {
      _isolate = await Isolate.spawn<List<Object?>>(
        _localSimulationWorker,
        <Object?>[port.sendPort, payload],
        debugName: 'ket-local-quantum-$id',
      );
      final message = await port.first;
      if (_cancelled) return;
      if (message is! Map) {
        throw StateError('Local simulator worker returned an invalid message.');
      }
      final map = Map<String, Object?>.from(message);
      if (map['ok'] != true) {
        throw StateError('${map['error'] ?? 'Local simulator failed'}');
      }
      final resultMap = Map<String, Object?>.from(map['result']! as Map);
      final result = _quantumResultFromMap(resultMap);
      _snapshot = QuantumJobSnapshot(
        id: id,
        backendId: backendId,
        targetId: targetId,
        state: QuantumJobState.succeeded,
        updatedAt: DateTime.now().toUtc(),
        result: result,
        metadata: <String, Object?>{
          'engine': 'ket-dart-statevector',
          'elapsedMicros': map['elapsedMicros'],
        },
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
    } finally {
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      port.close();
      _port = null;
    }
  }

  @override
  Future<void> cancel() async {
    if (_completion.isCompleted || _cancelled) return;
    _cancelled = true;
    _isolate?.kill(priority: Isolate.immediate);
    _port?.close();
    _snapshot = QuantumJobSnapshot(
      id: id,
      backendId: backendId,
      targetId: targetId,
      state: QuantumJobState.cancelled,
      updatedAt: DateTime.now().toUtc(),
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

void _localSimulationWorker(List<Object?> message) {
  final sendPort = message[0]! as SendPort;
  final payload = Map<String, Object?>.from(message[1]! as Map);
  final watch = Stopwatch()..start();
  try {
    final codec = const KetJsonCodec();
    final circuit = codec.decode(payload['circuit']! as String);
    final parameters = payload['parameters'] is Map
        ? (payload['parameters']! as Map)
            .map((key, value) => MapEntry('$key', (value as num).toDouble()))
        : const <String, double>{};
    final engine = _StatevectorMachine(circuit.qubitCount, parameters);
    for (final operation in circuit.operations) {
      engine.apply(operation);
    }
    final result = engine.result(
      circuit: circuit,
      shots: payload['shots']! as int,
      seed: payload['seed'] as int?,
    );
    watch.stop();
    sendPort.send(<String, Object?>{
      'ok': true,
      'result': result,
      'elapsedMicros': watch.elapsedMicroseconds,
    });
  } catch (error, stackTrace) {
    watch.stop();
    sendPort.send(<String, Object?>{
      'ok': false,
      'error': '$error',
      'stackTrace': '$stackTrace',
      'elapsedMicros': watch.elapsedMicroseconds,
    });
  }
}

QuantumResult _quantumResultFromMap(Map<String, Object?> map) {
  final statevector = (map['statevector']! as List)
      .map((item) {
        final pair = item as List;
        return ComplexValue((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
      })
      .toList(growable: false);
  final probabilities = (map['probabilities']! as Map).map(
    (key, value) => MapEntry('$key', (value as num).toDouble()),
  );
  final counts = (map['counts']! as Map).map(
    (key, value) => MapEntry('$key', value as int),
  );
  return QuantumResult(
    counts: counts,
    probabilities: probabilities,
    statevector: statevector,
    metadata: map['metadata'] is Map
        ? Map<String, Object?>.from(map['metadata']! as Map)
        : const <String, Object?>{},
  );
}

final class LocalQuantumDebugger implements QuantumDebugger {
  const LocalQuantumDebugger({this.maxQubits = 16});
  final int maxQubits;

  @override
  Future<QuantumDebugSession> start(QuantumDebugRequest request) async {
    if (request.circuit.qubitCount > maxQubits) {
      throw LocalQuantumLimitException(
        'Debugger is capped at $maxQubits exact qubits.',
      );
    }
    return _LocalQuantumDebugSession(request.circuit, request.parameters);
  }
}

final class _LocalQuantumDebugSession implements QuantumDebugSession {
  _LocalQuantumDebugSession(this._circuit, this._parameters);

  final KetCircuit _circuit;
  final Map<String, double> _parameters;
  var _index = 0;
  bool _disposed = false;

  @override
  int get operationIndex => _index;

  @override
  Future<QuantumDebugSnapshot> current() async => _snapshotAt(_index);

  @override
  Future<QuantumDebugSnapshot> stepForward() async {
    _ensureAlive();
    if (_index < _circuit.operations.length) _index++;
    return _snapshotAt(_index);
  }

  @override
  Future<QuantumDebugSnapshot> stepBackward() async {
    _ensureAlive();
    if (_index > 0) _index--;
    return _snapshotAt(_index);
  }

  @override
  Future<QuantumDebugSnapshot> seek(int operationIndex) async {
    _ensureAlive();
    if (operationIndex < 0 || operationIndex > _circuit.operations.length) {
      throw RangeError.range(operationIndex, 0, _circuit.operations.length);
    }
    _index = operationIndex;
    return _snapshotAt(_index);
  }

  QuantumDebugSnapshot _snapshotAt(int index) {
    _ensureAlive();
    final machine = _StatevectorMachine(_circuit.qubitCount, _parameters);
    for (var i = 0; i < index; i++) {
      machine.apply(_circuit.operations[i]);
    }
    final probabilities = machine.probabilities();
    final state = machine.statevector();
    final qubits = <QubitSnapshot>[
      for (var q = 0; q < _circuit.qubitCount; q++) machine.qubitSnapshot(q),
    ];
    final entanglement = _circuit.qubitCount == 2
        ? <EntanglementEdge>[
            EntanglementEdge(a: 0, b: 1, strength: machine.twoQubitConcurrence()),
          ]
        : const <EntanglementEdge>[];
    return QuantumDebugSnapshot(
      operationIndex: index,
      operation: index == 0 ? null : _circuit.operations[index - 1],
      probabilities: probabilities,
      statevector: state,
      qubits: qubits,
      entanglement: entanglement,
    );
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('Quantum debug session is disposed.');
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}

final class _StatevectorMachine {
  _StatevectorMachine(this.qubitCount, this.parameters)
      : _real = List<double>.filled(1 << qubitCount, 0),
        _imag = List<double>.filled(1 << qubitCount, 0) {
    _real[0] = 1;
  }

  final int qubitCount;
  final Map<String, double> parameters;
  final List<double> _real;
  final List<double> _imag;

  void apply(KetOperation operation) {
    switch (operation) {
      case KetBarrier():
      case KetMeasure():
        return;
      case KetGate():
        _applyGate(operation);
    }
  }

  void _applyGate(KetGate gate) {
    if (gate.name == 'swap') {
      if (gate.qubits.length != 2) throw StateError('swap requires two targets.');
      _applySwap(gate.qubits[0], gate.qubits[1], gate.controls);
      return;
    }
    if (gate.qubits.length != 1) {
      throw StateError('Gate ${gate.name} requires exactly one target in canonical KET IR.');
    }
    final target = gate.qubits.single;
    final angle = gate.parameters.isEmpty ? null : _resolve(gate.parameters.first);
    final matrix = switch (gate.name) {
      'x' => const _Matrix2(0, 0, 1, 0, 1, 0, 0, 0),
      'y' => const _Matrix2(0, 0, 0, -1, 0, 1, 0, 0),
      'z' => const _Matrix2(1, 0, 0, 0, 0, 0, -1, 0),
      'h' => _hadamard(),
      's' => const _Matrix2(1, 0, 0, 0, 0, 0, 0, 1),
      'sdg' => const _Matrix2(1, 0, 0, 0, 0, 0, 0, -1),
      't' => _phaseMatrix(math.pi / 4),
      'tdg' => _phaseMatrix(-math.pi / 4),
      'rx' => _rx(angle ?? _missingAngle('rx')),
      'ry' => _ry(angle ?? _missingAngle('ry')),
      'rz' => _rz(angle ?? _missingAngle('rz')),
      final String name => throw StateError('Unsupported local gate: $name'),
    };
    _applyMatrix(target, gate.controls, matrix);
  }

  Never _missingAngle(String gate) => throw StateError('$gate requires an angle parameter.');

  double _resolve(KetParameter parameter) => switch (parameter) {
        KetLiteralParameter() => parameter.value,
        KetSymbolParameter() => parameters[parameter.name] ??
            (throw StateError('Missing value for parameter ${parameter.name}.')),
      };

  _Matrix2 _hadamard() {
    final v = 1 / math.sqrt(2);
    return _Matrix2(v, 0, v, 0, v, 0, -v, 0);
  }

  _Matrix2 _phaseMatrix(double angle) => _Matrix2(
        1,
        0,
        0,
        0,
        0,
        0,
        math.cos(angle),
        math.sin(angle),
      );

  _Matrix2 _rx(double angle) {
    final c = math.cos(angle / 2);
    final s = math.sin(angle / 2);
    return _Matrix2(c, 0, 0, -s, 0, -s, c, 0);
  }

  _Matrix2 _ry(double angle) {
    final c = math.cos(angle / 2);
    final s = math.sin(angle / 2);
    return _Matrix2(c, 0, -s, 0, s, 0, c, 0);
  }

  _Matrix2 _rz(double angle) {
    final half = angle / 2;
    return _Matrix2(
      math.cos(half),
      -math.sin(half),
      0,
      0,
      0,
      0,
      math.cos(half),
      math.sin(half),
    );
  }

  void _applyMatrix(int target, List<int> controls, _Matrix2 m) {
    _validateQubit(target);
    for (final control in controls) {
      _validateQubit(control);
      if (control == target) throw StateError('Control cannot equal target.');
    }
    final mask = 1 << target;
    for (var base = 0; base < _real.length; base++) {
      if ((base & mask) != 0 || !_controlsActive(base, controls)) continue;
      final one = base | mask;
      final a0r = _real[base];
      final a0i = _imag[base];
      final a1r = _real[one];
      final a1i = _imag[one];

      _real[base] = m.aR * a0r - m.aI * a0i + m.bR * a1r - m.bI * a1i;
      _imag[base] = m.aR * a0i + m.aI * a0r + m.bR * a1i + m.bI * a1r;
      _real[one] = m.cR * a0r - m.cI * a0i + m.dR * a1r - m.dI * a1i;
      _imag[one] = m.cR * a0i + m.cI * a0r + m.dR * a1i + m.dI * a1r;
    }
  }

  void _applySwap(int a, int b, List<int> controls) {
    _validateQubit(a);
    _validateQubit(b);
    if (a == b) return;
    final maskA = 1 << a;
    final maskB = 1 << b;
    for (var index = 0; index < _real.length; index++) {
      if (!_controlsActive(index, controls)) continue;
      final bitA = (index & maskA) != 0;
      final bitB = (index & maskB) != 0;
      if (bitA || !bitB) continue; // process only 01 -> 10 once
      final other = (index | maskA) & ~maskB;
      final rr = _real[index];
      final ii = _imag[index];
      _real[index] = _real[other];
      _imag[index] = _imag[other];
      _real[other] = rr;
      _imag[other] = ii;
    }
  }

  bool _controlsActive(int basisIndex, List<int> controls) {
    for (final control in controls) {
      if ((basisIndex & (1 << control)) == 0) return false;
    }
    return true;
  }

  void _validateQubit(int index) {
    if (index < 0 || index >= qubitCount) {
      throw RangeError.range(index, 0, qubitCount - 1, 'qubit');
    }
  }

  Map<String, Object?> result({
    required KetCircuit circuit,
    required int shots,
    required int? seed,
  }) {
    final probabilities = this.probabilities();
    final counts = _sample(circuit, probabilities, shots, seed);
    return <String, Object?>{
      'probabilities': probabilities,
      'counts': counts,
      'statevector': <Object?>[
        for (var i = 0; i < _real.length; i++) <double>[_real[i], _imag[i]],
      ],
      'metadata': <String, Object?>{
        'qubitCount': qubitCount,
        'exactStatevector': true,
        'shots': shots,
        'seed': seed,
      },
    };
  }

  List<ComplexValue> statevector() => <ComplexValue>[
        for (var i = 0; i < _real.length; i++) ComplexValue(_real[i], _imag[i]),
      ];

  Map<String, double> probabilities() {
    final result = <String, double>{};
    for (var i = 0; i < _real.length; i++) {
      final probability = _real[i] * _real[i] + _imag[i] * _imag[i];
      if (probability > 1e-14) {
        result[i.toRadixString(2).padLeft(qubitCount, '0')] = probability;
      }
    }
    return result;
  }

  Map<String, int> _sample(
    KetCircuit circuit,
    Map<String, double> probabilities,
    int shots,
    int? seed,
  ) {
    final rng = math.Random(seed);
    final entries = probabilities.entries.toList(growable: false);
    final cumulative = <double>[];
    var sum = 0.0;
    for (final entry in entries) {
      sum += entry.value;
      cumulative.add(sum);
    }
    if ((sum - 1).abs() > 1e-8) {
      throw StateError('Statevector is not normalized: $sum');
    }
    final counts = <String, int>{};
    for (var shot = 0; shot < shots; shot++) {
      final value = rng.nextDouble() * sum;
      var selected = entries.length - 1;
      for (var i = 0; i < cumulative.length; i++) {
        if (value < cumulative[i]) {
          selected = i;
          break;
        }
      }
      final basis = int.parse(entries[selected].key, radix: 2);
      final key = _classicalOutcome(circuit, basis);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  String _classicalOutcome(KetCircuit circuit, int basis) {
    final measurements = circuit.operations.whereType<KetMeasure>().toList(growable: false);
    if (measurements.isEmpty || circuit.classicalBitCount <= 0) {
      return basis.toRadixString(2).padLeft(circuit.qubitCount, '0');
    }
    final bits = List<int>.filled(circuit.classicalBitCount, 0);
    for (final measurement in measurements) {
      bits[measurement.classicalBit] = (basis >> measurement.qubit) & 1;
    }
    return <int>[for (var i = bits.length - 1; i >= 0; i--) bits[i]].join();
  }

  QubitSnapshot qubitSnapshot(int qubit) {
    _validateQubit(qubit);
    final mask = 1 << qubit;
    var x = 0.0;
    var y = 0.0;
    var z = 0.0;
    for (var base = 0; base < _real.length; base++) {
      if ((base & mask) != 0) continue;
      final one = base | mask;
      final a0r = _real[base];
      final a0i = _imag[base];
      final a1r = _real[one];
      final a1i = _imag[one];
      final p0 = a0r * a0r + a0i * a0i;
      final p1 = a1r * a1r + a1i * a1i;
      z += p0 - p1;
      x += 2 * (a0r * a1r + a0i * a1i);
      y += 2 * (a0r * a1i - a0i * a1r);
    }
    final purity = ((1 + x * x + y * y + z * z) / 2).clamp(0.0, 1.0).toDouble();
    return QubitSnapshot(
      index: qubit,
      blochX: x,
      blochY: y,
      blochZ: z,
      purity: purity,
    );
  }

  double twoQubitConcurrence() {
    if (qubitCount != 2) return 0;
    final a00 = _Complex(_real[0], _imag[0]);
    final a01 = _Complex(_real[1], _imag[1]);
    final a10 = _Complex(_real[2], _imag[2]);
    final a11 = _Complex(_real[3], _imag[3]);
    final determinant = a00 * a11 - a01 * a10;
    return (2 * determinant.abs()).clamp(0.0, 1.0).toDouble();
  }
}

final class _Matrix2 {
  const _Matrix2(
    this.aR,
    this.aI,
    this.bR,
    this.bI,
    this.cR,
    this.cI,
    this.dR,
    this.dI,
  );
  final double aR;
  final double aI;
  final double bR;
  final double bI;
  final double cR;
  final double cI;
  final double dR;
  final double dI;
}

final class _Complex {
  const _Complex(this.r, this.i);
  final double r;
  final double i;

  _Complex operator *(_Complex other) =>
      _Complex(r * other.r - i * other.i, r * other.i + i * other.r);
  _Complex operator -(_Complex other) => _Complex(r - other.r, i - other.i);
  double abs() => math.sqrt(r * r + i * i);
}

void unawaited(Future<void> future) {}
