import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final class ProviderBridgeException implements Exception {
  const ProviderBridgeException(this.message);
  final String message;

  @override
  String toString() => 'ProviderBridgeException: $message';
}

final class ProviderProbe {
  const ProviderProbe({
    required this.vendor,
    required this.available,
    required this.targets,
    this.version,
  });

  final String vendor;
  final bool available;
  final String? version;
  final List<Map<String, Object?>> targets;
}

final class PythonProviderBridgeClient {
  PythonProviderBridgeClient({
    required this.pythonExecutable,
    required this.bridgeScript,
    this.workingDirectory,
  });

  static const int protocolVersion = 1;
  static const int _maxFrameBytes = 16 * 1024 * 1024;

  final String pythonExecutable;
  final String bridgeScript;
  final String? workingDirectory;

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  final Map<String, Completer<Map<String, Object?>>> _pending =
      <String, Completer<Map<String, Object?>>>{};
  Completer<Map<String, Object?>>? _hello;
  StringBuffer _stderr = StringBuffer();
  int _requestCounter = 0;
  bool _disposed = false;
  bool _disposing = false;

  bool get isRunning => _process != null;

  Future<void> start() async {
    if (_disposed || _disposing) throw StateError('Provider bridge is disposed.');
    if (_process != null) return;
    _stderr = StringBuffer();
    final process = await Process.start(
      pythonExecutable,
      <String>[bridgeScript],
      workingDirectory: workingDirectory,
      includeParentEnvironment: true,
      runInShell: false,
    );
    _process = process;
    _hello = Completer<Map<String, Object?>>();
    _stdoutSub = process.stdout.listen(_onBytes, onError: _failAll);
    _stderrSub = process.stderr.listen(
      (chunk) => _stderr.write(utf8.decode(chunk, allowMalformed: true)),
    );
    unawaited(_watchExit(process));
    final hello = await _hello!.future.timeout(const Duration(seconds: 5));
    if (hello['protocolVersion'] != protocolVersion) {
      await dispose();
      throw const ProviderBridgeException('Provider bridge protocol mismatch.');
    }
  }

  Future<List<ProviderProbe>> probe({String? vendor}) async {
    await start();
    final response = await request(<String, Object?>{
      'type': 'probe',
      if (vendor != null) 'vendor': vendor,
    });
    final raw = response['providers'];
    if (raw is! List) {
      throw const ProviderBridgeException('Probe response is malformed.');
    }
    return raw.whereType<Map>().map((value) {
      final map = Map<String, Object?>.from(value);
      final targets = map['targets'] is List
          ? (map['targets']! as List)
              .whereType<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .toList(growable: false)
          : const <Map<String, Object?>>[];
      return ProviderProbe(
        vendor: '${map['vendor'] ?? ''}',
        available: map['available'] == true,
        version: map['version'] as String?,
        targets: targets,
      );
    }).toList(growable: false);
  }

  Future<Map<String, Object?>> request(
    Map<String, Object?> message, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_disposed || _disposing) {
      throw const ProviderBridgeException('Provider bridge is shutting down.');
    }
    await start();
    return _requestStarted(message, timeout: timeout);
  }

  Future<Map<String, Object?>> _requestStarted(
    Map<String, Object?> message, {
    required Duration timeout,
  }) async {
    final requestId = 'p${++_requestCounter}';
    final completer = Completer<Map<String, Object?>>();
    _pending[requestId] = completer;
    try {
      await _write(<String, Object?>{...message, 'requestId': requestId});
    } catch (error, stackTrace) {
      _pending.remove(requestId);
      Error.throwWithStackTrace(error, stackTrace);
    }
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(requestId);
      throw ProviderBridgeException('Provider request timed out: ${message['type']}');
    }
  }

  Future<void> _write(Map<String, Object?> value) async {
    final process = _process;
    if (process == null) throw const ProviderBridgeException('Bridge is not running.');
    final payload = utf8.encode(jsonEncode(value));
    if (payload.length > _maxFrameBytes) {
      throw const ProviderBridgeException('Provider frame exceeds maximum size.');
    }
    final frame = Uint8List(4 + payload.length);
    ByteData.sublistView(frame).setUint32(0, payload.length, Endian.big);
    frame.setRange(4, frame.length, payload);
    process.stdin.add(frame);
    await process.stdin.flush();
  }

  void _onBytes(List<int> chunk) {
    if (_disposed) return;
    _buffer.add(chunk);
    final bytes = _buffer.toBytes();
    var offset = 0;
    while (bytes.length - offset >= 4) {
      final length = ByteData.sublistView(bytes, offset, offset + 4)
          .getUint32(0, Endian.big);
      if (length <= 0 || length > _maxFrameBytes) {
        _failAll(const ProviderBridgeException('Invalid provider frame length.'));
        _process?.kill(ProcessSignal.sigkill);
        return;
      }
      if (bytes.length - offset - 4 < length) break;
      try {
        final decoded = jsonDecode(utf8.decode(
          Uint8List.sublistView(bytes, offset + 4, offset + 4 + length),
        ));
        if (decoded is! Map) {
          throw const ProviderBridgeException('Provider frame root must be an object.');
        }
        _handle(Map<String, Object?>.from(decoded));
      } catch (error) {
        _failAll(error);
        _process?.kill(ProcessSignal.sigkill);
        return;
      }
      offset += 4 + length;
    }
    _buffer.clear();
    if (offset < bytes.length) {
      _buffer.add(Uint8List.sublistView(bytes, offset));
    }
  }

  void _handle(Map<String, Object?> message) {
    final type = message['type'];
    if (type == 'hello') {
      final hello = _hello;
      if (hello != null && !hello.isCompleted) hello.complete(message);
      _hello = null;
      return;
    }
    if (type == 'fatal') {
      _failAll(ProviderBridgeException('${message['message'] ?? 'Provider bridge fatal error'}'));
      return;
    }
    final requestId = message['requestId'];
    if (requestId is! String) return;
    final pending = _pending.remove(requestId);
    if (pending == null || pending.isCompleted) return;
    if (type == 'error') {
      pending.completeError(ProviderBridgeException('${message['message'] ?? 'Provider error'}'));
    } else {
      pending.complete(message);
    }
  }

  Future<void> _watchExit(Process process) async {
    final code = await process.exitCode;
    if (!identical(_process, process)) return;
    _process = null;
    if (_disposed || _disposing) return;
    final detail = _stderr.toString().trim();
    _failAll(ProviderBridgeException(
      'Provider bridge exited with code $code${detail.isEmpty ? '' : ': $detail'}',
    ));
  }

  void _failAll(Object error) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    final hello = _hello;
    if (hello != null && !hello.isCompleted) hello.completeError(error);
    _hello = null;
  }

  Future<void> dispose() async {
    if (_disposed || _disposing) return;
    _disposing = true;
    final process = _process;
    if (process != null) {
      var graceful = false;
      try {
        await _requestStarted(
          const <String, Object?>{'type': 'shutdown'},
          timeout: const Duration(seconds: 2),
        );
        graceful = true;
      } catch (_) {
        // Fall through to deterministic force termination.
      }
      if (!graceful) process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
      }
    }
    _disposed = true;
    _disposing = false;
    _process = null;
    _failAll(const ProviderBridgeException('Provider bridge disposed.'));
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
  }
}
