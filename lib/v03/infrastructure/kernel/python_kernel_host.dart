import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/kernel/kernel.dart';
import '../../core/protocol/ket_event.dart';

final class PythonKernelHost implements KernelHost {
  const PythonKernelHost({required this.kernelScript});

  final String kernelScript;

  @override
  Future<KernelSession> launch(KernelLaunchRequest request) async {
    final process = await Process.start(
      request.interpreter,
      <String>[...request.arguments, kernelScript],
      workingDirectory: request.workingDirectory,
      environment: request.environment.isEmpty ? null : request.environment,
      includeParentEnvironment: true,
      runInShell: false,
    );

    final session = _PythonKernelSession(process);
    await session.initialize();
    return session;
  }
}

final class _PythonKernelSession implements KernelSession {
  _PythonKernelSession(this._process);

  static const int _maxFrameBytes = 8 * 1024 * 1024;

  final Process _process;
  final StreamController<KetEvent> _events =
      StreamController<KetEvent>.broadcast(sync: true);
  final Map<String, Completer<Map<String, Object?>>> _pending =
      <String, Completer<Map<String, Object?>>>{};
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;
  StringBuffer _stderr = StringBuffer();
  int _requestCounter = 0;
  String _id = '';
  KernelState _state = KernelState.created;
  bool _disposed = false;

  Future<void> initialize() async {
    _state = KernelState.starting;
    _stdoutSub = _process.stdout.listen(_onBytes, onError: _failAll);
    _stderrSub = _process.stderr.listen(
      (chunk) => _stderr.write(utf8.decode(chunk, allowMalformed: true)),
    );
    unawaited(_watchExit());

    final hello = await _waitForHello().timeout(const Duration(seconds: 5));
    final sessionId = hello['sessionId'];
    if (hello['protocolVersion'] != KetEvent.currentProtocolVersion ||
        sessionId is! String ||
        sessionId.isEmpty) {
      await shutdown(force: true);
      throw StateError('Python kernel protocol mismatch.');
    }
    _id = sessionId;
    _state = KernelState.idle;
  }

  Completer<Map<String, Object?>>? _helloCompleter;

  Future<Map<String, Object?>> _waitForHello() {
    final completer = Completer<Map<String, Object?>>();
    _helloCompleter = completer;
    return completer.future;
  }

  @override
  String get id => _id;

  @override
  KernelState get state => _state;

  @override
  Stream<KetEvent> get events => _events.stream;

  @override
  Future<void> execute(KernelExecutionRequest request) async {
    _ensureUsable();
    if (_state != KernelState.idle) {
      throw StateError('Kernel $id is not idle.');
    }
    _state = KernelState.busy;
    try {
      await _request(<String, Object?>{
        'type': 'execute',
        'executionId': request.executionId,
        'code': request.code,
        if (request.fileName != null) 'fileName': request.fileName,
        'metadata': request.metadata,
      });
    } catch (_) {
      _state = KernelState.failed;
      rethrow;
    }
  }

  @override
  Future<void> provideInput(String value) async {
    _ensureUsable();
    await _request(<String, Object?>{'type': 'input', 'value': value});
  }

  @override
  Future<void> interrupt() async {
    _ensureUsable();
    // The kernel runtime deliberately refuses unsafe thread interruption.
    // Kill/restart the owned process to guarantee a deterministic interruption.
    await restart();
  }

  @override
  Future<void> restart() async {
    _ensureUsable();
    if (_state == KernelState.busy) {
      _state = KernelState.restarting;
      _process.kill(ProcessSignal.sigkill);
      throw StateError(
        'Busy kernel process was terminated. Launch a replacement session.',
      );
    }
    _state = KernelState.restarting;
    await _request(<String, Object?>{'type': 'restart'});
    _state = KernelState.idle;
  }

