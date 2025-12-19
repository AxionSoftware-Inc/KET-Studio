import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/services/file_service.dart';
import '../../core/services/editor_service.dart';
import 'explorer_logic.dart';

class ExplorerWidget extends StatefulWidget {
  const ExplorerWidget({super.key});

  @override
  State<ExplorerWidget> createState() => _ExplorerWidgetState();
}

class _ExplorerWidgetState extends State<ExplorerWidget> {
  String? _currentProjectPath; // Tanlangan loyiha yo'li
  List<FileSystemEntity> _files = []; // Fayllar ro'yxati

  // --- ACTIONS ---

  void _openProject() async {
    final path = await FileService.pickDirectory();
    if (path != null) {
      setState(() {
        _currentProjectPath = path;
        _refreshFiles();
      });
    }
  }

  void _refreshFiles() {
    if (_currentProjectPath != null) {
      setState(() {
        _files = FileService.getFiles(_currentProjectPath!);
      });
    }
  }

  // Faylni bosganda Editorga xabar berish
  void _onFileClick(File file) async {
    try {
      String content = await FileService.readFile(file.path);
      String name = file.path.split(Platform.pathSeparator).last;

      // Editor Service orqali faylni ochamiz
      EditorService().openFile(name, content);
    } catch (e) {
      // Agar rasm yoki binary fayl bo'lsa ochmaymiz
      print("Faylni o'qib bo'lmadi: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Agar loyiha ochilmagan bo'lsa
    if (_currentProjectPath == null) {
      return Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636), // GitHub Green Button
            foregroundColor: Colors.white,
          ),
          onPressed: _openProject,
          icon: const Icon(Icons.folder_open, size: 16),
          label: const Text("Open Folder"),
        ),
      );
    }

    // 2. Loyiha ochiq bo'lsa - Daraxtni chizamiz
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loyiha nomi (Header)
        Container(
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          color: const Color(0xFF161B22),
          child: Row(
            children: [
              const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white70),
              const SizedBox(width: 5),
              Text(
                _currentProjectPath!.split(Platform.pathSeparator).last.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12
                ),
              ),
            ],
          ),
        ),

        // Fayllar ro'yxati (Recursiv widget)
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: _files.map((entity) => _buildNode(entity)).toList(),
          ),
        ),
      ],
    );
  }

  // --- REKURSIV DARAXT YASOVCHI ---
  Widget _buildNode(FileSystemEntity entity) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.')) return const SizedBox.shrink();

    bool isFile = entity is File;

    // --- UI QISMI ---
    return GestureDetector(
      // 1. CHAP TUGMA (Oddiy ochish)
      onTap: () {
        if (isFile) {
          _onFileClick(entity as File);
        } else {
          // Papka bo'lsa ExpansionTile o'zi ochiladi, shuning uchun bu yer bo'sh qolishi mumkin
          // yoki maxsus logika yozish mumkin.
          // Lekin ExpansionTile ishlatayotganimiz uchun onTap conflict bo'lishi mumkin.
          // Keling, eng oson yo'li: Fayl uchun alohida, Papka uchun alohida qilamiz.
        }
      },

      // 2. O'NG TUGMA (MENU CHIQARISH)
      onSecondaryTapDown: (details) {
        ExplorerLogic.showContextMenu(
            context,
            entity.path,
            details.globalPosition,
            _refreshFiles // Menu yopilgandan keyin yangilash uchun
        );
      },

      child: isFile
          ? _buildFileItem(name, entity as File)
          : _buildFolderItem(name, entity as Directory),
    );
  }

  // FAYL UI (Alohida qildim, toza bo'lishi uchun)
  Widget _buildFileItem(String name, File file) {
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 30), // Indent
      color: Colors.transparent, // Click sezishi uchun
      child: Row(
        children: [
          _getFileIcon(name),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  // PAPKA UI
  Widget _buildFolderItem(String name, Directory dir) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        dense: true,
        minTileHeight: 30,
        leading: const Icon(Icons.folder, size: 16, color: Colors.amber),
        title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        trailing: const SizedBox(),
        children: FileService.getFiles(dir.path)
            .map((child) => _buildNode(child)) // Rekursiya
            .toList(),
      ),
    );
  }

  Widget _getFileIcon(String filename) {
    if (filename.endsWith('.py')) return const Icon(Icons.data_object, size: 16, color: Colors.blueAccent);
    if (filename.endsWith('.dart')) return const Icon(Icons.flutter_dash, size: 16, color: Colors.blue);
    if (filename.endsWith('.json')) return const Icon(Icons.javascript, size: 16, color: Colors.yellow);
    return const Icon(Icons.insert_drive_file_outlined, size: 16, color: Colors.grey);
  }
}