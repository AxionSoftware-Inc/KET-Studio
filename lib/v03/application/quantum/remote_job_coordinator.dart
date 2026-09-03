import 'dart:async';

import '../../core/quantum/quantum_backend.dart';
import '../../core/quantum/remote_job.dart';
import 'provider_registry.dart';

final class RemoteJobRecoveryReport {
  const RemoteJobRecoveryReport({
    required this.checked,
    required this.updated,
    required this.failed,
  });

  final int checked;
  final int updated;
  final int failed;
}

final class RemoteJobCoordinator {
  RemoteJobCoordinator({required this.registry, required this.store});

  final QuantumProviderRegistry registry;
  final RemoteJobStore store;
  Timer? _timer;
  bool _running = false;

  Future<RemoteJobRecoveryReport> recoverOnce() async {
    if (_running) return const RemoteJobRecoveryReport(checked: 0, updated: 0, failed: 0);
    _running = true;
    var checked = 0;
    var updated = 0;
    var failed = 0;
    try {
      final records = await store.list();
      for (final record in records.where((item) => !_terminal(item.state))) {
        checked++;
        try {
          final backend = registry.backend(record.backendId);
          final snapshot = await backend.getJob(record.jobId);
          await store.save(record.copyWith(
            state: snapshot.state,
            updatedAt: snapshot.updatedAt,
            metadata: <String, Object?>{
              ...record.metadata,
              ...snapshot.metadata,
              'lastRecoveryAt': DateTime.now().toUtc().toIso8601String(),
              if (snapshot.errorMessage != null) 'errorMessage': snapshot.errorMessage,
            },
          ));
          updated++;
        } catch (error) {
          failed++;
          await store.save(record.copyWith(
            updatedAt: DateTime.now().toUtc(),
            metadata: <String, Object?>{
              ...record.metadata,
              'lastRecoveryError': '$error',
              'lastRecoveryAt': DateTime.now().toUtc().toIso8601String(),
            },
          ));
        }
      }
      return RemoteJobRecoveryReport(checked: checked, updated: updated, failed: failed);
    } finally {
      _running = false;
    }
  }

  void start({Duration interval = const Duration(seconds: 15)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(recoverOnce()));
    unawaited(recoverOnce());
  }

  Future<void> track(RemoteJobRecord record) async {
    await store.save(record);
  }

  bool _terminal(QuantumJobState state) => switch (state) {
        QuantumJobState.succeeded || QuantumJobState.failed || QuantumJobState.cancelled => true,
        _ => false,
      };

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
