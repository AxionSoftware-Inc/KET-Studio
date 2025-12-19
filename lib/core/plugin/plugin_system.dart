import 'package:flutter/material.dart';

enum PanelPosition { left, right, bottom }

abstract class ISidePanel {
  String get id;
  IconData get icon;
  String get title;
  String get tooltip;
  PanelPosition get position;
  Widget buildContent(BuildContext context);
}

class PluginRegistry {
  static final PluginRegistry _instance = PluginRegistry._internal();
  factory PluginRegistry() => _instance;
  PluginRegistry._internal();

  final Map<String, ISidePanel> _plugins = {};

  List<ISidePanel> get leftPanels => _plugins.values
      .where((p) => p.position == PanelPosition.left).toList();

  List<ISidePanel> get rightPanels => _plugins.values
      .where((p) => p.position == PanelPosition.right).toList();

  void register(ISidePanel panel) {
    _plugins[panel.id] = panel;
  }

  ISidePanel? getPanel(String id) => _plugins[id];
}