  @override
  Future<void> shutdown({bool force = false}) async {
    if (_state == KernelState.stopped || _disposed) return;
    _state = KernelState.stopping;
    if (force) {
      _process.kill(ProcessSignal.sigkill);
    } else {
      try {
        await _request(<String, Object?>{'type': 'shutdown'})
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        _process.kill(ProcessSignal.sigkill);
      }
    }
    await _process.exitCode;
    _state = KernelState.stopped;
  }

  Future<Map<String, Object?>> _request(Map<String, Object?> message) async {
    final requestId = 'k${++_requestCounter}';
    final completer = Completer<Map<String, Object?>>();
    _pending[requestId] = completer;
    await _write(<String, Object?>{...message, 'requestId': requestId});
    try {
      return await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _pending.remove(requestId);
      rethrow;
    }
  }

  Future<void> _write(Map<String, Object?> value) async {
    final payload = utf8.encode(jsonEncode(value));
    if (payload.length > _maxFrameBytes) {
      throw StateError('Kernel frame exceeds maximum size.');
    }
    final bytes = Uint8List(4 + payload.length);
    ByteData.sublistView(bytes).setUint32(0, payload.length, Endian.big);
    bytes.setRange(4, bytes.length, payload);
    _process.stdin.add(bytes);
    await _process.stdin.flush();
  }

  void _onBytes(List<int> chunk) {
    _buffer.add(chunk);
    final data = _buffer.toBytes();
    var offset = 0;
    while (data.length - offset >= 4) {
      final length = ByteData.sublistView(data, offset, offset + 4)
          .getUint32(0, Endian.big);
      if (length <= 0 || length > _maxFrameBytes) {
        _failAll(StateError('Invalid kernel frame length.'));
        _process.kill(ProcessSignal.sigkill);
        return;
      }
      if (data.length - offset - 4 < length) break;
      final payload = utf8.decode(
        Uint8List.sublistView(data, offset + 4, offset + 4 + length),
      );
      _handleMessage(jsonDecode(payload) as Map<String, Object?>);
      offset += 4 + length;
    }
    _buffer.clear();
    if (offset < data.length) {
      _buffer.add(Uint8List.sublistView(data, offset));
    }
  }

  void _handleMessage(Map<String, Object?> message) {
    final type = message['type'];
    if (type == 'hello') {
      _helloCompleter?.complete(message);
      _helloCompleter = null;
      return;
    }
    if (type == 'event') {
      final raw = message['event'];
      if (raw is Map<String, Object?>) {
        final event = KetEvent.decode(jsonEncode(raw));
        if (event.kind == KetEventKind.lifecycle) {
          final state = event.payload['state'];
          if (state == 'idle') _state = KernelState.idle;
          if (state == 'busy') _state = KernelState.busy;
        }
        _events.add(event);
      }
      return;
    }

    final requestId = message['requestId'];
    if (requestId is String) {
      final pending = _pending.remove(requestId);
      if (pending != null) {
        if (type == 'error') {
          pending.completeError(StateError('${message['message']}'));
        } else {
          pending.complete(message);
        }
      }
    }
  }

  Future<void> _watchExit() async {
    final exitCode = await _process.exitCode;
    if (_state != KernelState.stopping && _state != KernelState.stopped) {
      _state = exitCode == 0 ? KernelState.stopped : KernelState.failed;
    }
    final detail = _stderr.toString().trim();
    _failAll(StateError(
      'Python kernel exited with code $exitCode${detail.isEmpty ? '' : ': $detail'}',
    ));
  }

  void _failAll(Object error) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    if (_helloCompleter case final hello? when !hello.isCompleted) {
      hello.completeError(error);
    }
  }

  void _ensureUsable() {
    if (_disposed || _state == KernelState.stopped) {
      throw StateError('Kernel session is not usable.');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (_state != KernelState.stopped) {
      await shutdown(force: true);
    }
    _disposed = true;
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    await _events.close();
  }
}

void unawaited(Future<void> future) {}
