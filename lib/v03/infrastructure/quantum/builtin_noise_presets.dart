import '../../core/quantum/noise_model.dart';

final class BuiltinNoisePresetRepository implements NoisePresetRepository {
  const BuiltinNoisePresetRepository();

  static const List<NoisePreset> _presets = <NoisePreset>[
    NoisePreset(
      id: 'ideal',
      name: 'Ideal',
      description: 'No synthetic noise. Useful as the control run.',
      model: NoiseModel(metadata: <String, Object?>{'preset': 'ideal'}),
    ),
    NoisePreset(
      id: 'nisq-light',
      name: 'NISQ Light',
      description: 'Low single-qubit depolarizing and readout error.',
      model: NoiseModel(
        depolarizing: <DepolarizingNoise>[
          DepolarizingNoise(qubits: <int>[0], probability: 0.002),
          DepolarizingNoise(qubits: <int>[1], probability: 0.002),
        ],
        readout: <ReadoutNoise>[
          ReadoutNoise(qubit: 0, p0To1: 0.01, p1To0: 0.015),
          ReadoutNoise(qubit: 1, p0To1: 0.01, p1To0: 0.015),
        ],
        metadata: <String, Object?>{'preset': 'nisq-light'},
      ),
    ),
    NoisePreset(
      id: 'nisq-heavy',
      name: 'NISQ Heavy',
      description: 'Aggressive synthetic noise for robustness experiments.',
      model: NoiseModel(
        depolarizing: <DepolarizingNoise>[
          DepolarizingNoise(qubits: <int>[0], probability: 0.02),
          DepolarizingNoise(qubits: <int>[1], probability: 0.02),
        ],
        readout: <ReadoutNoise>[
          ReadoutNoise(qubit: 0, p0To1: 0.04, p1To0: 0.06),
          ReadoutNoise(qubit: 1, p0To1: 0.04, p1To0: 0.06),
        ],
        metadata: <String, Object?>{'preset': 'nisq-heavy'},
      ),
    ),
  ];

  @override
  Future<List<NoisePreset>> list() async => _presets;

  @override
  Future<NoisePreset?> get(String id) async {
    for (final preset in _presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
