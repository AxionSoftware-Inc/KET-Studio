import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/experiments/experiment_record.dart';
import '../../core/quantum/quantum_backend.dart';

final class FileExperimentStore implements ExperimentStore {
  FileExperimentStore(this.rootDirectory);

  final Directory rootDirectory;
  final Map<String, StreamController<List<ExperimentRecord>>> _projectStreams =
      <String, StreamController<List<ExperimentRecord>>>{};

  Future<void> initialize() async {
    await rootDirectory.create(recursive: true);
  }

  Directory _recordsDirectory() => Directory(p.join(rootDirectory.path, 'records'));
  Directory _artifactsDirectory(String recordId) =>
      Directory(p.join(rootDirectory.path, 'artifacts', recordId));
  File _recordFile(String id) => File(p.join(_recordsDirectory().path, '$id.json'));

  @override
  Future<void> save(ExperimentRecord record) async {
    await initialize();
    await _recordsDirectory().create(recursive: true);
    final file = _recordFile(record.id);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_encodeRecord(record)),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    await _publish(record.projectId);
  }

  @override
  Future<ExperimentRecord?> get(String id) async {
    final file = _recordFile(id);
    if (!await file.exists()) return null;
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) throw FormatException('Invalid experiment record: $id');
    return _decodeRecord(Map<String, Object?>.from(raw));
  }

  @override
  Stream<List<ExperimentRecord>> watchProject(String projectId) async* {
    yield await _listProject(projectId);
    final controller = _projectStreams.putIfAbsent(
      projectId,
      () => StreamController<List<ExperimentRecord>>.broadcast(sync: true),
    );
    yield* controller.stream;
  }

  @override
  Future<void> delete(String id) async {
    final existing = await get(id);
    final file = _recordFile(id);
    if (await file.exists()) await file.delete();
    final artifacts = _artifactsDirectory(id);
    if (await artifacts.exists()) await artifacts.delete(recursive: true);
    if (existing != null) await _publish(existing.projectId);
  }

  Future<ExperimentArtifact> persistJsonArtifact({
    required String recordId,
    required String kind,
    required Object? value,
    String mimeType = 'application/json',
  }) async {
    final directory = _artifactsDirectory(recordId);
    await directory.create(recursive: true);
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(value));
    final digest = sha256.convert(bytes).toString();
    final safeKind = kind.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final file = File(p.join(directory.path, '$safeKind-$digest.json'));
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    return ExperimentArtifact(
      id: '$recordId:$safeKind:$digest',
      kind: kind,
      uri: file.absolute.uri,
      sha256: digest,
      mimeType: mimeType,
      metadata: <String, Object?>{'bytes': bytes.length},
    );
  }

  Future<List<ExperimentRecord>> _listProject(String projectId) async {
    final directory = _recordsDirectory();
    if (!await directory.exists()) return const <ExperimentRecord>[];
    final records = <ExperimentRecord>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final raw = jsonDecode(await entity.readAsString());
        if (raw is! Map) continue;
        final record = _decodeRecord(Map<String, Object?>.from(raw));
        if (record.projectId == projectId) records.add(record);
      } catch (_) {
        // A malformed record does not make the entire experiment history unusable.
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<ExperimentRecord>.unmodifiable(records);
  }

  Future<void> _publish(String projectId) async {
    final controller = _projectStreams[projectId];
    if (controller == null || controller.isClosed) return;
    controller.add(await _listProject(projectId));
  }

  Map<String, Object?> _encodeRecord(ExperimentRecord record) => <String, Object?>{
        'version': 1,
        'id': record.id,
        'createdAt': record.createdAt.toUtc().toIso8601String(),
        'projectId': record.projectId,
        'sourceRevision': record.sourceRevision,
        'environmentFingerprint': record.environmentFingerprint,
        'backendId': record.backendId,
        'targetId': record.targetId,
        'programFormat': record.programFormat.name,
        'shots': record.shots,
        'seed': record.seed,
        'parameters': record.parameters,
        'dependencies': record.dependencies,
        'backendMetadata': record.backendMetadata,
        'artifacts': record.artifacts.map(_encodeArtifact).toList(),
      };

  Map<String, Object?> _encodeArtifact(ExperimentArtifact artifact) => <String, Object?>{
        'id': artifact.id,
        'kind': artifact.kind,
        'uri': artifact.uri.toString(),
        'sha256': artifact.sha256,
        'mimeType': artifact.mimeType,
        'metadata': artifact.metadata,
      };

  ExperimentRecord _decodeRecord(Map<String, Object?> map) {
    if (map['version'] != 1) {
      throw FormatException('Unsupported experiment record version: ${map['version']}');
    }
    final formatName = map['programFormat'];
    final format = QuantumProgramFormat.values.where((item) => item.name == formatName).firstOrNull;
    if (format == null) throw FormatException('Unknown program format: $formatName');
    return ExperimentRecord(
      id: _string(map, 'id'),
      createdAt: DateTime.parse(_string(map, 'createdAt')).toUtc(),
      projectId: _string(map, 'projectId'),
      sourceRevision: _string(map, 'sourceRevision'),
      environmentFingerprint: _string(map, 'environmentFingerprint'),
      backendId: _string(map, 'backendId'),
      targetId: _string(map, 'targetId'),
      programFormat: format,
      shots: _integer(map, 'shots'),
      seed: map['seed'] as int?,
      parameters: map['parameters'] is Map
          ? (map['parameters']! as Map).map(
              (key, value) => MapEntry('$key', (value as num).toDouble()),
            )
          : const <String, double>{},
      dependencies: map['dependencies'] is Map
          ? (map['dependencies']! as Map).map((key, value) => MapEntry('$key', '$value'))
          : const <String, String>{},
      backendMetadata: map['backendMetadata'] is Map
          ? Map<String, Object?>.from(map['backendMetadata']! as Map)
          : const <String, Object?>{},
      artifacts: map['artifacts'] is List
          ? (map['artifacts']! as List)
              .map((item) => _decodeArtifact(Map<String, Object?>.from(item as Map)))
              .toList(growable: false)
          : const <ExperimentArtifact>[],
    );
  }

  ExperimentArtifact _decodeArtifact(Map<String, Object?> map) => ExperimentArtifact(
        id: _string(map, 'id'),
        kind: _string(map, 'kind'),
        uri: Uri.parse(_string(map, 'uri')),
        sha256: _string(map, 'sha256'),
        mimeType: map['mimeType'] as String?,
        metadata: map['metadata'] is Map
            ? Map<String, Object?>.from(map['metadata']! as Map)
            : const <String, Object?>{},
      );

  String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) throw FormatException('$key must be a string.');
    return value;
  }

  int _integer(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  Future<void> dispose() async {
    for (final controller in _projectStreams.values) {
      await controller.close();
    }
    _projectStreams.clear();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
