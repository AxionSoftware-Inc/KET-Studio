import 'quantum_backend.dart';

final class RemoteJobRecord {
  const RemoteJobRecord({
    required this.id,
    required this.jobId,
    required this.backendId,
    required this.targetId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    required this.programFormat,
    required this.programHash,
    required this.shots,
    this.seed,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String jobId;
  final String backendId;
  final String targetId;
  final QuantumJobState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final QuantumProgramFormat programFormat;
  final String programHash;
  final int shots;
  final int? seed;
  final Map<String, Object?> metadata;

  RemoteJobRecord copyWith({
    QuantumJobState? state,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
  }) {
    return RemoteJobRecord(
      id: id,
      jobId: jobId,
      backendId: backendId,
      targetId: targetId,
      state: state ?? this.state,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      programFormat: programFormat,
      programHash: programHash,
      shots: shots,
      seed: seed,
      metadata: metadata ?? this.metadata,
    );
  }
}

abstract interface class RemoteJobStore {
  Future<void> save(RemoteJobRecord record);
  Future<RemoteJobRecord?> get(String id);
  Future<List<RemoteJobRecord>> list({String? backendId});
  Future<void> delete(String id);
}
