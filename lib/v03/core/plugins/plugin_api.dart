import '../quantum/quantum_backend.dart';

/// Versioned plugin API. Plugin implementations must not import UI internals.
abstract interface class KetPlugin {
  PluginManifest get manifest;
  Future<void> activate(PluginContext context);
  Future<void> deactivate();
}

final class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.apiVersion,
    this.description,
    this.capabilities = const <PluginCapability>{},
  });

  final String id;
  final String name;
  final String version;
  final String apiVersion;
  final String? description;
  final Set<PluginCapability> capabilities;
}

enum PluginCapability {
  quantumBackend,
  simulator,
  visualizer,
  analysis,
  language,
  hardwareProvider,
}

abstract interface class PluginContext {
  void registerQuantumBackend(QuantumBackend backend);
  void registerVisualizer(VisualizerContribution contribution);
  void registerAnalysis(AnalysisContribution contribution);
}

final class VisualizerContribution {
  const VisualizerContribution({
    required this.id,
    required this.displayName,
    required this.supportedKinds,
  });

  final String id;
  final String displayName;
  final Set<String> supportedKinds;
}

final class AnalysisContribution {
  const AnalysisContribution({
    required this.id,
    required this.displayName,
    required this.run,
  });

  final String id;
  final String displayName;
  final Future<Map<String, Object?>> Function(Map<String, Object?> input) run;
}
