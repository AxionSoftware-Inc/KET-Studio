import 'dart:io';
import 'dart:convert';
import 'terminal_service.dart';

class ExecutionService {
  // Singleton
  static final ExecutionService _instance = ExecutionService._internal();
  factory ExecutionService() => _instance;
  ExecutionService._internal();

  Process? _process; // Hozirgi ishlayotgan jarayon

  // Kodni yurgizish
  Future<void> runPython(String filePath) async {
    final terminal = TerminalService();

    // 1. Terminalni tozalaymiz va start beramiz
    terminal.clear();
    terminal.write("Running: python $filePath");
    terminal.write("----------------------------------------");

    try {
      // 2. Jarayonni boshlaymiz (Windows/Mac/Linux universal)
      // '-u' bayrog'i (unbuffered) muhim, output darrov chiqishi uchun
      _process = await Process.start('python', ['-u', filePath]);

      if (_process == null) {
        terminal.write("Error: Pythonni ishga tushirib bo'lmadi.");
        return;
      }

      // 3. STDOUT (Oddiy yozuvlarni o'qish)
      _process!.stdout.transform(utf8.decoder).listen((data) {
        // Ba'zan ma'lumot bo'laklanib keladi, biz uni qatorlarga bo'lamiz
        final lines = data.split('\n');
        for (var line in lines) {
          if (line.isNotEmpty) terminal.write(line);
        }
      });

      // 4. STDERR (Xatolarni o'qish)
      _process!.stderr.transform(utf8.decoder).listen((data) {
        terminal.write("ERROR: $data"); // Xatolarni ajratib ko'rsatish mumkin
      });

      // 5. Tugashini kutish
      int exitCode = await _process!.exitCode;
      terminal.write("----------------------------------------");
      terminal.write("Process finished with exit code $exitCode");

      _process = null;

    } catch (e) {
      terminal.write("System Error: $e");
    }
  }

  // To'xtatish (Stop tugmasi uchun)
  void stop() {
    if (_process != null) {
      _process!.kill();
      TerminalService().write("\n[Jarayon majburan to'xtatildi]");
      _process = null;
    }
  }
}