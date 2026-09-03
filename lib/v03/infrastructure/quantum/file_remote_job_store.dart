import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/quantum/quantum_backend.dart';
import '../../core/quantum/remote_job.dart';

final class FileRemoteJobStore implements RemoteJobStore {
  FileRemoteJobStore(this.root);

  final Directory root;

  File _file(String id) => File(p.join(root.path, '${_safe(id)}.json'));

  @override
  Future<void> save(RemoteJobRecord record) async {
    await root.create(recursive: true);
    final file = _file(record.id);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_encode(record)),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  @override
  Future<RemoteJobRecord?> get(String id) async {
    final file = _file(id);
    if (!await file.exists()) return null;
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) throw FormatException('Remote job record root must be an object.');
    return _decode(Map<String, Object?>.from(raw));
  }

  @override
  Future<List<RemoteJobRecord>> list({String? backendId}) async {
    if (!await root.exists()) return const <RemoteJobRecord>[];
    final values = <RemoteJobRecord>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final raw = jsonDecode(await entity.readAsString());
        if (raw is! Map) continue;
        final record = _decode(Map<String, Object?>.from(raw));
        if (backendId == null || record.backendId == backendId) values.add(record);
      } catch (_) {
        // Corrupt records are isolated and can be diagnosed separately.
      }
    }
    values.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<RemoteJobRecord>.unmodifiable(values);
  }

  @override
  Future<void> delete(String id) async {
    final file = _file(id);
    if (await file.exists()) await file.delete();
  }

  Map<String, Object?> _encode(RemoteJobRecord record) => <String, Object?>{
        'version': 1,
        'id': record.id,
        'jobId': record.jobId,
        'backendId': record.backendId,
        'targetId': record.targetId,
        'state': record.state.name,
        'createdAt': record.createdAt.toUtc().toIso8601String(),
        'updatedAt': record.updatedAt.toUtc().toIso8601String(),
        'programFormat': record.programFormat.name,
        'programHash': record.programHash,
        'shots': record.shots,
        'seed': record.seed,
        'metadata': record.metadata,
      };

  RemoteJobRecord _decode(Map<String, Object?> map) {
    if (map['version'] != 1) throw FormatException('Unsupported remote job record version.');
    final state = QuantumJobState.values.where((item) => item.name == map['state']).firstOrNull;
    final format = QuantumProgramFormat.values.where((item) => item.name == map['programFormat']).firstOrNull;
    if (state == null || format == null) throw FormatException('Invalid remote job enum value.');
    return RemoteJobRecord(
      id: _string(map, 'id'),
      jobId: _string(map, 'jobId'),
      backendId: _string(map, 'backendId'),
      targetId: _string(map, 'targetId'),
      state: state,
      createdAt: DateTime.parse(_string(map, 'createdAt')).toUtc(),
      updatedAt: DateTime.parse(_string(map, 'updatedAt')).toUtc(),
      programFormat: format,
      programHash: _string(map, 'programHash'),
      shots: map['shots'] as int? ?? 0,
      seed: map['seed'] as int?,
      metadata: map['metadata'] is Map
          ? Map<String, Object?>.from(map['metadata']! as Map)
          : const <String, Object?>{},
    );
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) throw FormatException('$key must be a string.');
    return value;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
