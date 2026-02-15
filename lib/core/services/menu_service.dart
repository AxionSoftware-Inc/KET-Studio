import 'package:flutter/material.dart';

// 1. Menyu Elementi Modeli
class MenuItemData {
  final String label; // Masalan: "New File"
  final IconData? icon; // Masalan: Icons.add
  final VoidCallback? onTap; // Bosilganda nima bo'lishi
  final String? shortcut; // Masalan: "Ctrl+N"
  final bool isSeparator;

  MenuItemData({
    this.label = "",
    this.onTap,
    this.icon,
    this.shortcut,
    this.isSeparator = false,
  });

  static MenuItemData separator() => MenuItemData(isSeparator: true);
}

// 2. Menyu Guruhi (File, Edit, View...)
class MenuGroup {
  final String title;
  final List<MenuItemData> items;

  MenuGroup({required this.title, required this.items});
}

// 3. Xizmat (Service)
class MenuService extends ChangeNotifier {
  // Singleton
  static final MenuService _instance = MenuService._internal();
  factory MenuService() => _instance;
  MenuService._internal();

  // Asosiy ro'yxat
  final List<MenuGroup> _menus = [];

  List<MenuGroup> get menus => _menus;

  // --- REGISTRATSIYA FUNKSIYASI ---
  // Bu funksiya orqali istalgan joydan menyu qo'shsa bo'ladi
  void registerMenu(String title, List<MenuItemData> items) {
    // Agar bu nomdagi menyu bor bo'lsa, ichiga qo'shamiz
    final existingIndex = _menus.indexWhere((m) => m.title == title);

    if (existingIndex != -1) {
      _menus[existingIndex].items.addAll(items);
    } else {
      _menus.add(MenuGroup(title: title, items: items));
    }
    notifyListeners(); // UI yangilansin
  }

  // Tozalash (kerak bo'lsa)
  void clear() {
    _menus.clear();
    notifyListeners();
  }
}
