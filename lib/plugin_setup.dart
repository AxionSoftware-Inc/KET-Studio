import 'core/plugin/plugin_system.dart';

// Modullaringizni shu yerga import qilasiz
import 'modules/explorer/explorer_plugin.dart';
import 'modules/search/search_plugin.dart';
import 'modules/tutorial/tutorial_plugin.dart';
import 'modules/vizualization/viz_plugin.dart';

// Hamma plaginlar ro'yxati shu yerda turadi
void setupPlugins() {
  final registry = PluginRegistry();

  // Left Sidebar (Reordered as requested)
  registry.register(ExplorerPlugin());
  registry.register(SearchPlugin());
  registry.register(TutorialPlugin());

  // Right Sidebar
  registry.register(VisualizationPlugin());
  registry.register(MetricsPlugin());
  registry.register(CircuitInspectorPlugin());
  registry.register(VizHistoryPlugin());
  registry.register(ResourceEstimatorPlugin());
}
