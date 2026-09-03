import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/application/quantum/provider_registry.dart';
import 'package:ket_studio/v03/core/quantum/quantum_backend.dart';
import 'package:ket_studio/v03/infrastructure/quantum/local_density_matrix_backend.dart';
import 'package:ket_studio/v03/infrastructure/quantum/local_statevector_backend.dart';

void main() {
  const bell = '''
OPENQASM 3.0;
qubit[2] q;
bit[2] c;
h q[0];
cx q[0], q[1];
measure q -> c;
''';

  test('provider registry discovers both built-in local engines', () async {
    final registry = QuantumProviderRegistry()
      ..register(LocalStatevectorBackend())
      ..register(LocalDensityMatrixBackend());
    addTearDown(registry.dispose);

    final snapshots = await registry.refreshAll();
    expect(snapshots.length, 2);
    expect(snapshots.every((item) => item.health == ProviderHealth.ready), isTrue);
    expect(
      snapshots.expand((item) => item.targets).map((item) => item.id),
      containsAll(<String>['local-statevector', 'local-density-matrix']),
    );
  });

  test('density-matrix backend preserves trace and mixes Bell state', () async {
    final backend = LocalDensityMatrixBackend();
    final job = await backend.submit(const QuantumExecutionRequest(
      targetId: 'local-density-matrix',
      program: bell,
      format: QuantumProgramFormat.openQasm3,
      shots: 1024,
      seed: 11,
      options: <String, Object?>{
        'noise': <String, Object?>{
          'depolarizing': <Object?>[
            <String, Object?>{
              'qubits': <int>[0],
              'probability': 0.12,
            },
          ],
        },
      },
    ));

    final snapshot = await job.completion;
    expect(snapshot.state, QuantumJobState.succeeded);
    final result = snapshot.result!;
    expect(result.densityMatrix, isNotNull);
    final density = result.densityMatrix!;
    final trace = List<double>.generate(density.length, (i) => density[i][i].real)
        .fold<double>(0, (a, b) => a + b);
    expect(trace, closeTo(1, 1e-7));
    expect(result.probabilities.length, greaterThan(2));
    expect(result.counts.values.fold<int>(0, (a, b) => a + b), 1024);
  });

  test('relaxation noise fails explicitly instead of faking physics', () async {
    final backend = LocalDensityMatrixBackend();
    await expectLater(
      backend.submit(const QuantumExecutionRequest(
        targetId: 'local-density-matrix',
        program: bell,
        format: QuantumProgramFormat.openQasm3,
        options: <String, Object?>{
          'noise': <String, Object?>{
            'relaxation': <Object?>[
              <String, Object?>{
                'qubit': 0,
                't1Microseconds': 100.0,
                't2Microseconds': 80.0,
              },
            ],
          },
        },
      )),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
