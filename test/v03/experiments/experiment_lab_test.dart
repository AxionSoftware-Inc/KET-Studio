import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/core/experiments/experiment_record.dart';
import 'package:ket_studio/v03/core/quantum/quantum_backend.dart';
import 'package:ket_studio/v03/infrastructure/experiments/file_experiment_lab.dart';
import 'package:ket_studio/v03/infrastructure/experiments/file_experiment_store.dart';

void main() {
  test('experiment lab computes total variation and source/backend changes', () async {
    final root = await Directory.systemTemp.createTemp('ket-exp-lab-');
    addTearDown(() => root.delete(recursive: true));
    final store = FileExperimentStore(root);
    final lab = FileExperimentLab(store);

    Future<void> write(
      String id,
      String source,
      String backend,
      Map<String, double> probabilities,
    ) async {
      final artifact = await store.persistJsonArtifact(
        recordId: id,
        kind: 'quantum-result',
        value: <String, Object?>{
          'counts': const <String, int>{},
          'probabilities': probabilities,
        },
      );
      await store.save(ExperimentRecord(
        id: id,
        createdAt: DateTime.now().toUtc(),
        projectId: 'project',
        sourceRevision: source,
        environmentFingerprint: 'env',
        backendId: backend,
        targetId: 'target',
        programFormat: QuantumProgramFormat.openQasm3,
        shots: 100,
        artifacts: <ExperimentArtifact>[artifact],
      ));
    }

    await write('a', 'source-a', 'backend-a', const <String, double>{'00': 0.5, '11': 0.5});
    await write('b', 'source-b', 'backend-b', const <String, double>{'00': 0.75, '11': 0.25});

    final comparison = await lab.compare('a', 'b');
    expect(comparison.sameSource, isFalse);
    expect(comparison.sameBackend, isFalse);
    expect(comparison.totalVariationDistance, closeTo(0.25, 1e-12));
    expect(comparison.maxProbabilityDelta, closeTo(0.25, 1e-12));
  });
}
