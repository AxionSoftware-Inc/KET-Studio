import 'core/plugin/plugin_system.dart';

// Modullaringizni shu yerga import qilasiz
import 'modules/explorer/explorer_plugin.dart';
import 'modules/vizualization/viz_plugin.dart';

// Hamma plaginlar ro'yxati shu yerda turadi
void setupPlugins() {
  final registry = PluginRegistry();

  registry.register(ExplorerPlugin());
  registry.register(VisualizationPlugin());
  registry.register(MetricsPlugin());
  registry.register(CircuitInspectorPlugin());
  registry.register(VizHistoryPlugin());
  registry.register(ResourceEstimatorPlugin());

  // 3. kelajakda...
  // registry.register(MyNewAIPlugin());
}
