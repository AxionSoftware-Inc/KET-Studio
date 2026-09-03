import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/core/quantum/quantum_backend.dart';
import 'package:ket_studio/v03/core/quantum/quantum_debugger.dart';
import 'package:ket_studio/v03/infrastructure/quantum/local_statevector_backend.dart';
import 'package:ket_studio/v03/infrastructure/quantum/openqasm3_codec.dart';

void main() {
  const bell = '''
OPENQASM 3.0;
include "stdgates.inc";
qubit[2] q;
bit[2] c;
h q[0];
cx q[0], q[1];
measure q -> c;
''';

  test('local backend produces normalized Bell probabilities and seeded shots', () async {
    final backend = LocalStatevectorBackend();
    final job = await backend.submit(const QuantumExecutionRequest(
      targetId: 'local-statevector',
      program: bell,
      format: QuantumProgramFormat.openQasm3,
      shots: 2048,
      seed: 42,
    ));

    final snapshot = await job.completion;
    expect(snapshot.state, QuantumJobState.succeeded);
    final result = snapshot.result!;
    expect(result.probabilities.keys, containsAll(<String>['00', '11']));
    expect(result.probabilities['00']!, closeTo(0.5, 1e-10));
    expect(result.probabilities['11']!, closeTo(0.5, 1e-10));
    expect(result.probabilities.values.reduce((a, b) => a + b), closeTo(1.0, 1e-10));
    expect(result.counts.keys.every((key) => key == '00' || key == '11'), isTrue);
    expect(result.counts.values.fold<int>(0, (a, b) => a + b), 2048);
  });

  test('quantum debugger exposes Bell entanglement after controlled-X', () async {
    final circuit = const OpenQasm3CodecImpl().decode(bell);
    final debugger = const LocalQuantumDebugger();
    final session = await debugger.start(QuantumDebugRequest(circuit: circuit));
    addTearDown(session.dispose);

    await session.stepForward(); // H
    final snapshot = await session.stepForward(); // CX

    expect(snapshot.operationIndex, 2);
    expect(snapshot.probabilities['00']!, closeTo(0.5, 1e-10));
    expect(snapshot.probabilities['11']!, closeTo(0.5, 1e-10));
    expect(snapshot.entanglement.single.strength, closeTo(1.0, 1e-10));
    expect(snapshot.qubits.every((qubit) => qubit.purity < 0.5000001), isTrue);
  });

  test('local exact simulator rejects oversized circuits before execution', () async {
    final backend = LocalStatevectorBackend(maxQubits: 3);
    await expectLater(
      backend.submit(const QuantumExecutionRequest(
        targetId: 'local-statevector',
        program: 'OPENQASM 3.0; qubit[4] q;',
        format: QuantumProgramFormat.openQasm3,
      )),
      throwsA(isA<LocalQuantumLimitException>()),
    );
  });
}
