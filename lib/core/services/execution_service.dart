import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // <--- ValueNotifier uchun kerak
import 'terminal_service.dart';
import 'viz_service.dart';

class ExecutionService {
  static final ExecutionService _instance = ExecutionService._internal();
  factory ExecutionService() => _instance;
  ExecutionService._internal();

  Process? _process;

  // --- 1. BU YERDA XATO BERAYOTGAN "isRunning" BOR ---
  final ValueNotifier<bool> isRunning = ValueNotifier(false);

  Future<void> runPython(String filePath) async {
    final terminal = TerminalService();

    if (_process != null) stop();

    terminal.write("> python $filePath");
    terminal.write("----------------------------------------");

    try {
      isRunning.value = true;

      // 1. CREATE LAUNCHER TO CAPTURE MATPLOTLIB
      final projectDir = File(filePath).parent.path;
      final launcherPath =
          "$projectDir${Platform.pathSeparator}.ket_launcher.py";
      final vizDir = "$projectDir${Platform.pathSeparator}.ket_viz";

      final launcherCode =
          """
import sys
import os
import json

# --- KET IDE INTERCEPTOR ---
try:
    import matplotlib
    matplotlib.use('Agg') # Prevent popup windows
    import matplotlib.pyplot as plt
    
    def ket_show(*args, **kwargs):
        import time
        if not os.path.exists('$vizDir'.replace('\\\\', '/')):
            os.makedirs('$vizDir'.replace('\\\\', '/'))
        
        # Save plot to temp file
        path = os.path.join('$vizDir'.replace('\\\\', '/'), f"viz_{int(time.time()*1000)}.png")
        plt.savefig(path, bbox_inches='tight')
        print(f"IMAGE:{path}")
        plt.close() # Reset for next plot
    
    plt.show = ket_show
except ImportError:
    pass

# Run user script
import runpy
try:
    # Adjust argv so script thinks it's running normally
    sys.argv = [sys.argv[1]] + sys.argv[2:]
    runpy.run_path(sys.argv[0], run_name="__main__")
except Exception as e:
    import traceback
    traceback.print_exc()
""";

      await File(launcherPath).writeAsString(launcherCode);

      // 2. START PROCESS
      _process = await Process.start('python', ['-u', launcherPath, filePath]);

      if (_process == null) {
        terminal.write("❌ Error: Python start failed.");
        isRunning.value = false;
        return;
      }

      _process!.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          // --- SMART PATTERN MATCHING ---

          // 1. VIZ: explicitly
          if (trimmed.startsWith("VIZ:")) {
            try {
              final jsonStr = trimmed.substring(4).trim();
              final map = jsonDecode(jsonStr);
              final typeStr = map['type'] as String;
              final vizData = map['data'];

              final type = VizType.values.firstWhere(
                (e) => e.toString().split('.').last == typeStr,
                orElse: () => VizType.none,
              );

              if (type != VizType.none) {
                VizService().updateData(type, vizData);
              }
            } catch (e) {
              debugPrint("Viz Parse Error: $e");
            }
          }
          // 2. __DATA__: pattern
          else if (trimmed.startsWith("__DATA__:")) {
            try {
              final jsonStr = trimmed.substring(9).trim();
              final data = jsonDecode(jsonStr);
              VizService().updateData(VizType.quantum, data);
            } catch (e) {
              debugPrint("__DATA__ Parse Error: $e");
            }
          }
          // 3. BLOCH:theta,phi OR BLOCH:x,y,z
          else if (trimmed.toUpperCase().startsWith("BLOCH:")) {
            final coords = trimmed.substring(6).split(',');
            if (coords.length == 2) {
              // Assume Sphere (theta, phi)
              final theta = double.tryParse(coords[0]) ?? 0;
              final phi = double.tryParse(coords[1]) ?? 0;
              // Simple conversion is handled in Widget
              VizService().updateData(VizType.bloch, {
                "theta": theta,
                "phi": phi,
              });
            } else if (coords.length == 3) {
              final x = double.tryParse(coords[0]) ?? 0;
              final y = double.tryParse(coords[1]) ?? 0;
              final z = double.tryParse(coords[2]) ?? 0;
              VizService().updateData(VizType.bloch, {"x": x, "y": y, "z": z});
            }
          }
          // 4. IMAGE:path
          else if (trimmed.toUpperCase().startsWith("IMAGE:") ||
              trimmed.toUpperCase().startsWith("CIRCUIT:")) {
            final type = trimmed.toUpperCase().startsWith("CIRCUIT:")
                ? VizType.circuit
                : VizType.image;
            final path = trimmed.substring(trimmed.indexOf(":") + 1).trim();
            VizService().updateData(type, path);
          }
          // Default: Terminal
          else {
            terminal.write(trimmed);
          }
        }
      });

      _process!.stderr
          .transform(utf8.decoder)
          .listen((data) => terminal.write("Error: $data"));

      int exitCode = await _process!.exitCode;

      terminal.write("----------------------------------------");
      terminal.write("Process finished with exit code $exitCode");

      _process = null;
      isRunning.value = false; // <--- To'xtadi
    } catch (e) {
      terminal.write("System Error: $e");
      isRunning.value = false;
    }
  }

  // --- 2. BU YERDA XATO BERAYOTGAN "writeToStdin" BOR ---
  void writeToStdin(String text) {
    if (_process != null) {
      try {
        _process!.stdin.writeln(text);
      } catch (e) {
        TerminalService().write("⚠️ Input Error: $e");
      }
    } else {
      TerminalService().write("⚠️ Hozir hech qanday dastur ishlamayapti.");
    }
  }

  void stop() {
    if (_process != null) {
      _process!.kill();
      TerminalService().write("\n🛑 Dastur majburan to'xtatildi.");
      _process = null;
      isRunning.value = false;
    }
  }
}
