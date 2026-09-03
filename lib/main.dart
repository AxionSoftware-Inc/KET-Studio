import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:window_manager/window_manager.dart';

import 'v03/presentation/app/ket_v03_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await flutter_acrylic.Window.initialize();
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: Size(1440, 920),
      minimumSize: Size(1100, 700),
      center: true,
      backgroundColor: Color(0xFF0B0F14),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'KET Studio',
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const KetV03App());
}
