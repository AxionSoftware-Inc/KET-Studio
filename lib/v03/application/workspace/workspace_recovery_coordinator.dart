import 'dart:async';

import '../../core/workspace/workspace_session.dart';
import '../workbench_controller.dart';

final class WorkspaceRecoveryCoordinator {
  WorkspaceRecoveryCoordinator({
    required this.controller,
    required this.store,
    this.debounce = const Duration(milliseconds: 700),
  });

  final WorkbenchController controller;
  final WorkspaceSessionStore store;
  final Duration debounce;
  Timer? _timer;
  bool _attached = false;
  bool _restoring = false;

  Future<bool> initialize() async {
    final session = await store.load();
    if (session != null) {
      _restoring = true;
      try {
        controller.restoreSession(session);
      } finally {
        _restoring = false;
      }
    }
    attach();
    return session != null;
  }

  void attach() {
    if (_attached) return;
    _attached = true;
    controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (_restoring) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(saveNow()));
  }

  Future<void> saveNow() async {
    await store.save(controller.snapshotSession());
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    if (_attached) {
      controller.removeListener(_onChanged);
      _attached = false;
    }
    await saveNow();
  }
}
