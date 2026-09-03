import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../core/native/native_host_protocol.dart';
import '../../core/terminal/terminal_host.dart';
import '../native/native_host_client.dart';

final class NativeTerminalHost implements TerminalHost {
  NativeTerminalHost(this._client);

  final NativeHostClient _client;

  @override
  Future<TerminalSession> open(TerminalLaunchRequest request) async {
    if (!_client.isRunning) await _client.start();

    final response = await _client.request(
      NativeHostMessageType.openTerminal,
      <String, Object?>{
        'executable': request.executable,
        'arguments': request.arguments,
        if (request.workingDirectory != null)
          'workingDirectory': request.workingDirectory,
        'environment': request.environment,
        'columns': request.initialSize.columns,
        'rows': request.initialSize.rows,
      },
    );

    final sessionId = response.sessionId;
    if (response.type != NativeHostMessageType.terminalOpened ||
        sessionId == null ||
        sessionId.isEmpty) {
      throw const NativeHostException('Host returned invalid terminal session.');
    }

    return _NativeTerminalSession(_client, sessionId);
  }
}

final class _NativeTerminalSession implements TerminalSession {
  _NativeTerminalSession(this._client, this.id) {
    _subscription = _client.events.listen(_handleEvent);
  }

  final NativeHostClient _client;
  @override
  final String id;

  final StreamController<Uint8List> _output =
      StreamController<Uint8List>.broadcast(sync: true);
  final Completer<int> _exit = Completer<int>();
  late final StreamSubscription<NativeHostMessage> _subscription;
  bool _disposed = false;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  void _handleEvent(NativeHostMessage message) {
    if (message.sessionId != id) return;
    switch (message.type) {
      case NativeHostMessageType.terminalOutput:
        final encoded = message.payload['data'];
        if (encoded is! String) {
          _output.addError(const FormatException('Terminal output data missing.'));
          return;
        }
        try {
          _output.add(base64Decode(encoded));
        } catch (error, stackTrace) {
          _output.addError(error, stackTrace);
        }
      case NativeHostMessageType.terminalExit:
        final code = message.payload['exitCode'];
        if (!_exit.isCompleted) {
          _exit.complete(code is int ? code : -1);
        }
      case NativeHostMessageType.error:
        final error = NativeHostException(
          '${message.payload['message'] ?? 'Terminal host error'}',
        );
        _output.addError(error);
        if (!_exit.isCompleted) _exit.completeError(error);
      default:
        break;
    }
  }

  void _ensureUsable() {
    if (_disposed) throw StateError('Terminal session $id is disposed.');
  }

  @override
  Future<void> write(Uint8List bytes) async {
    _ensureUsable();
    await _client.send(
      NativeHostMessageType.terminalInput,
      <String, Object?>{'data': base64Encode(bytes)},
      sessionId: id,
    );
  }

  @override
  Future<void> resize(TerminalSize size) async {
    _ensureUsable();
    await _client.send(
      NativeHostMessageType.terminalResize,
      <String, Object?>{'columns': size.columns, 'rows': size.rows},
      sessionId: id,
    );
  }

  @override
  Future<void> interrupt() async {
    _ensureUsable();
    await _client.send(
      NativeHostMessageType.terminalInterrupt,
      const <String, Object?>{},
      sessionId: id,
    );
  }

  @override
  Future<void> terminate({bool force = false}) async {
    _ensureUsable();
    await _client.send(
      NativeHostMessageType.terminalTerminate,
      <String, Object?>{'force': force},
      sessionId: id,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription.cancel();
    await _output.close();
  }
}
