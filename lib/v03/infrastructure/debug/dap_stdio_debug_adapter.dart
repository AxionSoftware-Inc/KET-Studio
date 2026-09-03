import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/debug/debug_adapter.dart';

final class DapException implements Exception {
  const DapException(this.message);
  final String message;

  @override
  String toString() => 'DapException: $message';
}

final class DapStdioDebugAdapterHost implements DebugAdapterHost {
  const DapStdioDebugAdapterHost();

  @override
  Future<DebugSession> launch({
    required String adapterExecutable,
    required String program,
    List<String> adapterArguments = const <String>[],
    List<String> programArguments = const <String>[],
    String? workingDirectory,
    Map<String, String> environment = const <String, String>{},
  }) async {
    final process = await Process.start(
      adapterExecutable,
      adapterArguments,
      workingDirectory: workingDirectory,
      environment: environment.isEmpty ? null : environment,
      includeParentEnvironment: true,
      runInShell: false,
    );
    final transport = _DapTransport(process)..start();
    final session = _DapDebugSession(transport, process);
    await session.initialize(
      program: program,
      programArguments: programArguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return session;
  }
}

final class _DapDebugSession implements DebugSession {
  _DapDebugSession(this._transport, this._process);

  final _DapTransport _transport;
  final Process _process;
  final StreamController<String> _output = StreamController<String>.broadcast(sync: true);
  final StreamController<DebugStackFrame> _stoppedFrames =
      StreamController<DebugStackFrame>.broadcast(sync: true);
  StreamSubscription<Map<String, Object?>>? _eventSubscription;
  bool _disposed = false;

  @override
  Stream<String> get output => _output.stream;

  @override
  Stream<DebugStackFrame> get stoppedFrames => _stoppedFrames.stream;

  Future<void> initialize({
    required String program,
    required List<String> programArguments,
    required String? workingDirectory,
    required Map<String, String> environment,
  }) async {
    final initialized = Completer<void>();
    _eventSubscription = _transport.events.listen((event) {
      final name = event['event'];
      if (name == 'initialized' && !initialized.isCompleted) initialized.complete();
      if (name == 'output') {
        final body = event['body'];
        if (body is Map && body['output'] != null && !_output.isClosed) {
          _output.add('${body['output']}');
        }
      }
      if (name == 'stopped') unawaited(_publishTopFrame());
      if (name == 'terminated' && !_output.isClosed) {
        _output.add('[debug session terminated]\n');
      }
    });

    await _transport.request('initialize', <String, Object?>{
      'clientID': 'ket-studio',
      'clientName': 'KET Studio',
      'adapterID': 'python',
      'pathFormat': 'path',
      'linesStartAt1': true,
      'columnsStartAt1': true,
      'supportsVariableType': true,
      'supportsVariablePaging': true,
      'supportsRunInTerminalRequest': false,
      'locale': 'en-US',
    });

    final launchFuture = _transport.request('launch', <String, Object?>{
      'name': 'KET Python Debug',
      'type': 'python',
      'request': 'launch',
      'program': program,
      'args': programArguments,
      'cwd': workingDirectory,
      'env': environment,
      'console': 'internalConsole',
      'justMyCode': false,
      'stopOnEntry': true,
    });

    await initialized.future.timeout(const Duration(seconds: 10));
    await _transport.request('configurationDone', const <String, Object?>{});
    await launchFuture;
  }

  Future<void> _publishTopFrame() async {
    try {
      final frames = await stackTrace();
      if (frames.isNotEmpty && !_stoppedFrames.isClosed) {
        _stoppedFrames.add(frames.first);
      }
    } catch (error) {
      if (!_output.isClosed) _output.add('[debug stack error] $error\n');
    }
  }

  @override
  Future<void> setBreakpoints(String sourcePath, List<SourceBreakpoint> points) async {
    await _transport.request('setBreakpoints', <String, Object?>{
      'source': <String, Object?>{'path': sourcePath},
      'breakpoints': <Object?>[
        for (final point in points)
          <String, Object?>{
            'line': point.line,
            if (point.condition != null) 'condition': point.condition,
          },
      ],
      'sourceModified': false,
    });
  }

  @override
  Future<void> continueExecution() async {
    final threadId = await _primaryThreadId();
    await _transport.request('continue', <String, Object?>{'threadId': threadId});
  }

