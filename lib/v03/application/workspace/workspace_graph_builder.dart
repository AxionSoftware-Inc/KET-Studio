import '../../core/experiments/experiment_record.dart';
import '../../core/quantum/ket_ir.dart';
import '../../core/quantum/quantum_backend.dart';
import '../../core/quantum/transpiler_pipeline.dart';
import '../../core/workspace/workspace_graph.dart';

final class WorkspaceGraphBuilder {
  const WorkspaceGraphBuilder();

  WorkspaceGraph build({
    required String sourceLabel,
    required KetCircuit circuit,
    required String backendId,
    required String targetId,
    required QuantumResult result,
    required ExperimentRecord experiment,
    TranspilationTrace? transpilation,
  }) {
    final nodes = <WorkspaceNode>[
      WorkspaceNode(
        id: 'source',
        kind: WorkspaceNodeKind.source,
        label: sourceLabel,
      ),
      WorkspaceNode(
        id: 'circuit',
        kind: WorkspaceNodeKind.circuit,
        label: '${circuit.qubitCount} qubits • ${circuit.operations.length} ops',
        metadata: <String, Object?>{
          'qubitCount': circuit.qubitCount,
          'operationCount': circuit.operations.length,
        },
      ),
      if (transpilation != null)
        WorkspaceNode(
          id: 'transpilation',
          kind: WorkspaceNodeKind.transpilation,
          label: '${transpilation.stages.length} compiler passes',
          metadata: <String, Object?>{
            'inputOperations': transpilation.input.operations.length,
            'outputOperations': transpilation.output.operations.length,
          },
        ),
      WorkspaceNode(
        id: 'backend',
        kind: WorkspaceNodeKind.backend,
        label: '$backendId / $targetId',
      ),
      WorkspaceNode(
        id: 'measurement',
        kind: WorkspaceNodeKind.measurement,
        label: '${experiment.shots} shots',
      ),
      WorkspaceNode(
        id: 'result',
        kind: WorkspaceNodeKind.result,
        label: '${result.counts.length} outcomes',
        metadata: <String, Object?>{'counts': result.counts},
      ),
      WorkspaceNode(
        id: 'experiment',
        kind: WorkspaceNodeKind.experiment,
        label: experiment.id,
        metadata: <String, Object?>{
          'sourceRevision': experiment.sourceRevision,
          'environmentFingerprint': experiment.environmentFingerprint,
        },
      ),
      for (final artifact in experiment.artifacts)
        WorkspaceNode(
          id: 'artifact:${artifact.id}',
          kind: WorkspaceNodeKind.artifact,
          label: artifact.kind,
          metadata: <String, Object?>{
            'uri': artifact.uri.toString(),
            'sha256': artifact.sha256,
          },
        ),
    ];

    final circuitNext = transpilation == null ? 'backend' : 'transpilation';
    final edges = <WorkspaceEdge>[
      const WorkspaceEdge(from: 'source', to: 'circuit', label: 'parses to'),
      WorkspaceEdge(from: 'circuit', to: circuitNext, label: transpilation == null ? 'executes on' : 'compiled by'),
      if (transpilation != null)
        const WorkspaceEdge(from: 'transpilation', to: 'backend', label: 'targets'),
      const WorkspaceEdge(from: 'backend', to: 'measurement', label: 'produces'),
      const WorkspaceEdge(from: 'measurement', to: 'result', label: 'aggregates'),
      const WorkspaceEdge(from: 'result', to: 'experiment', label: 'recorded as'),
      for (final artifact in experiment.artifacts)
        WorkspaceEdge(from: 'experiment', to: 'artifact:${artifact.id}', label: 'owns'),
    ];
    return WorkspaceGraph(
      nodes: List<WorkspaceNode>.unmodifiable(nodes),
      edges: List<WorkspaceEdge>.unmodifiable(edges),
    );
  }
}
