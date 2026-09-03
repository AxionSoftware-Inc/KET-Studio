import 'experiment_record.dart';

final class ExperimentResultSnapshot {
  const ExperimentResultSnapshot({
    required this.record,
    this.counts = const <String, int>{},
    this.probabilities = const <String, double>{},
  });

  final ExperimentRecord record;
  final Map<String, int> counts;
  final Map<String, double> probabilities;
}

final class ExperimentComparison {
  const ExperimentComparison({
    required this.left,
    required this.right,
    required this.sameSource,
    required this.sameBackend,
    required this.totalVariationDistance,
    required this.maxProbabilityDelta,
    required this.shotDelta,
    required this.changedArtifacts,
  });

  final ExperimentResultSnapshot left;
  final ExperimentResultSnapshot right;
  final bool sameSource;
  final bool sameBackend;
  final double totalVariationDistance;
  final double maxProbabilityDelta;
  final int shotDelta;
  final Set<String> changedArtifacts;
}

abstract interface class ExperimentLab {
  Future<List<ExperimentRecord>> list(String projectId);
  Future<ExperimentResultSnapshot> load(String recordId);
  Future<ExperimentComparison> compare(String leftId, String rightId);
}
