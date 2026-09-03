import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:xterm3/flutter.dart';
import 'package:xterm3/xterm.dart';

import '../../application/runtime/runtime_supervisor.dart';
import '../../core/terminal/terminal_host.dart';

final class TerminalPanel extends StatefulWidget {
  const TerminalPanel({
    required this.runtime,
    super.key,
  });

  final RuntimeSupervisor runtime;

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

final class _TerminalPanelState extends State<TerminalPanel> {
  late final Terminal _terminal;
  TerminalSession? _session;
  StreamSubscription<String>? _outputSubscription;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _terminal.onOutput = _sendInput;
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      final session = _session;
      if (session == null || width <= 0 || height <= 0) return;
      unawaited(session.resize(TerminalSize(columns: width, rows: height)));
    };
    unawaited(_connect());
  }

  Future<void> _connect() async {
    if (mounted) {
      setState(() {
        _connecting = true;
        _error = null;
      });
    }

    try {
      final old = _session;
      _session = null;
      await _outputSubscription?.cancel();
      _outputSubscription = null;
      if (old != null) {
        try {
          await old.terminate(force: true);
        } catch (_) {}
        await old.dispose();
      }

      final session = await widget.runtime.openTerminal(
        initialSize: TerminalSize(
          columns: _terminal.viewWidth <= 0 ? 120 : _terminal.viewWidth,
          rows: _terminal.viewHeight <= 0 ? 32 : _terminal.viewHeight,
        ),
      );
      _session = session;
      _outputSubscription = session.output
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(_terminal.write, onError: _onTerminalError);
      unawaited(_watchExit(session));
      _terminal.write('\r\n\x1b[38;5;39mKET Studio v0.3 terminal connected.\x1b[0m\r\n');
      if (mounted) setState(() => _connecting = false);
    } catch (error) {
      _onTerminalError(error);
    }
  }

  Future<void> _watchExit(TerminalSession session) async {
    try {
      final code = await session.exitCode;
      if (!identical(_session, session)) return;
      _terminal.write('\r\n\x1b[38;5;244m[process exited: $code]\x1b[0m\r\n');
    } catch (error) {
      if (identical(_session, session)) _onTerminalError(error);
    }
  }

  void _sendInput(String value) {
    final session = _session;
    if (session == null) return;
    unawaited(session.write(Uint8List.fromList(utf8.encode(value))));
  }

  void _onTerminalError(Object error, [StackTrace? stackTrace]) {
    _terminal.write('\r\n\x1b[31mKET terminal error: $error\x1b[0m\r\n');
    if (mounted) {
      setState(() {
        _connecting = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF080C11),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: <Widget>[
                  const Icon(FluentIcons.command_prompt, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    _connecting ? 'Starting terminal…' : 'TERMINAL',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  if (_error != null)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(FluentIcons.warning, size: 13),
                    ),
                  IconButton(
                    icon: const Icon(FluentIcons.refresh, size: 14),
                    onPressed: _connecting ? null : _connect,
                  ),
                ],
              ),
            ),
          ),
          const Divider(size: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: TerminalView(
                _terminal,
                autofocus: true,
                backgroundOpacity: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    final session = _session;
    _session = null;
    unawaited(_outputSubscription?.cancel() ?? Future<void>.value());
    if (session != null) {
      unawaited(() async {
        try {
          await session.terminate(force: true);
        } catch (_) {}
        await session.dispose();
      }());
    }
    super.dispose();
  }
}

void unawaited(Future<void> future) {}
