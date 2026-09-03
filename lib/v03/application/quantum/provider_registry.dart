import 'dart:async';

import '../../core/quantum/quantum_backend.dart';

enum ProviderHealth { unknown, ready, degraded, unavailable }

final class ProviderSnapshot {
  const ProviderSnapshot({
    required this.backendId,
    required this.displayName,
    required this.health,
    required this.updatedAt,
    this.capabilities,
    this.targets = const <QuantumTarget>[],
    this.errorMessage,
  });

  final String backendId;
  final String displayName;
  final ProviderHealth health;
  final DateTime updatedAt;
  final QuantumBackendCapabilities? capabilities;
  final List<QuantumTarget> targets;
  final String? errorMessage;
}

final class QuantumProviderRegistry {
  final Map<String, QuantumBackend> _backends = <String, QuantumBackend>{};
  final Map<String, ProviderSnapshot> _snapshots = <String, ProviderSnapshot>{};
  final StreamController<List<ProviderSnapshot>> _changes =
      StreamController<List<ProviderSnapshot>>.broadcast(sync: true);
  bool _disposed = false;

  List<QuantumBackend> get backends => List<QuantumBackend>.unmodifiable(_backends.values);
  List<ProviderSnapshot> get snapshots => List<ProviderSnapshot>.unmodifiable(
        _snapshots.values.toList()..sort((a, b) => a.displayName.compareTo(b.displayName)),
      );
  Stream<List<ProviderSnapshot>> get changes => _changes.stream;

  void register(QuantumBackend backend) {
    _ensureAlive();
    final existing = _backends[backend.id];
    if (existing != null && !identical(existing, backend)) {
      throw StateError('A quantum backend with id ${backend.id} is already registered.');
    }
    _backends[backend.id] = backend;
    _snapshots.putIfAbsent(
      backend.id,
      () => ProviderSnapshot(
        backendId: backend.id,
        displayName: backend.displayName,
        health: ProviderHealth.unknown,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    _publish();
  }

  void unregister(String backendId) {
    _ensureAlive();
    _backends.remove(backendId);
    _snapshots.remove(backendId);
    _publish();
  }

  QuantumBackend backend(String backendId) {
    _ensureAlive();
    final value = _backends[backendId];
    if (value == null) throw StateError('Quantum backend is not registered: $backendId');
    return value;
  }

  Future<ProviderSnapshot> refresh(String backendId) async {
    _ensureAlive();
    final backend = this.backend(backendId);
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        backend.capabilities(),
        backend.listTargets(),
      ]);
      final snapshot = ProviderSnapshot(
        backendId: backend.id,
        displayName: backend.displayName,
        health: ProviderHealth.ready,
        updatedAt: DateTime.now().toUtc(),
        capabilities: results[0] as QuantumBackendCapabilities,
        targets: List<QuantumTarget>.unmodifiable(results[1] as List<QuantumTarget>),
      );
      _snapshots[backendId] = snapshot;
      _publish();
      return snapshot;
    } catch (error) {
      final previous = _snapshots[backendId];
      final snapshot = ProviderSnapshot(
        backendId: backend.id,
        displayName: backend.displayName,
        health: previous?.capabilities == null
            ? ProviderHealth.unavailable
            : ProviderHealth.degraded,
        updatedAt: DateTime.now().toUtc(),
        capabilities: previous?.capabilities,
        targets: previous?.targets ?? const <QuantumTarget>[],
        errorMessage: '$error',
      );
      _snapshots[backendId] = snapshot;
      _publish();
      return snapshot;
    }
  }

  Future<List<ProviderSnapshot>> refreshAll() async {
    _ensureAlive();
    for (final backendId in _backends.keys.toList(growable: false)) {
      await refresh(backendId);
    }
    return snapshots;
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(snapshots);
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('QuantumProviderRegistry is disposed.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _backends.clear();
    _snapshots.clear();
    await _changes.close();
  }
}
