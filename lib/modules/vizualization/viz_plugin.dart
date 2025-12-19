import 'package:flutter/material.dart';
import '../../core/plugin/plugin_system.dart';

class VisualizationPlugin implements ISidePanel {
  @override
  String get id => 'vizualization'; // Unikal ID

  @override
  IconData get icon => Icons.pie_chart_outline; // Ikonka

  @override
  String get title => 'Quantum Viz';

  @override
  String get tooltip => 'Visualization Dashboard';

  @override
  PanelPosition get position => PanelPosition.right; // <--- O'NG TOMONGA

  @override
  Widget buildContent(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 50, color: Colors.purpleAccent),
            const SizedBox(height: 10),
            const Text("Bloch Sphere", style: TextStyle(color: Colors.white)),
            const SizedBox(height: 5),
            Container(width: 100, height: 2, color: Colors.green),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "Bu yerda kvant grafikalari chiziladi.\nHech narsa Explorerga bog'liq emas.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}