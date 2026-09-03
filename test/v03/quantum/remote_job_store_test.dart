import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/core/quantum/quantum_backend.dart';
import 'package:ket_studio/v03/core/quantum/remote_job.dart';
import 'package:ket_studio/v03/infrastructure/quantum/file_remote_job_store.dart';

void main() {
  test('remote job store survives a fresh store instance', () async {
    final directory = await Directory.systemTemp.createTemp('ket-remote-jobs-');
    addTearDown(() => directory.delete(recursive: true));
    final created = DateTime.utc(2026, 9, 3, 10);
    final record = RemoteJobRecord(
      id: 'ibm:job-1',
      jobId: 'job-1',
      backendId: 'provider.example',
      targetId: 'qpu-1',
      state: QuantumJobState.queued,
      createdAt: created,
      updatedAt: created,
      programFormat: QuantumProgramFormat.openQasm3,
      programHash: 'abc123',
      shots: 4096,
      seed: 7,
      metadata: const <String, Object?>{'region': 'test'},
    );

    await FileRemoteJobStore(directory).save(record);
    final recovered = await FileRemoteJobStore(directory).get(record.id);

    expect(recovered, isNotNull);
    expect(recovered!.jobId, 'job-1');
    expect(recovered.state, QuantumJobState.queued);
    expect(recovered.shots, 4096);
  });
}