  @override
  Future<void> pause() async {
    final threadId = await _primaryThreadId();
    await _transport.request('pause', <String, Object?>{'threadId': threadId});
  }

  @override
  Future<void> stepOver() async {
    final threadId = await _primaryThreadId();
    await _transport.request('next', <String, Object?>{'threadId': threadId});
  }

  @override
  Future<void> stepInto() async {
    final threadId = await _primaryThreadId();
    await _transport.request('stepIn', <String, Object?>{'threadId': threadId});
  }

  @override
  Future<void> stepOut() async {
    final threadId = await _primaryThreadId();
    await _transport.request('stepOut', <String, Object?>{'threadId': threadId});
  }

  Future<int> _primaryThreadId() async {
    final body = await _transport.request('threads', const <String, Object?>{});
    final threads = body['threads'];
    if (threads is! List || threads.isEmpty || threads.first is! Map) {
      throw const DapException('Debug adapter returned no threads.');
    }
    final id = (threads.first as Map)['id'];
    if (id is! int) throw const DapException('Debug thread id is invalid.');
    return id;
  }

  @override
  Future<List<DebugStackFrame>> stackTrace() async {
    final threadId = await _primaryThreadId();
    final body = await _transport.request('stackTrace', <String, Object?>{
      'threadId': threadId,
      'startFrame': 0,
      'levels': 100,
    });
    final frames = body['stackFrames'];
    if (frames is! List) return const <DebugStackFrame>[];
    return frames.whereType<Map>().map((raw) {
      final frame = Map<String, Object?>.from(raw);
      final source = frame['source'];
      return DebugStackFrame(
        id: frame['id'] as int? ?? 0,
        name: '${frame['name'] ?? 'frame'}',
        line: frame['line'] as int? ?? 1,
        sourcePath: source is Map ? source['path'] as String? : null,
      );
    }).toList(growable: false);
  }

  Future<List<int>> _scopes(int frameId) async {
    final body = await _transport.request('scopes', <String, Object?>{'frameId': frameId});
    final scopes = body['scopes'];
    if (scopes is! List) return const <int>[];
    return scopes.whereType<Map>().map((scope) => scope['variablesReference']).whereType<int>().toList();
  }

  @override
  Future<List<DebugVariable>> variables(int variablesReference) async {
    final body = await _transport.request('variables', <String, Object?>{
      'variablesReference': variablesReference,
    });
    final values = body['variables'];
    if (values is! List) return const <DebugVariable>[];
    return values.whereType<Map>().map((raw) {
      final value = Map<String, Object?>.from(raw);
      return DebugVariable(
        name: '${value['name'] ?? ''}',
        value: '${value['value'] ?? ''}',
        type: value['type'] as String?,
        variablesReference: value['variablesReference'] as int? ?? 0,
      );
    }).toList(growable: false);
  }

  Future<List<DebugVariable>> variablesForFrame(int frameId) async {
    final references = await _scopes(frameId);
    final result = <DebugVariable>[];
    for (final reference in references) {
      result.addAll(await variables(reference));
    }
    return result;
  }

  @override
  Future<String> evaluate(String expression, {int? frameId}) async {
    final body = await _transport.request('evaluate', <String, Object?>{
      'expression': expression,
      if (frameId != null) 'frameId': frameId,
      'context': 'repl',
    });
    return '${body['result'] ?? ''}';
  }

  @override
  Future<void> terminate() async {
    if (_disposed) return;
    try {
      await _transport.request('disconnect', const <String, Object?>{
        'restart': false,
        'terminateDebuggee': true,
      }).timeout(const Duration(seconds: 3));
    } catch (_) {
      _process.kill(ProcessSignal.sigkill);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await terminate();
    _disposed = true;
    await _eventSubscription?.cancel();
    await _transport.dispose();
    await _output.close();
    await _stoppedFrames.close();
  }
}

final class _DapTransport {
  _DapTransport(this.process);
  final Process process;

  final Map<int, Completer<Map<String, Object?>>> _pending =
      <int, Completer<Map<String, Object?>>>{};
  final StreamController<Map<String, Object?>> _events =
      StreamController<Map<String, Object?>>.broadcast(sync: true);
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;
  final StringBuffer _stderr = StringBuffer();
  var _seq = 0;
  bool _disposed = false;

  Stream<Map<String, Object?>> get events => _events.stream;

