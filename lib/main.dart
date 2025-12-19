import 'package:flutter/material.dart';
import 'package:ket_studio/plugin_setup.dart';

// 1. ASOSIY LAYOUT (Oynalar tizimi)
import 'layout/main_layout.dart';

void main() {
  // HAMMA MODULLARNI SHU YERDA YUKLAYMIZ
  setupPlugins();

  runApp(const QuantumIDE());
}

class QuantumIDE extends StatelessWidget {
  const QuantumIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantum IDE Pro',
      debugShowCheckedModeBanner: false,

      // --- DIZAYN (THEME) ---
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E), // VS Code Dark fon rangi
        primaryColor: Colors.purpleAccent,

        // Matnlar stili (Google Fonts keyin qo'shiladi)
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
        ),

        // Scrollbarlar chiroyli va ingichka bo'lishi uchun
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(Colors.white24),
          thickness: MaterialStateProperty.all(6.0), // Ingichka scroll
          radius: const Radius.circular(3),
          thumbVisibility: MaterialStateProperty.all(true), // Doim ko'rinib turadi
        ),

        // Divider (Ajratuvchi chiziqlar) rangi
        dividerTheme: const DividerThemeData(
          color: Colors.black,
          thickness: 1,
        ),
      ),

      home: const MainLayout(),
    );
  }
}