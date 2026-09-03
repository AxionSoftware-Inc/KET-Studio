import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/native/native_host_protocol.dart';

final class NativeHostException implements Exception {
  const NativeHostException(this.message);
  final String message;
  @override
  String toString() => 'NativeHostException: $message';
}

final class NativeHostClient {
  NativeHostClient({
    required this.executable,
    this.arguments = const <String>[],
    NativeHostFrameCodec codec = const NativeHostFrameCodec(),
    this.handshakeTimeout = const Duration(seconds: 5),
  }) : _codec = codec;

  final String executable;
  final List<String> arguments;
  final Duration handshakeTimeout;
  final NativeHostFrameCodec _codec;

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  final Map<String, Completer<NativeHostMessage>> _pending =
      <String, Completer<NativeHostMessage>>{};
  final StreamController<NativeHostMessage> _events =
      StreamController<NativeHostMessage>.broadcast(sync: true);
  final StringBuffer _stderr = StringBuffer();
  var _requestCounter = 0;
  bool _disposed = false;

  Stream<NativeHostMessage> get events => _events.stream;
  bool get isRunning => _process != null;

  Future<void> start() async {
    if (_disposed) throw StateError('NativeHostClient is disposed.');
    if (_process != null) return;

    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    _process = process;

    final decoder = NativeHostFrameDecoder(_codec);
    _stdoutSubscription = process.stdout.listen(
      (chunk) {
        try {
          for (final message in decoder.add(Uint8List.fromList(chunk))) {
            _onMessage(message);
          }
        } catch (error, stackTrace) {
          _failAll(NativeHostException('Malformed host output: $error'), stackTrace);
          unawaited(_killHost());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _failAll(error, stackTrace);
      },
    );
    _stderrSubscription = process.stderr.listen(
      (chunk) => _stderr.write(String.fromCharCodes(chunk)),
    );
    unawaited(_watchProcess(process));

    final hello = await request(
      NativeHostMessageType.hello,
      const <String, Object?>{'protocolVersion': 1},
      timeout: handshakeTimeout,
    );
    if (hello.type != NativeHostMessageType.hello ||
        hello.payload['protocolVersion'] != 1) {
      await _killHost();
      throw const NativeHostException('Native host protocol mismatch.');
    }
  }

  Future<NativeHostMessage> request(
    NativeHostMessageType type,
    Map<String, Object?> payload, {
    String? sessionId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final process = _process;
    if (process == null) throw StateError('Native host is not running.');

    final requestId = 'r${++_requestCounter}';
    final completer = Completer<NativeHostMessage>();
    _pending[requestId] = completer;
    final message = NativeHostMessage(
      type: type,
      requestId: requestId,
      sessionId: sessionId,
      payload: payload,
    );

    process.stdin.add(_codec.encode(message));
    await process.stdin.flush();

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(requestId);
      throw NativeHostException('Native host request timed out: ${type.name}');
    }
  }

  Future<void> send(
    NativeHostMessageType type,
    Map<String, Object?> payload, {
    required String sessionId,
  }) async {
    final process = _process;
    if (process == null) throw StateError('Native host is not running.');
    final message = NativeHostMessage(
      type: type,
      requestId: 'n${++_requestCounter}',
      sessionId: sessionId,
      payload: payload,
    );
    process.stdin.add(_codec.encode(message));
    await process.stdin.flush();
  }

  void _onMessage(NativeHostMessage message) {
    final completer = _pending.remove(message.requestId);
    if (completer != null) {
      if (message.type == NativeHostMessageType.error) {
        completer.completeError(
          NativeHostException('${message.payload['message'] ?? 'Host error'}'),
        );
      } else {
        completer.complete(message);
      }
      return;
    }
    _events.add(message);
  }

  Future<void> _watchProcess(Process process) async {
    final exitCode = await process.exitCode;
    if (!identical(_process, process)) return;
    _process = null;
    final detail = _stderr.toString().trim();
    _failAll(
      NativeHostException(
        'Native host exited with code $exitCode${detail.isEmpty ? '' : ': $detail'}',
      ),
      StackTrace.current,
    );
  }

  void _failAll(Object error, StackTrace stackTrace) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
  }

  Future<void> _killHost() async {
    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final process = _process;
    if (process != null) {
      try {
        await request(
          NativeHostMessageType.shutdown,
          const <String, Object?>{},
          timeout: const Duration(seconds: 2),
        );
      } catch (_) {
        await _killHost();
      }
    }
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _failAll(
      const NativeHostException('Native host client disposed.'),
      StackTrace.current,
    );
    await _events.close();
  }
}
