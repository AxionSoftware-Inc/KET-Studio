import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FileService {
  // Papka tanlash oynasini ochish
  static Future<String?> pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    return selectedDirectory;
  }

  // Papka ichidagi fayllarni o'qish
  static List<FileSystemEntity> getFiles(String path) {
    try {
      final dir = Directory(path);
      // Papka va fayllarni olamiz
      final List<FileSystemEntity> entities = dir.listSync();

      // Tartiblaymiz: Avval papkalar, keyin fayllar. Hammasi alifbo bo'yicha.
      entities.sort((a, b) {
        bool isADir = a is Directory;
        bool isBDir = b is Directory;

        if (isADir && !isBDir) return -1; // Papka tepaga
        if (!isADir && isBDir) return 1;  // Fayl pastga

        // Agar ikkalasi bir xil turdagi bo'lsa, nomiga qarab
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      return entities;
    } catch (e) {
      print("Xato: $e");
      return [];
    }
  }

  // Fayl ichini o'qish
  static Future<String> readFile(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  static Future<void> createFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
  }

  // 2. Papka yaratish
  static Future<void> createFolder(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // 3. O'chirish (Fayl yoki Papka)
  static Future<void> deleteEntity(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    }
  }

  // 4. Nomini o'zgartirish
  static Future<void> renameEntity(String oldPath, String newName) async {
    final parentPath = File(oldPath).parent.path;
    final newPath = "$parentPath${Platform.pathSeparator}$newName";
    if (await FileSystemEntity.isDirectory(oldPath)) {
      await Directory(oldPath).rename(newPath);
    } else {
      await File(oldPath).rename(newPath);
    }
  }
}