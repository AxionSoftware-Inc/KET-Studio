import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // <--- ValueNotifier uchun kerak
import 'terminal_service.dart';
import 'viz_service.dart';
import '../constants/viz_protocol.dart';

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

      // 1. CREATE LAUNCHER AND HELPER LIBRARY
      final projectDir = Directory(
        File(filePath).parent.path,
      ).absolute.path.replaceAll(r'\', '/');
      final launcherPath = "$projectDir/.ket_launcher.py";
      final helperPath1 = "$projectDir/ket_viz.py";
      final helperPath2 = "$projectDir/ketviz.py";
      final vizDir = "$projectDir/.ket_viz";

      const helperCode = """
import json, time, os

def viz(kind, payload):
    \"\"\"Standard KET VIZ protocol\"\"\"
    msg = {"kind": kind, "payload": payload, "ts": int(time.time()*1000)}
    print(f"KET_VIZ {json.dumps(msg, ensure_ascii=False)}", flush=True)

def heatmap(data, title="Heatmap"):
    viz("heatmap", {"data": data, "title": title})

def table(title, rows):
    viz("table", {"title": title, "rows": rows})

def text(content):
    viz("text", {"content": content})

def save_png(fig, name="plot.png"):
    if not os.path.exists(".ket_viz"):
        os.makedirs(".ket_viz")
    path = os.path.join(".ket_viz", name)
    fig.savefig(path, bbox_inches='tight')
    viz("image", {"path": path, "title": name})
    return path
""";

      final launcherCode =
          """
import sys
import os
import json

# --- KET IDE INTERCEPTOR ---
try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    
    def ket_show(*args, **kwargs):
        import time
        vdir = '$vizDir'.replace('\\\\', '/')
        if not os.path.exists(vdir):
            os.makedirs(vdir)
        path = os.path.join(vdir, f"viz_{int(time.time()*1000)}.png")
        plt.savefig(path, bbox_inches='tight')
        print(f"IMAGE:{path}")
        plt.close()
    
    import matplotlib.figure
    def ket_fig_show(self, *args, **kwargs):
        import time
        vdir = '$vizDir'.replace('\\\\', '/')
        if not os.path.exists(vdir):
            os.makedirs(vdir)
        path = os.path.join(vdir, f"viz_{int(time.time()*1000)}.png")
        self.savefig(path, bbox_inches='tight')
        print(f"IMAGE:{path}")
    
    plt.show = ket_show
    matplotlib.figure.Figure.show = ket_fig_show
except Exception:
    pass

# Run user script
import runpy
try:
    target_script = sys.argv[1]
    sys.argv = sys.argv[1:]
    runpy.run_path(target_script, run_name="__main__")
except Exception as e:
    import traceback
    traceback.print_exc()
""";

      await File(helperPath1).writeAsString(helperCode);
      await File(helperPath2).writeAsString(helperCode);
      await File(launcherPath).writeAsString(launcherCode);

      // 2. START PROCESS
      _process = await Process.start('python', [
        '-u',
        launcherPath,
        filePath,
      ], workingDirectory: projectDir);
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

          // --- KET_VIZ PROTOCOL (New standard) ---
          if (trimmed.startsWith(VizProtocol.prefix)) {
            try {
              final jsonStr = trimmed
                  .substring(VizProtocol.prefix.length)
                  .trim();
              final msg = jsonDecode(jsonStr);
              final kind = msg['kind'] as String;
              final payload = msg['payload'];

              final type = VizType.values.firstWhere(
                (e) => e.toString().split('.').last == kind,
                orElse: () => VizType.none,
              );

              if (type != VizType.none) {
                // If it's an image, resolve path
                if (type == VizType.image || type == VizType.circuit) {
                  String? path = payload['path'];
                  if (path != null && !File(path).isAbsolute) {
                    payload['path'] = "$projectDir/$path";
                  }
                }
                VizService().updateData(type, payload);
              }
            } catch (e) {
              debugPrint("KET_VIZ Parse Error: $e");
            }
          }
          // 1. VIZ: explicitly (Legacy support)
          else if (trimmed.startsWith("VIZ:")) {
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
            var path = trimmed.substring(trimmed.indexOf(":") + 1).trim();

            // Resolve relative path
            if (!File(path).isAbsolute) {
              path = "$projectDir/$path";
            }

            VizService().updateData(type, path);
          }
          // 5. GENERIC JSON (e.g. Qiskit events)
          else if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
            try {
              final map = jsonDecode(trimmed);

              // Prioritize images/charts
              String? imgPath =
                  map['path'] ??
                  map['hist_path'] ??
                  map['image_path'] ??
                  map['circuit_path'];

              if (imgPath != null) {
                if (!File(imgPath).isAbsolute) {
                  imgPath = "$projectDir/$imgPath";
                }
                VizService().updateData(VizType.image, imgPath);
              } else if (map.containsKey('final_counts') ||
                  map.containsKey('counts')) {
                final counts = map['final_counts'] ?? map['counts'];
                VizService().updateData(VizType.quantum, {"histogram": counts});
              } else {
                // If it's a generic JSON we don't know, just print it as text
                terminal.write(trimmed);
              }
            } catch (e) {
              terminal.write(trimmed);
            }
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
