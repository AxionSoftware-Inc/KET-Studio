import 'package:fluent_ui/fluent_ui.dart';

import '../workbench/ket_workbench.dart';

final class KetV03App extends StatelessWidget {
  const KetV03App({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'KET Studio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        cardColor: const Color(0xFF111820),
        focusTheme: const FocusThemeData(glowFactor: 0),
      ),
      home: const KetWorkbench(),
    );
  }
}
