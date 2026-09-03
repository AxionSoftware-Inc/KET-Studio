final class NoiseModel {
  const NoiseModel({
    this.depolarizing = const <DepolarizingNoise>[],
    this.relaxation = const <RelaxationNoise>[],
    this.readout = const <ReadoutNoise>[],
    this.metadata = const <String, Object?>{},
  });

  final List<DepolarizingNoise> depolarizing;
  final List<RelaxationNoise> relaxation;
  final List<ReadoutNoise> readout;
  final Map<String, Object?> metadata;
}

final class DepolarizingNoise {
  const DepolarizingNoise({required this.qubits, required this.probability})
      : assert(probability >= 0 && probability <= 1);

  final List<int> qubits;
  final double probability;
}

final class RelaxationNoise {
  const RelaxationNoise({
    required this.qubit,
    required this.t1Microseconds,
    required this.t2Microseconds,
    this.gateTimeNanoseconds,
  })  : assert(t1Microseconds > 0),
        assert(t2Microseconds > 0);

  final int qubit;
  final double t1Microseconds;
  final double t2Microseconds;
  final double? gateTimeNanoseconds;
}

final class ReadoutNoise {
  const ReadoutNoise({
    required this.qubit,
    required this.p0To1,
    required this.p1To0,
  })  : assert(p0To1 >= 0 && p0To1 <= 1),
        assert(p1To0 >= 0 && p1To0 <= 1);

  final int qubit;
  final double p0To1;
  final double p1To0;
}

abstract interface class NoisePresetRepository {
  Future<List<NoisePreset>> list();
  Future<NoisePreset?> get(String id);
}

final class NoisePreset {
  const NoisePreset({
    required this.id,
    required this.name,
    required this.model,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final NoiseModel model;
}
