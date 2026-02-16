import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // <--- ValueNotifier uchun kerak
import 'package:fluent_ui/fluent_ui.dart';
import 'terminal_service.dart';
import 'viz_service.dart';
import 'layout_service.dart';

class ExecutionService {
  static final ExecutionService _instance = ExecutionService._internal();
  factory ExecutionService() => _instance;
  ExecutionService._internal();

  Process? _process;
  String _stdoutBuffer = "";

  // --- 1. BU YERDA XATO BERAYOTGAN "isRunning" BOR ---
  final ValueNotifier<bool> isRunning = ValueNotifier(false);

  Future<void> runPython(String filePath, {String? content}) async {
    final terminal = TerminalService();

    if (_process != null) stop();

    terminal.write("> Preparing execution environment...");

    try {
      terminal.clear();
      isRunning.value = true;
      final sessionId = "v_${DateTime.now().millisecondsSinceEpoch}";
      VizService().startSession(sessionId);

      String actualFilePath = filePath;
      String projectDir;

      // Handle "Fake" or unsaved files by writing them to a real temp location
      if (filePath.startsWith('/fake')) {
        final tempSystemDir = Directory.systemTemp.createTempSync(
          'ket_studio_exec_',
        );
        projectDir = tempSystemDir.path.replaceAll(r'\', '/');
        actualFilePath = "$projectDir/temp_script.py";
        if (content != null) {
          await File(actualFilePath).writeAsString(content);
        } else {
          terminal.write("Error: Cannot run unsaved file without content.");
          isRunning.value = false;
          return;
        }
      } else {
        projectDir = Directory(
          File(filePath).parent.path,
        ).absolute.path.replaceAll(r'\', '/');
      }

      final ketBaseDir = "$projectDir/.ket";
      final outDir = "$ketBaseDir/out";
      final tempDir = "$ketBaseDir/temp";

      // Ensure directories exist
      await Directory(outDir).create(recursive: true);
      await Directory(tempDir).create(recursive: true);

      final launcherPath = "$tempDir/launcher.py";
      final helperPath1 = "$projectDir/ket_viz.py";
      final helperPath2 = "$projectDir/ketviz.py";

      // Update filePath for the launcher below
      final scriptToRun = actualFilePath.replaceAll(r'\', '/');

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

def histogram(counts, title="Counts"):
    viz("quantum", {"histogram": counts, "title": title})

def plot(fig, name="plot.png", title=None):
    out_dir = os.environ.get("KET_OUT", ".")
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)
    path = os.path.join(out_dir, name)
    fig.savefig(path, bbox_inches='tight')
    viz("image", {"path": path, "title": title or name})
    return path

def dashboard(histogram=None, matrix=None):
    \"\"\"Combine histogram and matrix in one view\"\"\"
    viz("quantum", {"histogram": histogram, "matrix": matrix})

def inspector(title, frames):
    \"\"\"Steppable circuit inspection with Bloch spheres\"\"\"
    viz("inspector", {"title": title, "frames": frames})
""";

      final launcherCode = """
import sys
import os
import json

# --- KET IDE INTERCEPTOR ---
import builtins
import json
import time
import os
import sys
import io

# Force UTF-8 for stdout to avoid charmap errors on Windows
if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def _ket_viz_impl(kind, payload):
    # Use ensure_ascii=True (default) for IPC safety. 
    # Non-ASCII chars will be escaped (e.g. \u03c0), and decoded back in Dart.
    msg = {"kind": kind, "payload": payload, "ts": int(time.time()*1000)}
    print(f"KET_VIZ {json.dumps(msg, ensure_ascii=True)}", flush=True)

# Inject into builtins so it's available in all modules without import
builtins.ket_viz = _ket_viz_impl

# Helper aliases in builtins
builtins.ket_histogram = lambda counts, title="Counts": _ket_viz_impl("quantum", {"histogram": counts, "title": title})
builtins.ket_heatmap = lambda data, title="Heatmap": _ket_viz_impl("heatmap", {"data": data, "title": title})
builtins.ket_text = lambda text: _ket_viz_impl("text", {"content": text})
builtins.ket_inspector = lambda title, frames: _ket_viz_impl("inspector", {"title": title, "frames": frames})

# Backward compatibility / Fake module
class _KetVizMock:
    def __getattr__(self, name):
        if name == "histogram": return builtins.ket_histogram
        if name == "heatmap": return builtins.ket_heatmap
        if name == "text": return builtins.ket_text
        if name == "inspector": return builtins.ket_inspector
        return lambda *args, **kwargs: _ket_viz_impl(name, args[0] if args else kwargs)
    def __call__(self, kind, payload): _ket_viz_impl(kind, payload)

import sys
sys.modules['ket_viz'] = _KetVizMock()

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    
    def ket_show(*args, **kwargs):
        vdir = os.environ.get("KET_OUT", ".")
        if not os.path.exists(vdir):
            os.makedirs(vdir)
        path = os.path.join(vdir, f"viz_{int(time.time()*1000)}.png")
        plt.savefig(path, bbox_inches='tight')
        print(f"IMAGE:{path}", flush=True)
        plt.close()
    
    import matplotlib.figure
    def ket_fig_show(self, *args, **kwargs):
        vdir = os.environ.get("KET_OUT", ".")
        if not os.path.exists(vdir):
            os.makedirs(vdir)
        path = os.path.join(vdir, f"viz_{int(time.time()*1000)}.png")
        self.savefig(path, bbox_inches='tight')
        print(f"IMAGE:{path}", flush=True)
    
    plt.show = ket_show
    matplotlib.figure.Figure.show = ket_fig_show
except Exception:
    pass

# Run user script
import runpy
try:
    target_script = sys.argv[1]
    # Ensure current script directory is in path
    script_dir = os.path.dirname(os.path.abspath(target_script))
    if script_dir not in sys.path:
        sys.path.insert(0, script_dir)
        
    sys.argv = sys.argv[1:]
    runpy.run_path(target_script, run_name="__main__")
except Exception as e:
    import traceback
    traceback.print_exc()
""";

      await File(helperPath1).writeAsString(helperCode);
      await File(helperPath2).writeAsString(helperCode);
      await File(launcherPath).writeAsString(launcherCode);

      // Try python then python3
      String executable = 'python';
      try {
        final check = await Process.run(executable, ['--version']);
        if (check.exitCode != 0) throw 'fail';
      } catch (e) {
        executable = 'python3';
        try {
          final check = await Process.run(executable, ['--version']);
          if (check.exitCode != 0) throw 'fail';
        } catch (e) {
          terminal.write(
            "❌ Error: Python not found. Please install Python and add it to PATH.",
          );
          VizService().endSession(
            exitCode: 1,
            error: "Python not found. Please check your system PATH.",
          );
          isRunning.value = false;
          return;
        }
      }

      terminal.write("> Executing: $executable $scriptToRun");
      terminal.write("----------------------------------------");

      _process = await Process.start(
        executable,
        ['-u', launcherPath, scriptToRun],
        workingDirectory: projectDir,
        environment: {"KET_OUT": outDir, "PYTHONUNBUFFERED": "1"},
      );
      if (_process == null) {
        terminal.write("❌ Error: Python start failed.");
        isRunning.value = false;
        return;
      }

      _stdoutBuffer = ""; // Clear buffer for new execution
      _process!.stdout.transform(utf8.decoder).listen((data) {
        _stdoutBuffer += data;
        while (true) {
          final newlineIndex = _stdoutBuffer.indexOf('\n');
          if (newlineIndex == -1) break;

          String line = _stdoutBuffer.substring(0, newlineIndex).trim();
          _stdoutBuffer = _stdoutBuffer.substring(newlineIndex + 1);

          if (line.isEmpty) continue;
          terminal.write(line);

          final upperLine = line.toUpperCase();
          if (upperLine.contains("KET_VIZ")) {
            try {
              final int start = line.indexOf('{');
              final int end = line.lastIndexOf('}');

              if (start != -1 && end != -1 && end > start) {
                final jsonStr = line.substring(start, end + 1);
                final msg = jsonDecode(jsonStr);

                String kind = (msg['kind'] ?? msg['type'] ?? "")
                    .toString()
                    .toLowerCase();
                final payload = msg['payload'] ?? msg['data'];

                if (kind == "quantum" || kind == "dashboard") {
                  kind = "dashboard";
                }

                final type = VizType.values.firstWhere(
                  (e) => e.toString().split('.').last == kind,
                  orElse: () => VizType.none,
                );

                if (type != VizType.none) {
                  if (type == VizType.image || type == VizType.circuit) {
                    String? path = payload is Map
                        ? payload['path']
                        : payload.toString();
                    if (path != null && !File(path).isAbsolute) {
                      if (payload is Map) payload['path'] = "$projectDir/$path";
                    }
                  }
                  VizService().updateData(type, payload);

                  // Auto-switch panels safely outside of build phase
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (type == VizType.inspector) {
                      LayoutService().setRightPanel('inspector');
                    } else if (type != VizType.none && type != VizType.error) {
                      if (LayoutService().activeRightPanelId == null) {
                        LayoutService().setRightPanel('vizualization');
                      }
                    }
                  });
                }
              }
            } catch (e) {
              terminal.write("⚠️ Viz Parse Error: $e");
            }
          }
        }
      });

      String stderrBuffer = "";
      _process?.stderr.transform(utf8.decoder).listen((data) {
        terminal.write("❌ Error: $data");
        stderrBuffer += data;
      });

      final exitCode = await _process!.exitCode;
      if (exitCode != 0 && stderrBuffer.isNotEmpty) {
        VizService().endSession(exitCode: exitCode, error: stderrBuffer);
      } else {
        VizService().endSession(exitCode: exitCode);
      }
      terminal.write("----------------------------------------");
      terminal.write("Process finished with exit code $exitCode");

      _process = null;
      isRunning.value = false;
    } catch (e) {
      terminal.write("⚠️ System Error: $e");
      VizService().endSession(exitCode: 1, error: e.toString());
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
