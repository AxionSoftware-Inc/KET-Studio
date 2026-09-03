import 'dart:async';
import 'dart:io';

import '../../core/language/language_services.dart';
import 'stdio_json_rpc.dart';

final class PyrightLanguageServiceHost implements LanguageServiceHost {
  const PyrightLanguageServiceHost();

  @override
  Future<LanguageServiceSession> start({
    required String languageId,
    required String executable,
    List<String> arguments = const <String>[],
    Uri? workspaceRoot,
  }) async {
    if (languageId != 'python') {
      throw ArgumentError.value(languageId, 'languageId', 'Pyright only supports Python.');
    }
    final process = await Process.start(
      executable,
      arguments.isEmpty ? const <String>['--stdio'] : arguments,
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    late final StdioJsonRpcClient client;
    client = StdioJsonRpcClient(
      process,
      serverRequestHandler: (method, params) => _handleServerRequest(
        method,
        params,
        workspaceRoot,
      ),
    )..start();

    final session = _PyrightSession(client, workspaceRoot);
    await session.initialize();
    return session;
  }

  Object? _handleServerRequest(String method, Object? params, Uri? workspaceRoot) {
    return switch (method) {
      'workspace/configuration' => _configurationResponse(params),
      'workspace/workspaceFolders' => workspaceRoot == null
          ? null
          : <Object?>[
              <String, Object?>{
                'uri': workspaceRoot.toString(),
                'name': 'KET Workspace',
              },
            ],
      'client/registerCapability' => null,
      'client/unregisterCapability' => null,
      'window/workDoneProgress/create' => null,
      'workspace/applyEdit' => const <String, Object?>{'applied': false},
      _ => null,
    };
  }

  List<Object?> _configurationResponse(Object? params) {
    if (params is! Map || params['items'] is! List) return const <Object?>[];
    final items = params['items']! as List;
    const analysis = <String, Object?>{
      'typeCheckingMode': 'basic',
      'diagnosticMode': 'openFilesOnly',
      'autoSearchPaths': true,
      'useLibraryCodeForTypes': true,
    };
    return <Object?>[
      for (final item in items)
        if (item is Map && item['section'] == 'python.analysis')
          analysis
        else if (item is Map && item['section'] == 'python')
          const <String, Object?>{'analysis': analysis}
        else
          const <String, Object?>{},
    ];
  }
}

final class _PyrightSession implements LanguageServiceSession {
  _PyrightSession(this._client, this._workspaceRoot);

  final StdioJsonRpcClient _client;
  final Uri? _workspaceRoot;
  final Map<Uri, StreamController<List<LanguageDiagnostic>>> _diagnosticStreams =
      <Uri, StreamController<List<LanguageDiagnostic>>>{};
  final Map<Uri, List<LanguageDiagnostic>> _latestDiagnostics =
      <Uri, List<LanguageDiagnostic>>{};
  StreamSubscription<Map<String, Object?>>? _notificationSubscription;
  bool _disposed = false;

  Future<void> initialize() async {
    _notificationSubscription = _client.notifications.listen(_onNotification);
    final root = _workspaceRoot;
    await _client.request<Object?>(
      'initialize',
      params: <String, Object?>{
        'processId': pid,
        'clientInfo': const <String, Object?>{
          'name': 'KET Studio',
          'version': '0.3.0',
        },
        'rootUri': root?.toString(),
        'workspaceFolders': root == null
            ? null
            : <Object?>[
                <String, Object?>{
                  'uri': root.toString(),
                  'name': 'KET Workspace',
                },
              ],
        'capabilities': const <String, Object?>{
          'workspace': <String, Object?>{
            'configuration': true,
            'workspaceFolders': true,
          },
          'textDocument': <String, Object?>{
            'publishDiagnostics': <String, Object?>{
              'relatedInformation': true,
              'versionSupport': true,
            },
            'completion': <String, Object?>{
              'completionItem': <String, Object?>{
                'documentationFormat': <String>['markdown', 'plaintext'],
                'snippetSupport': true,
              },
            },
            'hover': <String, Object?>{
              'contentFormat': <String>['markdown', 'plaintext'],
            },
            'definition': const <String, Object?>{},
          },
        },
      },
    );
    await _client.notify('initialized', params: const <String, Object?>{});
  }

  @override
  Stream<List<LanguageDiagnostic>> diagnosticsFor(Uri document) async* {
    yield _latestDiagnostics[document] ?? const <LanguageDiagnostic>[];
    final controller = _diagnosticStreams.putIfAbsent(
      document,
      () => StreamController<List<LanguageDiagnostic>>.broadcast(sync: true),
    );
    yield* controller.stream;
  }

