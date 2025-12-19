import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/editor_service.dart';

class EditorWidget extends StatefulWidget {
  const EditorWidget({super.key});

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  final EditorService _editorService = EditorService();

  @override
  void initState() {
    super.initState();
    _editorService.addListener(_update);

    // Test uchun boshlanishiga bitta fayl ochib qo'yamiz
    if (_editorService.files.isEmpty) {
      _editorService.openFile("main.py", "print('Salom, Ket Studio!')\n\n# Kodingizni shu yerga yozing...");
    }
  }

  @override
  void dispose() {
    _editorService.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // 1. Agar fayl yo'q bo'lsa (Empty State)
    if (_editorService.files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rocket_launch, size: 60, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 20),
            Text("Fayl ochish uchun Explorer'dan tanlang\nyoki Ctrl+N bosing",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.2))),
          ],
        ),
      );
    }

    final activeFile = _editorService.activeFile!;

    return Column(
      children: [
        // A. TAB BAR (Fayllar qatori)
        Container(
          height: 35,
          color: const Color(0xFF161B22), // Panel foni
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _editorService.files.length,
            itemBuilder: (context, index) {
              final file = _editorService.files[index];
              final isActive = index == _editorService.activeFileIndex;

              return InkWell(
                onTap: () => _editorService.setActiveIndex(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  // Aktiv tab ajralib turadi
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF0D1117) : Colors.transparent, // Aktiv bo'lsa Editor foni bilan bir xil
                    border: isActive
                        ? const Border(top: BorderSide(color: Color(0xFF58A6FF), width: 2))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        file.name.endsWith('.py') ? Icons.data_object : Icons.description,
                        size: 14,
                        color: isActive ? Colors.white : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(file.name, style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey,
                          fontSize: 12
                      )),
                      const SizedBox(width: 8),
                      // Yopish tugmasi
                      InkWell(
                        onTap: () => _editorService.closeFile(index),
                        borderRadius: BorderRadius.circular(10),
                        child: const Icon(Icons.close, size: 14, color: Colors.white54),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // B. KOD MAYDONI (Code Editor)
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: monokaiSublimeTheme), // VS Code Dark Theme
            child: CodeField(
              controller: activeFile.controller,
              textStyle: GoogleFonts.jetBrainsMono(fontSize: 14), // Maxsus kod shrifti
              expands: true,
              wrap: false, // Kodni pastga tushirmaslik (scroll bo'ladi)
              background: const Color(0xFF0D1117), // Editor foni
            ),
          ),
        ),
      ],
    );
  }
}