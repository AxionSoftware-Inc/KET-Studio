import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/core/workspace/workspace_session.dart';
import 'package:ket_studio/v03/infrastructure/workspace/file_workspace_session_store.dart';

void main() {
  test('workspace session round-trips dirty documents and quantum target state', () async {
    final root = await Directory.systemTemp.createTemp('ket-session-test-');
    addTearDown(() => root.delete(recursive: true));
    final store = FileWorkspaceSessionStore(root);
    final session = WorkspaceSession(
      savedAt: DateTime.utc(2026, 9, 3, 10),
      documents: const <WorkspaceDocumentState>[
        WorkspaceDocumentState(
          id: 'bell',
          title: 'bell.qasm',
          languageId: 'openqasm3',
          text: 'changed',
          savedText: 'saved',
          path: '/tmp/bell.qasm',
        ),
      ],
      activeDocumentId: 'bell',
      section: 'quantum',
      bottomPanel: 'output',
      bottomVisible: true,
      inspectorVisible: false,
      selectedBackendId: 'ket.vendor.cirq',
      selectedTargetId: 'cirq.simulator',
      noisePresetId: 'nisq-light',
    );

    await store.save(session);
    final restored = await store.load();

    expect(restored, isNotNull);
    expect(restored!.documents.single.isDirty, isTrue);
    expect(restored.selectedBackendId, 'ket.vendor.cirq');
    expect(restored.selectedTargetId, 'cirq.simulator');
    expect(restored.noisePresetId, 'nisq-light');
    expect(restored.inspectorVisible, isFalse);
  });
}
