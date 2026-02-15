import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class FileService extends ChangeNotifier {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  String _rootPath = Directory.current.path;
  String get rootPath => _rootPath;

  void setRootPath(String path) {
    _rootPath = path;
    notifyListeners();
  }

  // Papka tanlash oynasini ochish
  Future<String?> pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setRootPath(selectedDirectory);
    }
    return selectedDirectory;
  }

  // Fayl tanlash oynasini ochish
  Future<File?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  // Faylni boshqa nom bilan saqlash
  Future<String?> saveFileAs(String suggestedName, String content) async {
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save File As',
      fileName: suggestedName,
    );
    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsString(content);
      return outputPath;
    }
    return null;
  }

  // Papka ichidagi fayllarni o'qish
  List<FileSystemEntity> getFiles(String path) {
    try {
      final dir = Directory(path);
      final List<FileSystemEntity> entities = dir.listSync().where((e) {
        final name = e.path.split(Platform.pathSeparator).last;
        return !name.startsWith(".ket_") &&
            name != "ket_viz.py" &&
            name != "ketviz.py";
      }).toList();

      entities.sort((a, b) {
        bool isADir = a is Directory;
        bool isBDir = b is Directory;

        if (isADir && !isBDir) return -1;
        if (!isADir && isBDir) return 1;

        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      return entities;
    } catch (e) {
      debugPrint("Xato: $e");
      return [];
    }
  }

  // Fayl ichini o'qish
  Future<String> readFile(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  Future<void> createFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
  }

  // 2. Papka yaratish
  Future<void> createFolder(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // 3. O'chirish (Fayl yoki Papka)
  Future<void> deleteEntity(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    }
  }

  // 4. Nomini o'zgartirish
  Future<void> renameEntity(String oldPath, String newName) async {
    final parentPath = File(oldPath).parent.path;
    final newPath = "$parentPath${Platform.pathSeparator}$newName";
    if (await FileSystemEntity.isDirectory(oldPath)) {
      await Directory(oldPath).rename(newPath);
    } else {
      await File(oldPath).rename(newPath);
    }
  }
}
