final class WorkspaceDocumentState {
  const WorkspaceDocumentState({
    required this.id,
    required this.title,
    required this.languageId,
    required this.text,
    required this.savedText,
    this.path,
  });

  final String id;
  final String title;
  final String languageId;
  final String text;
  final String savedText;
  final String? path;

  bool get isDirty => text != savedText;
}

final class WorkspaceSession {
  const WorkspaceSession({
    required this.savedAt,
    required this.documents,
    required this.activeDocumentId,
    required this.section,
    required this.bottomPanel,
    required this.bottomVisible,
    required this.inspectorVisible,
    this.selectedBackendId = 'ket.local.statevector',
    this.selectedTargetId = 'local-statevector',
    this.noisePresetId = 'ideal',
  });

  final DateTime savedAt;
  final List<WorkspaceDocumentState> documents;
  final String activeDocumentId;
  final String section;
  final String bottomPanel;
  final bool bottomVisible;
  final bool inspectorVisible;
  final String selectedBackendId;
  final String selectedTargetId;
  final String noisePresetId;
}

abstract interface class WorkspaceSessionStore {
  Future<WorkspaceSession?> load();
  Future<void> save(WorkspaceSession session);
  Future<void> clear();
}
