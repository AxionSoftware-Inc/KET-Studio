import 'package:fluent_ui/fluent_ui.dart';

class KetTheme {
  // --- PROFESSIONAL PALITRA (VS CODE STYLE) ---

  // Asosiy fonlar
  // Asosiy fonlar (Windows 11 Mica-like)
  static const Color bgCanvas = Color(0xFF1B1B1C);
  static const Color bgSidebar = Color(0xFF202021);
  static const Color bgActivityBar = Color(0xFF181818);
  static const Color bgHeader = Color(0xFF252526);

  // Chegaralar
  static const Color border = Color(0xFF2B2B2C);

  // Matnlar
  static const Color textMain = Color(0xFFE0E0E0);
  static const Color textMuted = Color(0xFF8B8B8B);

  // Akcent
  static const Color accent = Color(0xFF9C27B0);
  static const Color selection = Color(0xFF3E3E42);

  // --- STYLES ---
  static const EdgeInsets panelPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  static Decoration sidebarDecoration = const BoxDecoration(
    color: bgSidebar,
    border: Border(right: BorderSide(color: Colors.black, width: 0.5)),
  );
}
