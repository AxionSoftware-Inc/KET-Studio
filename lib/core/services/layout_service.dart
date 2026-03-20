import 'package:fluent_ui/fluent_ui.dart';

enum WorkspaceMode { code, circuit, analyze, ecosystem }

class WorkspacePreset {
  final WorkspaceMode mode;
  final String label;
  final String description;
  final IconData icon;
  final Set<String> leftPanelIds;
  final Set<String> rightPanelIds;
  final String? defaultLeftPanelId;
  final String? defaultRightPanelId;
  final bool supportsBottomPanel;
  final bool defaultBottomVisible;

  const WorkspacePreset({
    required this.mode,
    required this.label,
    required this.description,
    required this.icon,
    this.leftPanelIds = const {},
    this.rightPanelIds = const {},
    this.defaultLeftPanelId,
    this.defaultRightPanelId,
    this.supportsBottomPanel = false,
    this.defaultBottomVisible = false,
  });
}

class WorkspaceLayoutState {
  String? activeLeftPanelId;
  String? activeRightPanelId;
  bool isBottomPanelVisible;

  WorkspaceLayoutState({
    this.activeLeftPanelId,
    this.activeRightPanelId,
    required this.isBottomPanelVisible,
  });
}

class LayoutService extends ChangeNotifier {
  static final LayoutService _instance = LayoutService._internal();
  factory LayoutService() => _instance;
  LayoutService._internal();

  static const Map<WorkspaceMode, WorkspacePreset> _presetMap = {
    WorkspaceMode.code: WorkspacePreset(
      mode: WorkspaceMode.code,
      label: 'IDE',
      description: 'Full workspace',
      icon: FluentIcons.code,
      leftPanelIds: {'explorer', 'search', 'tutorial'},
      rightPanelIds: {'vizualization', 'metrics', 'viz_history', 'inspector', 'estimator'},
      defaultLeftPanelId: 'explorer',
      defaultRightPanelId: 'vizualization',
      supportsBottomPanel: true,
      defaultBottomVisible: true,
    ),
    // Keeping other modes for internal logic if needed, but the main one is now IDE
    WorkspaceMode.circuit: WorkspacePreset(
      mode: WorkspaceMode.circuit,
      label: 'Circuit',
      description: 'Focus on circuit details',
      icon: FluentIcons.developer_tools,
      rightPanelIds: {'inspector', 'estimator'},
      defaultRightPanelId: 'inspector',
    ),
    WorkspaceMode.analyze: WorkspacePreset(
      mode: WorkspaceMode.analyze,
      label: 'Analyze',
      description: 'Data analysis focused',
      icon: FluentIcons.analytics_report,
      rightPanelIds: {'vizualization', 'metrics', 'viz_history'},
      defaultRightPanelId: 'metrics',
      supportsBottomPanel: true,
      defaultBottomVisible: true,
    ),
    WorkspaceMode.ecosystem: WorkspacePreset(
      mode: WorkspaceMode.ecosystem,
      label: 'Ecosystem',
      description: 'Full overview',
      icon: FluentIcons.cube_shape,
      leftPanelIds: {'explorer', 'search', 'tutorial'},
      rightPanelIds: {'vizualization', 'metrics', 'viz_history', 'inspector', 'estimator'},
      defaultLeftPanelId: 'explorer',
      defaultRightPanelId: 'vizualization',
    ),
  };

  final Map<WorkspaceMode, WorkspaceLayoutState> _workspaceStates = {
    for (final preset in _presetMap.values)
      preset.mode: WorkspaceLayoutState(
        activeLeftPanelId: preset.defaultLeftPanelId,
        activeRightPanelId: preset.defaultRightPanelId,
        isBottomPanelVisible: preset.supportsBottomPanel
            ? preset.defaultBottomVisible
            : false,
      ),
  };

  WorkspaceMode _activeWorkspace = WorkspaceMode.code;

  List<WorkspacePreset> get workspaces =>
      WorkspaceMode.values.map((mode) => _presetMap[mode]!).toList();

  WorkspaceMode get activeWorkspace => _activeWorkspace;
  WorkspacePreset get activeWorkspacePreset => _presetMap[_activeWorkspace]!;

  WorkspaceLayoutState get _currentState => _workspaceStates[_activeWorkspace]!;

  String? get activeLeftPanelId => _currentState.activeLeftPanelId;
  String? get activeRightPanelId => _currentState.activeRightPanelId;
  bool get isBottomPanelVisible => _currentState.isBottomPanelVisible;

  List<String> get allowedLeftPanelIds =>
      activeWorkspacePreset.leftPanelIds.toList();
  List<String> get allowedRightPanelIds =>
      activeWorkspacePreset.rightPanelIds.toList();

  bool get supportsBottomPanel => activeWorkspacePreset.supportsBottomPanel;
  bool get hasLeftRail => activeWorkspacePreset.leftPanelIds.isNotEmpty;
  bool get hasRightRail => activeWorkspacePreset.rightPanelIds.isNotEmpty;

  void setWorkspace(WorkspaceMode mode) {
    if (_activeWorkspace == mode) return;
    _activeWorkspace = mode;
    _normalizeState(_currentState, activeWorkspacePreset);
    notifyListeners();
  }

  void toggleLeftPanel(String panelId) {
    if (!activeWorkspacePreset.leftPanelIds.contains(panelId)) return;
    _currentState.activeLeftPanelId = activeLeftPanelId == panelId ? null : panelId;
    notifyListeners();
  }

  void toggleRightPanel(String panelId) {
    if (!activeWorkspacePreset.rightPanelIds.contains(panelId)) return;
    _currentState.activeRightPanelId =
        activeRightPanelId == panelId ? null : panelId;
    notifyListeners();
  }

  void setRightPanel(String panelId) {
    if (!activeWorkspacePreset.rightPanelIds.contains(panelId)) return;
    if (_currentState.activeRightPanelId != panelId) {
      _currentState.activeRightPanelId = panelId;
      notifyListeners();
    }
  }

  void toggleBottomPanel() {
    if (!supportsBottomPanel) return;
    _currentState.isBottomPanelVisible = !_currentState.isBottomPanelVisible;
    notifyListeners();
  }

  void _normalizeState(WorkspaceLayoutState state, WorkspacePreset preset) {
    if (!preset.leftPanelIds.contains(state.activeLeftPanelId)) {
      state.activeLeftPanelId = preset.defaultLeftPanelId;
    }

    if (!preset.rightPanelIds.contains(state.activeRightPanelId)) {
      state.activeRightPanelId = preset.defaultRightPanelId;
    }

    if (!preset.supportsBottomPanel) {
      state.isBottomPanelVisible = false;
    }
  }
}
