import 'dart:async';
import 'dart:io';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/python.dart';

import '../models/editor_file.dart';
import 'settings_service.dart';

class EditorService extends ChangeNotifier {
  static final EditorService _instance = EditorService._internal();
  factory EditorService() => _instance;
  EditorService._internal();

  final List<EditorFile> _files = [];
  int _activeFileIndex = -1;
  final ValueNotifier<bool> hasActiveFile = ValueNotifier(false);
  final Map<CodeController, VoidCallback> _autoSaveListeners = {};
  final Map<CodeController, Timer> _autoSaveTimers = {};

  int cursorLine = 1;
  int cursorColumn = 1;

  void updateCursorPosition(int line, int col) {
    cursorLine = line;
    cursorColumn = col;
    notifyListeners();
  }

  List<EditorFile> get files => _files;
  int get activeFileIndex => _activeFileIndex;

  EditorFile? get activeFile {
    if (_activeFileIndex >= 0 && _activeFileIndex < _files.length) {
      return _files[_activeFileIndex];
    }
    return null;
  }

  void openFile(String fileName, String content, {String? realPath}) {
    final existingIndex = _files.indexWhere((f) => f.name == fileName);
    if (existingIndex != -1) {
      _activeFileIndex = existingIndex;
      notifyListeners();
      return;
    }

    final controller = CodeController(
      text: content,
      language: fileName.endsWith('.dart') ? dart : python,
    );

    final newFile = EditorFile(
      path: realPath ?? "/fake/path/$fileName",
      name: fileName,
      extension: fileName.split('.').last,
      controller: controller,
    );

    _bindAutoSave(newFile);
    _files.add(newFile);
    _activeFileIndex = _files.length - 1;
    hasActiveFile.value = true;
    notifyListeners();
  }

  void closeFile(int index) {
    final removed = _files.removeAt(index);
    _unbindAutoSave(removed);

    if (_files.isEmpty) {
      _activeFileIndex = -1;
      hasActiveFile.value = false;
    } else if (index <= _activeFileIndex) {
      _activeFileIndex = (_activeFileIndex - 1).clamp(0, _files.length - 1);
    }
    notifyListeners();
  }

  void setActiveIndex(int index) {
    _activeFileIndex = index;
    notifyListeners();
  }

  Future<void> saveActiveFile() async {
    final file = activeFile;
    if (file == null) return;

    if (!file.path.startsWith('/fake')) {
      try {
        await File(file.path).writeAsString(file.controller.text);
        file.isModified = false;
        debugPrint("Saved: ${file.path}");
      } catch (e) {
        debugPrint("Save error: $e");
      }
    } else {
      debugPrint("File is virtual. Use Save As.");
    }
  }

  void renameFile(String oldPath, String newPath) {
    final index = _files.indexWhere((f) => f.path == oldPath);
    if (index == -1) return;

    final oldFile = _files[index];
    _unbindAutoSave(oldFile);

    final newName = newPath.split(Platform.pathSeparator).last;
    final updatedFile = EditorFile(
      path: newPath,
      name: newName,
      extension: newName.split('.').last,
      controller: oldFile.controller,
      isModified: oldFile.isModified,
    );

    _files[index] = updatedFile;
    _bindAutoSave(updatedFile);
    notifyListeners();
  }

  Future<void> saveAll() async {
    for (final file in _files) {
      if (!file.path.startsWith('/fake')) {
        try {
          await File(file.path).writeAsString(file.controller.text);
          file.isModified = false;
        } catch (e) {
          debugPrint("Save error: $e");
        }
      }
    }
  }

  Future<void> revertFile() async {
    final file = activeFile;
    if (file == null || file.path.startsWith('/fake')) return;
    try {
      final content = await File(file.path).readAsString();
      file.controller.text = content;
      file.isModified = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Revert error: $e");
    }
  }

  void closeActiveFile() {
    if (_activeFileIndex != -1) {
      closeFile(_activeFileIndex);
    }
  }

  void closeAll() {
    for (final file in _files) {
      _unbindAutoSave(file);
    }
    _files.clear();
    _activeFileIndex = -1;
    hasActiveFile.value = false;
    notifyListeners();
  }

  void _bindAutoSave(EditorFile file) {
    void listener() {
      file.isModified = true;
      notifyListeners();
      if (!SettingsService().autoSave || file.path.startsWith('/fake')) {
        return;
      }

      _autoSaveTimers[file.controller]?.cancel();
      _autoSaveTimers[file.controller] = Timer(
        const Duration(milliseconds: 700),
        () async {
          if (!_files.contains(file)) return;
          if (!SettingsService().autoSave) return;
          try {
            await File(file.path).writeAsString(file.controller.text);
            file.isModified = false;
            notifyListeners();
          } catch (e) {
            debugPrint("Auto-save error: $e");
          }
        },
      );
    }

    _autoSaveListeners[file.controller] = listener;
    file.controller.addListener(listener);
  }

  void _unbindAutoSave(EditorFile file) {
    _autoSaveTimers.remove(file.controller)?.cancel();
    final listener = _autoSaveListeners.remove(file.controller);
    if (listener != null) {
      file.controller.removeListener(listener);
    }
  }

  bool _notifyScheduled = false;

  @override
  void notifyListeners() {
    if (_notifyScheduled) return;

    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle) {
      _notifyScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        super.notifyListeners();
      });
    } else {
      super.notifyListeners();
    }
  }
}
