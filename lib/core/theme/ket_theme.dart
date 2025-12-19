import 'package:flutter/material.dart';

class KetTheme {
  // --- PROFESSIONAL PALITRA (VS CODE STYLE) ---

  // Asosiy fonlar
  static const Color bgCanvas = Color(0xFF1E1E1E);      // Editor foni
  static const Color bgSidebar = Color(0xFF252526);     // Yon panel foni
  static const Color bgActivityBar = Color(0xFF333333); // Eng chap panel
  static const Color bgHeader = Color(0xFF2D2D2D);      // Sarlavhalar foni (Tablar)

  // Chegaralar (Juda nozik)
  static const Color border = Color(0xFF1E1E1E);        // Ajratuvchi chiziqlar

  // Matnlar
  static const Color textMain = Color(0xFFCCCCCC);      // Asosiy oqish matn
  static const Color textMuted = Color(0xFF969696);     // Xira matn

  // Akcent (Faqat muhim joylar uchun)
  static const Color accent = Color(0xFF007ACC);        // VS Code Blue (yoki o'zingiz istagan rang)
  static const Color selection = Color(0xFF264F78);     // Tanlangan qator foni

  // --- STYLES ---

  // Oddiy tekis chiziq (Headerlar ostiga)
  static Border sideBorder = const Border(
    right: BorderSide(color: Colors.black, width: 1),
  );

  static Border bottomBorder = const Border(
    bottom: BorderSide(color: Colors.black, width: 1),
  );
}