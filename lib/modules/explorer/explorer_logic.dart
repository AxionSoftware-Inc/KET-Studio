import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/services/file_service.dart';

class ExplorerLogic {

  // O'ng tugma menyusi (Context Menu)
  static void showContextMenu(BuildContext context, String path, Offset position, VoidCallback onRefresh) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF252526),
      // MANA SHU YERDA TIPLARNI TO'G'RILADIK:
      items: <PopupMenuEntry<dynamic>>[
        _buildMenuItem("New File", Icons.insert_drive_file, () => _showNameDialog(context, path, isFile: true, onDone: onRefresh)),
        _buildMenuItem("New Folder", Icons.folder, () => _showNameDialog(context, path, isFile: false, onDone: onRefresh)),
        const PopupMenuDivider(height: 10), // Chiziq
        _buildMenuItem("Rename", Icons.edit, () => _showRenameDialog(context, path, onDone: onRefresh)),
        _buildMenuItem("Delete", Icons.delete, () => _deleteItem(context, path, onRefresh)),
      ],
    );
  }

  // Menyu elementi shabloni
  static PopupMenuItem<dynamic> _buildMenuItem(String title, IconData icon, VoidCallback onTap) {
    return PopupMenuItem(
      onTap: onTap,
      height: 32,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  // --- DIALOGLAR ---

  // 1. Yangi narsa yaratish dialogi
  static void _showNameDialog(BuildContext context, String parentPath, {required bool isFile, required VoidCallback onDone}) {
    // Agar fayl ustiga bosilgan bo'lsa, uning ota papkasini olamiz
    if (FileSystemEntity.isFileSync(parentPath)) {
      parentPath = File(parentPath).parent.path;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252526),
        title: Text(isFile ? "New File" : "New Folder", style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          cursorColor: Colors.blue,
          decoration: const InputDecoration(
            hintText: "Enter name...",
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final fullPath = "$parentPath${Platform.pathSeparator}$name";
                try {
                  if (isFile) {
                    await FileService.createFile(fullPath);
                  } else {
                    await FileService.createFolder(fullPath);
                  }
                  onDone();
                  Navigator.pop(context);
                } catch (e) {
                  print("Error creating: $e");
                }
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  // 2. Rename Dialog
  static void _showRenameDialog(BuildContext context, String oldPath, {required VoidCallback onDone}) {
    final oldName = oldPath.split(Platform.pathSeparator).last;
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252526),
        title: const Text("Rename", style: TextStyle(color: Colors.white, fontSize: 14)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  await FileService.renameEntity(oldPath, controller.text.trim());
                  onDone();
                  Navigator.pop(context);
                } catch (e) {
                  print("Rename error: $e");
                }
              }
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  // 3. Delete Logic
  static void _deleteItem(BuildContext context, String path, VoidCallback onDone) async {
    try {
      await FileService.deleteEntity(path);
      onDone();
    } catch (e) {
      print("Delete error: $e");
    }
  }
}