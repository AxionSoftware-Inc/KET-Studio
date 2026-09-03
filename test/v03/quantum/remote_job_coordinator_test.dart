import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/application/quantum/provider_registry.dart';
import 'package:ket_studio/v03/application/quantum/remote_job_coordinator.dart';
import 'package:ket_studio/v03/core/quantum/quantum_backend.dart';
import 'package:ket_studio/v03/core/quantum/remote_job.dart';
import 'package:ket_studio/v03/infrastructure/quantum/file_remote_job_store.dart';

void main() {
  test('remote job recovery persists refreshed terminal state', () async {
    final root = await Directory.systemTemp.createTemp('ket-remote-recovery-');
    addTearDown(() => root.delete(recursive: true));
    final store = FileRemoteJobStore(root);
    final registry = QuantumProviderRegistry()..register(_FakeBackend());
    addTearDown(registry.dispose);
    final coordinator = RemoteJobCoordinator(registry: registry, store: store);
    addTearDown(coordinator.dispose);

    final now = DateTime.now().toUtc();
    await store.save(RemoteJobRecord(
      id: 'record-1',
      jobId: 'job-1',
      backendId: 'fake.remote',
      targetId: 'target',
      state: QuantumJobState.running,
      createdAt: now,
      updatedAt: now,
      programFormat: QuantumProgramFormat.openQasm3,
      programHash: 'hash',
      shots: 100,
    ));

    final report = await coordinator.recoverOnce();
    final restored = await store.get('record-1');

    expect(report.checked, 1);
    expect(report.updated, 1);
    expect(report.failed, 0);
    expect(restored!.state, QuantumJobState.succeeded);
    expect(restored.metadata['recovered'], isTrue);
  });
}

final class _FakeBackend implements QuantumBackend {
  @override
  String get id => 'fake.remote';

  @override
  String get displayName => 'Fake Remote';

  @override
  Future<QuantumBackendCapabilities> capabilities() async =>
      const QuantumBackendCapabilities(
        supportsSimulator: false,
        supportsHardware: true,
        supportsStatevector: false,
        supportsDensityMatrix: false,
        supportsNoiseModels: false,
        supportsOpenQasm3: true,
        supportsParameterizedCircuits: false,
        supportsRemoteJobs: true,
      );

  @override
  Future<List<QuantumTarget>> listTargets() async => const <QuantumTarget>[
        QuantumTarget(id: 'target', name: 'Target', qubitCount: 5, isSimulator: false),
      ];

  @override
  Future<QuantumJobSnapshot> getJob(String jobId) async => QuantumJobSnapshot(
        id: jobId,
        backendId: id,
        targetId: 'target',
        state: QuantumJobState.succeeded,
        updatedAt: DateTime.now().toUtc(),
        metadata: const <String, Object?>{'recovered': true},
      );

  @override
  Future<QuantumJob> submit(QuantumExecutionRequest request) =>
      Future<QuantumJob>.error(UnimplementedError());

  @override
  Stream<QuantumJobSnapshot> watchJob(String jobId) => const Stream<QuantumJobSnapshot>.empty();

  @override
  Future<void> cancelJob(String jobId) async {}
}
