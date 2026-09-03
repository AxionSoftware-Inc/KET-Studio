/// Scientific workflow graph used by the KET workspace view.
final class WorkspaceGraph {
  const WorkspaceGraph({required this.nodes, required this.edges});

  final List<WorkspaceNode> nodes;
  final List<WorkspaceEdge> edges;
}

enum WorkspaceNodeKind {
  source,
  hamiltonian,
  ansatz,
  circuit,
  transpilation,
  backend,
  measurement,
  optimizer,
  experiment,
  artifact,
  result,
}

final class WorkspaceNode {
  const WorkspaceNode({
    required this.id,
    required this.kind,
    required this.label,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final WorkspaceNodeKind kind;
  final String label;
  final Map<String, Object?> metadata;
}

final class WorkspaceEdge {
  const WorkspaceEdge({
    required this.from,
    required this.to,
    this.label,
  });

  final String from;
  final String to;
  final String? label;
}
