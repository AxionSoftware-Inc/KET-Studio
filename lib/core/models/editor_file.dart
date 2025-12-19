import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';

class EditorFile {
  final String path;          // Fayl manzili (C:/projects/main.py)
  final String name;          // Fayl nomi (main.py)
  final String extension;     // Kengaytmasi (.py)
  final CodeController controller; // Kodni boshqaruvchi pult
  bool isModified;            // O'zgarish bo'ldimi? (Saqlanmagan yulduzcha * uchun)

  EditorFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.controller,
    this.isModified = false,
  });
}