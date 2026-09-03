import '../../core/execution/execution_backend.dart';
import '../../core/protocol/ket_event.dart';
import '../../core/session/session_state.dart';

final class ManagedExecution {
  ManagedExecution({
    required this.handle,
    required this.stateMachine,
  });

  final ExecutionHandle handle;
  final SessionStateMachine stateMachine;

  Stream<KetEvent> get events => handle.events;
  SessionState get state => stateMachine.state;
}

final class ExecutionService {
  ExecutionService(this._backend);

  final ExecutionBackend _backend;
  final Map<String, ManagedExecution> _sessions = <String, ManagedExecution>{};

  Iterable<ManagedExecution> get sessions => _sessions.values;

  Future<ManagedExecution> start(ExecutionRequest request) async {
    final state = SessionStateMachine()..transitionTo(SessionState.starting);

    try {
      final handle = await _backend.start(request);
      if (_sessions.containsKey(handle.id)) {
        await handle.dispose();
        throw StateError('Duplicate execution id: ${handle.id}');
      }

      state.transitionTo(SessionState.running);
      final managed = ManagedExecution(handle: handle, stateMachine: state);
      _sessions[handle.id] = managed;

      unawaited(_watchExit(managed));
      return managed;
    } catch (_) {
      if (!state.isTerminal) {
        state.transitionTo(SessionState.failed);
      }
      rethrow;
    }
  }

  Future<void> interrupt(String id) async {
    final session = _require(id);
    if (session.state != SessionState.running) {
      throw StateError('Execution $id is not running.');
    }
    await session.handle.interrupt();
  }

  Future<void> stop(String id, {bool force = false}) async {
    final session = _require(id);
    if (session.state == SessionState.running ||
        session.state == SessionState.starting) {
      session.stateMachine.transitionTo(SessionState.stopping);
    }
    await session.handle.stop(force: force);
  }

  Future<void> dispose() async {
    final snapshot = _sessions.values.toList(growable: false);
    _sessions.clear();
    for (final session in snapshot) {
      try {
        if (!session.stateMachine.isTerminal) {
          await session.handle.stop(force: true);
        }
      } finally {
        await session.handle.dispose();
      }
    }
  }

  ManagedExecution _require(String id) {
    final value = _sessions[id];
    if (value == null) {
      throw StateError('Unknown execution id: $id');
    }
    return value;
  }

  Future<void> _watchExit(ManagedExecution session) async {
    try {
      await session.handle.exitCode;
      if (!session.stateMachine.isTerminal) {
        if (session.state == SessionState.running) {
          session.stateMachine.transitionTo(SessionState.exited);
        } else if (session.state == SessionState.stopping) {
          session.stateMachine.transitionTo(SessionState.exited);
        }
      }
    } catch (_) {
      if (!session.stateMachine.isTerminal) {
        session.stateMachine.transitionTo(SessionState.failed);
      }
    }
  }
}

void unawaited(Future<void> future) {}
