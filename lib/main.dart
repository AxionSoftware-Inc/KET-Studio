import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as m;
import 'package:ket_studio/plugin_setup.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'dart:io';

// 1. ASOSIY LAYOUT (Oynalar tizimi)
import 'layout/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Window Manager va Acrylic initialization
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await flutter_acrylic.Window.initialize();
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      minimumSize: Size(800, 600),
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // HAMMA MODULLARNI SHU YERDA YUKLAYMIZ
  setupPlugins();

  runApp(const QuantumIDE());
}

class QuantumIDE extends StatelessWidget {
  const QuantumIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'KET Studio Pro',
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.purple,
        visualDensity: VisualDensity.standard,
        focusTheme: FocusThemeData(
          glowFactor: is10footScreen(context) ? 2.0 : 0.0,
        ),
      ),
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.purple,
        visualDensity: VisualDensity.standard,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: m.Material(
        type: m.MaterialType.transparency,
        child: const MainLayout(),
      ),
    );
  }
}
