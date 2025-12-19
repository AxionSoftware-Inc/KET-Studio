import 'package:flutter/material.dart';
import '../core/services/menu_service.dart';
import '../core/services/file_service.dart';
import '../core/services/editor_service.dart';
import '../core/services/terminal_service.dart';
import '../core/services/execution_service.dart';
import '../modules/explorer/explorer_logic.dart'; // Logic kerak bo'lishi mumkin

// Dastur ishga tushganda bir marta chaqiriladi
void setupMenus(BuildContext context) {
  final menuService = MenuService();
  menuService.clear(); // Eskilarini tozalaymiz

  // ---------------- FILE MENU ----------------
  menuService.registerMenu("File", [
    MenuItemData(
      label: "New File",
      icon: Icons.insert_drive_file,
      shortcut: "Ctrl+N",
      onTap: () {
        // Bu yerda ExplorerLogic dagi dialog chaqirilishi mumkin
        // Hozircha oddiy print yoki EditorService funksiyasi
        EditorService().openFile("untitled.py", "");
      },
    ),
    MenuItemData(
      label: "Save File",
      icon: Icons.save,
      shortcut: "Ctrl+S",
      onTap: () async {
        await EditorService().saveActiveFile();
      },
    ),
    MenuItemData(
      label: "Open Folder",
      icon: Icons.folder_open,
      shortcut: "Ctrl+O",
      onTap: () async {
        // Bu funksiyani ExplorerWidgetdan tashqariga chiqarishimiz kerak bo'lishi mumkin
        // yoki GlobalEventBus ishlatish kerak.
        // Hozircha oddiy print:
        print("Open Folder bosildi");
      },
    ),
    MenuItemData(
      label: "Exit",
      icon: Icons.exit_to_app,
      onTap: () {
        // Dasturdan chiqish
      },
    ),
  ]);

  // ---------------- EDIT MENU ----------------
  menuService.registerMenu("Edit", [
    MenuItemData(label: "Undo", icon: Icons.undo, shortcut: "Ctrl+Z", onTap: () {}),
    MenuItemData(label: "Redo", icon: Icons.redo, shortcut: "Ctrl+Y", onTap: () {}),
    MenuItemData(label: "Cut", icon: Icons.content_cut, shortcut: "Ctrl+X", onTap: () {}),
    MenuItemData(label: "Copy", icon: Icons.content_copy, shortcut: "Ctrl+C", onTap: () {}),
    MenuItemData(label: "Paste", icon: Icons.content_paste, shortcut: "Ctrl+V", onTap: () {}),
  ]);

  // ---------------- RUN MENU ----------------
  menuService.registerMenu("Run", [
    MenuItemData(
      label: "Run without Debugging",
      icon: Icons.play_arrow,
      shortcut: "F5",
      onTap: () async {
        final active = EditorService().activeFile;
        if(active != null) {
          await EditorService().saveActiveFile();
          ExecutionService().runPython(active.path);
        }
      },
    ),
  ]);

  // ---------------- TERMINAL MENU ----------------
  menuService.registerMenu("Terminal", [
    MenuItemData(
      label: "New Terminal",
      icon: Icons.add_to_queue,
      onTap: () => TerminalService().write("New terminal session..."),
    ),
    MenuItemData(
      label: "Clear Terminal",
      icon: Icons.block,
      onTap: () => TerminalService().clear(),
    ),
  ]);
}