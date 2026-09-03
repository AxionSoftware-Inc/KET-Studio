import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/workspace/workspace_session.dart';

final class FileWorkspaceSessionStore implements WorkspaceSessionStore {
  const FileWorkspaceSessionStore(this.rootDirectory);

  final Directory rootDirectory;

  File get _sessionFile => File(p.join(rootDirectory.path, 'workspace-session.json'));

  @override
  Future<WorkspaceSession?> load() async {
    final file = _sessionFile;
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final map = Map<String, Object?>.from(raw);
      if (map['version'] != 1 || map['documents'] is! List) return null;
      final documents = (map['documents']! as List).whereType<Map>().map((value) {
        final item = Map<String, Object?>.from(value);
        return WorkspaceDocumentState(
          id: _string(item, 'id'),
          title: _string(item, 'title'),
          languageId: _string(item, 'languageId'),
          text: item['text'] as String? ?? '',
          savedText: item['savedText'] as String? ?? '',
          path: item['path'] as String?,
        );
      }).toList(growable: false);
      if (documents.isEmpty) return null;
      return WorkspaceSession(
        savedAt: DateTime.parse(_string(map, 'savedAt')).toUtc(),
        documents: documents,
        activeDocumentId: _string(map, 'activeDocumentId'),
        section: map['section'] as String? ?? 'explorer',
        bottomPanel: map['bottomPanel'] as String? ?? 'terminal',
        bottomVisible: map['bottomVisible'] as bool? ?? true,
        inspectorVisible: map['inspectorVisible'] as bool? ?? true,
        selectedBackendId: map['selectedBackendId'] as String? ?? 'ket.local.statevector',
        selectedTargetId: map['selectedTargetId'] as String? ?? 'local-statevector',
        noisePresetId: map['noisePresetId'] as String? ?? 'ideal',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(WorkspaceSession session) async {
    await rootDirectory.create(recursive: true);
    final file = _sessionFile;
    final temporary = File('${file.path}.tmp');
    final payload = <String, Object?>{
      'version': 1,
      'savedAt': session.savedAt.toUtc().toIso8601String(),
      'activeDocumentId': session.activeDocumentId,
      'section': session.section,
      'bottomPanel': session.bottomPanel,
      'bottomVisible': session.bottomVisible,
      'inspectorVisible': session.inspectorVisible,
      'selectedBackendId': session.selectedBackendId,
      'selectedTargetId': session.selectedTargetId,
      'noisePresetId': session.noisePresetId,
      'documents': <Object?>[
        for (final document in session.documents)
          <String, Object?>{
            'id': document.id,
            'title': document.title,
            'languageId': document.languageId,
            'path': document.path,
            'text': document.text,
            'savedText': document.savedText,
          },
      ],
    };
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = _sessionFile;
    if (await file.exists()) await file.delete();
  }

  String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) throw FormatException('$key must be a string.');
    return value;
  }
}
