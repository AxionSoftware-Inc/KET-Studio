import 'package:flutter/foundation.dart';

enum WorkbenchSection {
  explorer,
  search,
  quantum,
  experiments,
  extensions,
}

enum WorkbenchBottomPanel {
  terminal,
  problems,
  output,
  debugConsole,
}

final class WorkbenchController extends ChangeNotifier {
  WorkbenchSection _section = WorkbenchSection.explorer;
  WorkbenchBottomPanel _bottomPanel = WorkbenchBottomPanel.terminal;
  bool _bottomVisible = true;
  bool _inspectorVisible = true;
  String _activeDocument = 'bell_state.py';

  WorkbenchSection get section => _section;
  WorkbenchBottomPanel get bottomPanel => _bottomPanel;
  bool get bottomVisible => _bottomVisible;
  bool get inspectorVisible => _inspectorVisible;
  String get activeDocument => _activeDocument;

  void selectSection(WorkbenchSection value) {
    if (_section == value) return;
    _section = value;
    notifyListeners();
  }

  void showBottomPanel(WorkbenchBottomPanel value) {
    final changed = !_bottomVisible || _bottomPanel != value;
    _bottomVisible = true;
    _bottomPanel = value;
    if (changed) notifyListeners();
  }

  void toggleBottomPanel() {
    _bottomVisible = !_bottomVisible;
    notifyListeners();
  }

  void toggleInspector() {
    _inspectorVisible = !_inspectorVisible;
    notifyListeners();
  }

  void openDocument(String name) {
    if (_activeDocument == name) return;
    _activeDocument = name;
    notifyListeners();
  }
}