  @override
  Future<List<CompletionEntry>> completion(Uri document, TextPosition position) async {
    final result = await _client.request<Object?>(
      'textDocument/completion',
      params: <String, Object?>{
        'textDocument': <String, Object?>{'uri': document.toString()},
        'position': _position(position),
      },
    );
    final items = result is List
        ? result
        : result is Map && result['items'] is List
            ? result['items']! as List
            : const <Object?>[];
    return items.whereType<Map>().map((raw) {
      final item = Map<String, Object?>.from(raw);
      return CompletionEntry(
        label: '${item['label'] ?? ''}',
        detail: item['detail'] as String?,
        insertText: item['insertText'] as String?,
        documentation: _markupToString(item['documentation']),
      );
    }).where((entry) => entry.label.isNotEmpty).toList(growable: false);
  }

  @override
  Future<String?> hover(Uri document, TextPosition position) async {
    final result = await _client.request<Object?>(
      'textDocument/hover',
      params: <String, Object?>{
        'textDocument': <String, Object?>{'uri': document.toString()},
        'position': _position(position),
      },
    );
    if (result is! Map) return null;
    return _markupToString(result['contents']);
  }

  @override
  Future<Uri?> definition(Uri document, TextPosition position) async {
    final result = await _client.request<Object?>(
      'textDocument/definition',
      params: <String, Object?>{
        'textDocument': <String, Object?>{'uri': document.toString()},
        'position': _position(position),
      },
    );
    final location = result is List && result.isNotEmpty
        ? result.first
        : result;
    if (location is! Map) return null;
    final uri = location['uri'] ?? location['targetUri'];
    return uri is String ? Uri.tryParse(uri) : null;
  }

  @override
  Future<void> openDocument(Uri document, String text, int version) async {
    await _client.notify(
      'textDocument/didOpen',
      params: <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': document.toString(),
          'languageId': 'python',
          'version': version,
          'text': text,
        },
      },
    );
  }

  @override
  Future<void> changeDocument(Uri document, String text, int version) async {
    await _client.notify(
      'textDocument/didChange',
      params: <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': document.toString(),
          'version': version,
        },
        'contentChanges': <Object?>[
          <String, Object?>{'text': text},
        ],
      },
    );
  }

  @override
  Future<void> closeDocument(Uri document) async {
    await _client.notify(
      'textDocument/didClose',
      params: <String, Object?>{
        'textDocument': <String, Object?>{'uri': document.toString()},
      },
    );
    _latestDiagnostics.remove(document);
  }

  void _onNotification(Map<String, Object?> message) {
    if (message['method'] != 'textDocument/publishDiagnostics') return;
    final params = message['params'];
    if (params is! Map) return;
    final uriValue = params['uri'];
    final values = params['diagnostics'];
    if (uriValue is! String || values is! List) return;
    final uri = Uri.tryParse(uriValue);
    if (uri == null) return;
    final diagnostics = values.whereType<Map>().map(_diagnosticFromJson).toList(growable: false);
    _latestDiagnostics[uri] = diagnostics;
    final controller = _diagnosticStreams[uri];
    if (controller != null && !controller.isClosed) controller.add(diagnostics);
  }

  LanguageDiagnostic _diagnosticFromJson(Map raw) {
    final map = Map<String, Object?>.from(raw);
    final range = map['range'] is Map
        ? Map<String, Object?>.from(map['range']! as Map)
        : const <String, Object?>{};
    final start = range['start'] is Map
        ? Map<String, Object?>.from(range['start']! as Map)
        : const <String, Object?>{};
    final end = range['end'] is Map
        ? Map<String, Object?>.from(range['end']! as Map)
        : const <String, Object?>{};
    final severityValue = map['severity'] as int? ?? 3;
    final severity = switch (severityValue) {
      1 => DiagnosticSeverity.error,
      2 => DiagnosticSeverity.warning,
      4 => DiagnosticSeverity.hint,
      _ => DiagnosticSeverity.information,
    };
    return LanguageDiagnostic(
      range: TextRange(
        TextPosition(start['line'] as int? ?? 0, start['character'] as int? ?? 0),
        TextPosition(end['line'] as int? ?? 0, end['character'] as int? ?? 0),
      ),
      message: '${map['message'] ?? 'Diagnostic'}',
      severity: severity,
      source: map['source'] as String?,
      code: map['code']?.toString(),
    );
  }

  Map<String, Object?> _position(TextPosition position) => <String, Object?>{
        'line': position.line,
        'character': position.character,
      };

  String? _markupToString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return value['value']?.toString() ?? value['language']?.toString();
    if (value is List) {
      return value.map(_markupToString).whereType<String>().join('\n\n');
    }
    return value.toString();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _client.request<Object?>('shutdown', timeout: const Duration(seconds: 3));
      await _client.notify('exit');
    } catch (_) {
      // Language server may already have exited.
    }
    await _notificationSubscription?.cancel();
    for (final controller in _diagnosticStreams.values) {
      await controller.close();
    }
    _diagnosticStreams.clear();
    await _client.dispose();
  }
}
