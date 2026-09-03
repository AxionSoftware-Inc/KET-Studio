import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../core/experiments/experiment_lab.dart';
import '../../core/experiments/experiment_record.dart';
import 'file_experiment_store.dart';

final class FileExperimentLab implements ExperimentLab {
  const FileExperimentLab(this.store);

  final FileExperimentStore store;

  @override
  Future<List<ExperimentRecord>> list(String projectId) async {
    return store.watchProject(projectId).first;
  }

  @override
  Future<ExperimentResultSnapshot> load(String recordId) async {
    final record = await store.get(recordId);
    if (record == null) throw StateError('Unknown experiment: $recordId');
    final artifact = record.artifacts.where((item) => item.kind == 'quantum-result').firstOrNull;
    if (artifact == null || artifact.uri.scheme != 'file') {
      return ExperimentResultSnapshot(record: record);
    }
    final file = File.fromUri(artifact.uri);
    if (!await file.exists()) return ExperimentResultSnapshot(record: record);
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) return ExperimentResultSnapshot(record: record);
    final map = Map<String, Object?>.from(raw);
    return ExperimentResultSnapshot(
      record: record,
      counts: map['counts'] is Map
          ? (map['counts']! as Map).map((key, value) => MapEntry('$key', value as int))
          : const <String, int>{},
      probabilities: map['probabilities'] is Map
          ? (map['probabilities']! as Map)
              .map((key, value) => MapEntry('$key', (value as num).toDouble()))
          : const <String, double>{},
    );
  }

  @override
  Future<ExperimentComparison> compare(String leftId, String rightId) async {
    final values = await Future.wait<ExperimentResultSnapshot>(<Future<ExperimentResultSnapshot>>[
      load(leftId),
      load(rightId),
    ]);
    final left = values[0];
    final right = values[1];
    final keys = <String>{
      ...left.probabilities.keys,
      ...right.probabilities.keys,
      ...left.counts.keys,
      ...right.counts.keys,
    };

    final leftDistribution = _distribution(left, keys);
    final rightDistribution = _distribution(right, keys);
    var l1 = 0.0;
    var maxDelta = 0.0;
    for (final key in keys) {
      final delta = (leftDistribution[key]! - rightDistribution[key]!).abs();
      l1 += delta;
      maxDelta = math.max(maxDelta, delta);
    }

    final leftArtifacts = <String>{for (final item in left.record.artifacts) '${item.kind}:${item.sha256}'};
    final rightArtifacts = <String>{for (final item in right.record.artifacts) '${item.kind}:${item.sha256}'};
    return ExperimentComparison(
      left: left,
      right: right,
      sameSource: left.record.sourceRevision == right.record.sourceRevision,
      sameBackend: left.record.backendId == right.record.backendId &&
          left.record.targetId == right.record.targetId,
      totalVariationDistance: l1 / 2,
      maxProbabilityDelta: maxDelta,
      shotDelta: right.record.shots - left.record.shots,
      changedArtifacts: <String>{
        ...leftArtifacts.difference(rightArtifacts),
        ...rightArtifacts.difference(leftArtifacts),
      },
    );
  }

  Map<String, double> _distribution(ExperimentResultSnapshot value, Set<String> keys) {
    if (value.probabilities.isNotEmpty) {
      return <String, double>{for (final key in keys) key: value.probabilities[key] ?? 0};
    }
    final shots = value.counts.values.fold<int>(0, (sum, count) => sum + count);
    if (shots <= 0) return <String, double>{for (final key in keys) key: 0};
    return <String, double>{
      for (final key in keys) key: (value.counts[key] ?? 0) / shots,
    };
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
