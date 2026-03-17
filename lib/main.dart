import 'package:fluent_ui/fluent_ui.dart';
import 'package:ket_studio/plugin_setup.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'core/theme/ket_theme.dart';
import 'core/services/settings_service.dart';
import 'dart:io';

// 1. ASOSIY LAYOUT (Oynalar tizimi)
import 'layout/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Settings initialize
  await SettingsService().initialize();

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
      if (SettingsService().startMaximized) {
        await windowManager.maximize();
      }
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
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();

        return FluentApp(
          title: 'KET Studio Pro',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: FluentThemeData(
            brightness: Brightness.light,
            accentColor: settings.accentColor.toAccentColor(),
            fontFamily: KetTheme.globalFont.fontFamily,
            visualDensity: settings.compactMode
                ? VisualDensity.compact
                : VisualDensity.standard,
            scaffoldBackgroundColor: KetTheme.bgCanvas,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen(context) ? 2.0 : 0.0,
            ),
          ),
          darkTheme: FluentThemeData(
            brightness: Brightness.dark,
            accentColor: settings.accentColor.toAccentColor(),
            fontFamily: KetTheme.globalFont.fontFamily,
            visualDensity: settings.compactMode
                ? VisualDensity.compact
                : VisualDensity.standard,
            scaffoldBackgroundColor: KetTheme.bgCanvas,
          ),
          home: const MainLayout(),
        );
      },
    );
  }
}