  void start() {
    _stdoutSub = process.stdout.listen(_onBytes, onError: _failAll);
    _stderrSub = process.stderr.listen(
      (chunk) => _stderr.write(utf8.decode(chunk, allowMalformed: true)),
    );
    unawaited(_watchExit());
  }

  Future<Map<String, Object?>> request(
    String command,
    Map<String, Object?> arguments,
  ) async {
    if (_disposed) throw StateError('DAP transport is disposed.');
    final seq = ++_seq;
    final completer = Completer<Map<String, Object?>>();
    _pending[seq] = completer;
    await _write(<String, Object?>{
      'seq': seq,
      'type': 'request',
      'command': command,
      'arguments': arguments,
    });
    try {
      return await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _pending.remove(seq);
      throw DapException('DAP request timed out: $command');
    }
  }

  Future<void> _write(Map<String, Object?> message) async {
    final payload = utf8.encode(jsonEncode(message));
    process.stdin.add(ascii.encode('Content-Length: ${payload.length}\r\n\r\n'));
    process.stdin.add(payload);
    await process.stdin.flush();
  }

  void _onBytes(List<int> chunk) {
    _buffer.add(chunk);
    final bytes = _buffer.toBytes();
    var offset = 0;
    while (offset < bytes.length) {
      final headerEnd = _findHeaderEnd(bytes, offset);
      if (headerEnd < 0) break;
      final header = ascii.decode(bytes.sublist(offset, headerEnd));
      final length = _contentLength(header);
      if (length == null || length < 0 || length > 32 * 1024 * 1024) {
        _failAll(const DapException('Invalid DAP Content-Length.'));
        process.kill(ProcessSignal.sigkill);
        return;
      }
      final bodyStart = headerEnd + 4;
      if (bytes.length - bodyStart < length) break;
      final decoded = jsonDecode(utf8.decode(bytes.sublist(bodyStart, bodyStart + length)));
      if (decoded is! Map) {
        _failAll(const DapException('DAP message root must be an object.'));
        return;
      }
      _handle(Map<String, Object?>.from(decoded));
      offset = bodyStart + length;
    }
    _buffer.clear();
    if (offset < bytes.length) _buffer.add(bytes.sublist(offset));
  }

  int _findHeaderEnd(List<int> data, int start) {
    for (var i = start; i <= data.length - 4; i++) {
      if (data[i] == 13 && data[i + 1] == 10 && data[i + 2] == 13 && data[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  int? _contentLength(String header) {
    for (final line in header.split('\r\n')) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      if (line.substring(0, colon).trim().toLowerCase() == 'content-length') {
        return int.tryParse(line.substring(colon + 1).trim());
      }
    }
    return null;
  }

  void _handle(Map<String, Object?> message) {
    switch (message['type']) {
      case 'response':
        final requestSeq = message['request_seq'];
        if (requestSeq is! int) return;
        final completer = _pending.remove(requestSeq);
        if (completer == null) return;
        if (message['success'] == false) {
          completer.completeError(DapException('${message['message'] ?? 'DAP request failed'}'));
        } else {
          final body = message['body'];
          completer.complete(body is Map ? Map<String, Object?>.from(body) : const <String, Object?>{});
        }
        break;
      case 'event':
        if (!_events.isClosed) _events.add(message);
        break;
      case 'request':
        unawaited(_respondUnsupported(message));
        break;
    }
  }

  Future<void> _respondUnsupported(Map<String, Object?> request) async {
    final seq = request['seq'];
    final command = request['command'];
    if (seq is! int || command is! String) return;
    await _write(<String, Object?>{
      'seq': ++_seq,
      'type': 'response',
      'request_seq': seq,
      'success': false,
      'command': command,
      'message': 'KET Studio does not support adapter reverse request $command yet.',
    });
  }

  Future<void> _watchExit() async {
    final code = await process.exitCode;
    if (_disposed) return;
    final detail = _stderr.toString().trim();
    _failAll(DapException(
      'Debug adapter exited with code $code${detail.isEmpty ? '' : ': $detail'}',
    ));
  }

  void _failAll(Object error, [StackTrace? stackTrace]) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace ?? StackTrace.current);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _failAll(const DapException('DAP transport disposed.'));
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    process.kill(ProcessSignal.sigkill);
    await _events.close();
  }
}

void unawaited(Future<void> future) {}
