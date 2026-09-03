import '../quantum/quantum_backend.dart';

/// Immutable metadata required to reproduce a scientific execution.
final class ExperimentRecord {
  const ExperimentRecord({
    required this.id,
    required this.createdAt,
    required this.projectId,
    required this.sourceRevision,
    required this.environmentFingerprint,
    required this.backendId,
    required this.targetId,
    required this.programFormat,
    required this.shots,
    this.seed,
    this.parameters = const <String, double>{},
    this.dependencies = const <String, String>{},
    this.backendMetadata = const <String, Object?>{},
    this.artifacts = const <ExperimentArtifact>[],
  });

  final String id;
  final DateTime createdAt;
  final String projectId;
  final String sourceRevision;
  final String environmentFingerprint;
  final String backendId;
  final String targetId;
  final QuantumProgramFormat programFormat;
  final int shots;
  final int? seed;
  final Map<String, double> parameters;
  final Map<String, String> dependencies;
  final Map<String, Object?> backendMetadata;
  final List<ExperimentArtifact> artifacts;
}

final class ExperimentArtifact {
  const ExperimentArtifact({
    required this.id,
    required this.kind,
    required this.uri,
    required this.sha256,
    this.mimeType,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String kind;
  final Uri uri;
  final String sha256;
  final String? mimeType;
  final Map<String, Object?> metadata;
}

abstract interface class ExperimentStore {
  Future<void> save(ExperimentRecord record);
  Future<ExperimentRecord?> get(String id);
  Stream<List<ExperimentRecord>> watchProject(String projectId);
  Future<void> delete(String id);
}
