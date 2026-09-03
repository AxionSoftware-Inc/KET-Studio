import 'dart:async';

import '../../core/kernel/kernel.dart';
import '../../core/terminal/terminal_host.dart';
import '../../infrastructure/kernel/python_kernel_host.dart';
import '../../infrastructure/native/native_host_client.dart';
import '../../infrastructure/terminal/native_terminal_host.dart';
import '../../infrastructure/runtime/runtime_locator.dart';

enum RuntimeHealth {
  cold,
  discovering,
  ready,
  degraded,
  failed,
  disposed,
}

final class RuntimeSnapshot {
  const RuntimeSnapshot({
    required this.health,
    required this.message,
    this.paths,
    this.terminalCount = 0,
    this.kernelState,
  });

  final RuntimeHealth health;
  final String message;
  final RuntimePaths? paths;
  final int terminalCount;
  final KernelState? kernelState;
}

final class RuntimeSupervisor {
  RuntimeSupervisor({RuntimeLocator locator = const RuntimeLocator()})
      : _locator = locator;

  final RuntimeLocator _locator;
  final StreamController<RuntimeSnapshot> _snapshots =
      StreamController<RuntimeSnapshot>.broadcast(sync: true);
  final List<TerminalSession> _terminals = <TerminalSession>[];

  RuntimePaths? _paths;
  NativeHostClient? _nativeClient;
  NativeTerminalHost? _terminalHost;
  KernelSession? _kernel;
  RuntimeSnapshot _snapshot = const RuntimeSnapshot(
    health: RuntimeHealth.cold,
    message: 'Runtime has not been initialized.',
  );
  bool _disposed = false;

  RuntimeSnapshot get snapshot => _snapshot;
  Stream<RuntimeSnapshot> get snapshots => _snapshots.stream;
  RuntimePaths? get paths => _paths;
  KernelSession? get kernel => _kernel;

  Future<RuntimeSnapshot> initialize() async {
    _ensureAlive();
    _emit(const RuntimeSnapshot(
      health: RuntimeHealth.discovering,
      message: 'Discovering KET runtime components…',
    ));

    try {
      final paths = await _locator.resolve();
      _paths = paths;
      final missing = <String>[
        if (!paths.hasNativeHost) 'native terminal host',
        if (!paths.hasKernel) 'Python kernel runtime',
      ];

      if (missing.isEmpty) {
        _emit(RuntimeSnapshot(
          health: RuntimeHealth.ready,
          message: 'Runtime foundation is ready.',
          paths: paths,
        ));
      } else {
        _emit(RuntimeSnapshot(
          health: RuntimeHealth.degraded,
          message: 'Missing ${missing.join(' and ')}. Build/runtime discovery is required.',
          paths: paths,
        ));
      }
      return _snapshot;
    } catch (error) {
      _emit(RuntimeSnapshot(
        health: RuntimeHealth.failed,
        message: 'Runtime discovery failed: $error',
      ));
      rethrow;
    }
  }

  Future<TerminalSession> openTerminal({
    String? workingDirectory,
    Map<String, String> environment = const <String, String>{},
    TerminalSize initialSize = const TerminalSize(columns: 120, rows: 32),
  }) async {
    _ensureAlive();
    final paths = await _requirePaths();
    final hostExecutable = paths.nativeHost;
    if (hostExecutable == null) {
      throw StateError('KET native host executable was not found.');
    }

    var client = _nativeClient;
    if (client == null) {
      client = NativeHostClient(executable: hostExecutable);
      await client.start();
      _nativeClient = client;
      _terminalHost = NativeTerminalHost(client);
    }

    final session = await _terminalHost!.open(TerminalLaunchRequest(
      executable: paths.defaultShell,
      workingDirectory: workingDirectory,
      environment: environment,
      initialSize: initialSize,
    ));
    _terminals.add(session);
    unawaited(_observeTerminalExit(session));
    _publishActivity('Terminal ${session.id} started.');
    return session;
  }

  Future<KernelSession> ensureKernel({String? workingDirectory}) async {
    _ensureAlive();
    final current = _kernel;
    if (current != null &&
        current.state != KernelState.stopped &&
        current.state != KernelState.failed) {
      return current;
    }

    final paths = await _requirePaths();
    final script = paths.kernelScript;
    if (script == null) {
      throw StateError('KET Python kernel runtime was not found.');
    }

    final host = PythonKernelHost(kernelScript: script);
    final kernel = await host.launch(KernelLaunchRequest(
      interpreter: paths.pythonInterpreter,
      workingDirectory: workingDirectory,
    ));
    _kernel = kernel;
    _publishActivity('Persistent Python kernel ${kernel.id} is ready.');
    return kernel;
  }

  Future<KernelSession> replaceKernel({String? workingDirectory}) async {
    final old = _kernel;
    _kernel = null;
    if (old != null) {
      try {
        await old.shutdown(force: true);
      } finally {
        await old.dispose();
      }
    }
    return ensureKernel(workingDirectory: workingDirectory);
  }

  Future<RuntimePaths> _requirePaths() async {
    final value = _paths;
    if (value != null) return value;
    await initialize();
    return _paths!;
  }

  Future<void> _observeTerminalExit(TerminalSession session) async {
    try {
      final code = await session.exitCode;
      _terminals.remove(session);
      _publishActivity('Terminal ${session.id} exited with code $code.');
    } catch (error) {
      _terminals.remove(session);
      _publishActivity('Terminal ${session.id} failed: $error');
    }
  }

  void _publishActivity(String message) {
    final paths = _paths;
    final kernel = _kernel;
    _emit(RuntimeSnapshot(
      health: _snapshot.health == RuntimeHealth.failed
          ? RuntimeHealth.degraded
          : _snapshot.health,
      message: message,
      paths: paths,
      terminalCount: _terminals.length,
      kernelState: kernel?.state,
    ));
  }

  void _emit(RuntimeSnapshot value) {
    _snapshot = value;
    if (!_snapshots.isClosed) _snapshots.add(value);
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('RuntimeSupervisor is disposed.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final terminals = _terminals.toList(growable: false);
    _terminals.clear();
    for (final terminal in terminals) {
      try {
        await terminal.terminate(force: true);
      } catch (_) {
        // Host/process may already be gone.
      } finally {
        await terminal.dispose();
      }
    }

    final kernel = _kernel;
    _kernel = null;
    if (kernel != null) {
      try {
        await kernel.shutdown(force: true);
      } catch (_) {
        // Kernel may already be gone.
      } finally {
        await kernel.dispose();
      }
    }

    await _nativeClient?.dispose();
    _nativeClient = null;
    _terminalHost = null;
    _emit(const RuntimeSnapshot(
      health: RuntimeHealth.disposed,
      message: 'Runtime disposed.',
    ));
    await _snapshots.close();
  }
}

void unawaited(Future<void> future) {}
