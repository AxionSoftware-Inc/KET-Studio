import 'package:flutter/material.dart';

class LayoutService extends ChangeNotifier {
  static final LayoutService _instance = LayoutService._internal();
  factory LayoutService() => _instance;
  LayoutService._internal();

  String? _activeLeftPanelId; // Boshida hech narsa ochiq emas
  String? _activeRightPanelId;
  bool _isBottomPanelVisible = false;

  String? get activeLeftPanelId => _activeLeftPanelId;
  String? get activeRightPanelId => _activeRightPanelId;
  bool get isBottomPanelVisible => _isBottomPanelVisible;

  void toggleLeftPanel(String panelId) {
    if (_activeLeftPanelId == panelId) {
      _activeLeftPanelId = null;
    } else {
      _activeLeftPanelId = panelId;
    }
    notifyListeners();
  }

  void toggleRightPanel(String panelId) {
    _activeRightPanelId = (_activeRightPanelId == panelId) ? null : panelId;
    notifyListeners();
  }

  void toggleBottomPanel() {
    _isBottomPanelVisible = !_isBottomPanelVisible;
    notifyListeners();
  }
}