import 'dart:async';
import 'dart:convert';
import 'dart:io';

final class JsonRpcException implements Exception {
  const JsonRpcException(this.message, {this.code, this.data});
  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() => 'JsonRpcException${code == null ? '' : '($code)'}: $message';
}

typedef JsonRpcServerRequestHandler = FutureOr<Object?> Function(
  String method,
  Object? params,
);

final class StdioJsonRpcClient {
  StdioJsonRpcClient(
    this.process, {
    this.serverRequestHandler,
    this.defaultTimeout = const Duration(seconds: 15),
  });

  final Process process;
  final JsonRpcServerRequestHandler? serverRequestHandler;
  final Duration defaultTimeout;

  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  final StreamController<Map<String, Object?>> _notifications =
      StreamController<Map<String, Object?>>.broadcast(sync: true);
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  final StringBuffer _stderr = StringBuffer();
  var _nextId = 0;
  bool _disposed = false;

  Stream<Map<String, Object?>> get notifications => _notifications.stream;
  String get stderrText => _stderr.toString();

  void start() {
    if (_stdoutSubscription != null) return;
    _stdoutSubscription = process.stdout.listen(
      _onBytes,
      onError: (Object error, StackTrace stackTrace) => _failAll(error, stackTrace),
    );
    _stderrSubscription = process.stderr.listen(
      (chunk) => _stderr.write(utf8.decode(chunk, allowMalformed: true)),
    );
    unawaited(_watchExit());
  }

  Future<T> request<T>(
    String method, {
    Object? params,
    Duration? timeout,
  }) async {
    _ensureAlive();
    final id = ++_nextId;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    await _write(<String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    });
    try {
      final value = await completer.future.timeout(timeout ?? defaultTimeout);
      return value as T;
    } on TimeoutException {
      _pending.remove(id);
      throw JsonRpcException('Request timed out: $method');
    }
  }

  Future<void> notify(String method, {Object? params}) async {
    _ensureAlive();
    await _write(<String, Object?>{
      'jsonrpc': '2.0',
      'method': method,
      if (params != null) 'params': params,
    });
  }

  Future<void> _write(Map<String, Object?> message) async {
    final payload = utf8.encode(jsonEncode(message));
    final header = ascii.encode('Content-Length: ${payload.length}\r\n\r\n');
    process.stdin.add(header);
    process.stdin.add(payload);
    await process.stdin.flush();
  }

  void _onBytes(List<int> chunk) {
    if (_disposed) return;
    _buffer.add(chunk);
    final bytes = _buffer.toBytes();
    var offset = 0;
    while (offset < bytes.length) {
      final headerEnd = _indexOf(bytes, const <int>[13, 10, 13, 10], offset);
      if (headerEnd < 0) break;
      final headerText = ascii.decode(bytes.sublist(offset, headerEnd));
      final length = _contentLength(headerText);
      if (length == null || length < 0 || length > 32 * 1024 * 1024) {
        _failAll(const JsonRpcException('Invalid Content-Length header.'), StackTrace.current);
        process.kill(ProcessSignal.sigkill);
        return;
      }
      final bodyStart = headerEnd + 4;
      if (bytes.length - bodyStart < length) break;
      final body = utf8.decode(bytes.sublist(bodyStart, bodyStart + length));
      try {
        final decoded = jsonDecode(body);
        if (decoded is! Map) throw const FormatException('JSON-RPC frame must be an object.');
        _handle(Map<String, Object?>.from(decoded));
      } catch (error, stackTrace) {
        _failAll(error, stackTrace);
        process.kill(ProcessSignal.sigkill);
        return;
      }
      offset = bodyStart + length;
    }

    _buffer.clear();
    if (offset < bytes.length) _buffer.add(bytes.sublist(offset));
  }

  int? _contentLength(String header) {
    for (final line in header.split('\r\n')) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      if (line.substring(0, colon).trim().toLowerCase() != 'content-length') continue;
      return int.tryParse(line.substring(colon + 1).trim());
    }
    return null;
  }

  int _indexOf(List<int> data, List<int> needle, int start) {
    outer:
    for (var i = start; i <= data.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (data[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  void _handle(Map<String, Object?> message) {
    final method = message['method'];
    final id = message['id'];
    if (method is String) {
      if (id != null) {
        unawaited(_handleServerRequest(id, method, message['params']));
      } else if (!_notifications.isClosed) {
        _notifications.add(message);
      }
      return;
    }

    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    final error = message['error'];
    if (error is Map) {
      final map = Map<String, Object?>.from(error);
      completer.completeError(JsonRpcException(
        '${map['message'] ?? 'JSON-RPC error'}',
        code: map['code'] as int?,
        data: map['data'],
      ));
    } else {
      completer.complete(message['result']);
    }
  }

  Future<void> _handleServerRequest(Object id, String method, Object? params) async {
    try {
      final result = await serverRequestHandler?.call(method, params);
      await _write(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      });
    } catch (error) {
      await _write(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'error': <String, Object?>{
          'code': -32603,
          'message': '$error',
        },
      });
    }
  }

  Future<void> _watchExit() async {
    final code = await process.exitCode;
    if (_disposed) return;
    final stderr = _stderr.toString().trim();
    _failAll(
      JsonRpcException(
        'Language/debug process exited with code $code${stderr.isEmpty ? '' : ': $stderr'}',
      ),
      StackTrace.current,
    );
  }

  void _failAll(Object error, StackTrace stackTrace) {
    final values = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in values) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('StdioJsonRpcClient is disposed.');
  }

  Future<void> dispose({bool kill = true}) async {
    if (_disposed) return;
    _disposed = true;
    _failAll(const JsonRpcException('JSON-RPC client disposed.'), StackTrace.current);
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    if (kill) process.kill(ProcessSignal.sigkill);
    await _notifications.close();
  }
}

void unawaited(Future<void> future) {}
