import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'terminal_service.dart';
import 'viz_service.dart';
import 'settings_service.dart';

class ExecutionService {
  static final ExecutionService _instance = ExecutionService._internal();
  factory ExecutionService() => _instance;
  ExecutionService._internal();

  Process? _process;
  final ValueNotifier<bool> isRunning = ValueNotifier(false);

  // PERFORMANCE OPTIMIZATION:
  // 1. '_terminalLines' and '_scheduleFlush' are used to batch terminal output (every 80ms).
  // 2. '_vizJsonQueue' stores RAW Strings. We decode only 5 JSON msgs every 60ms
  //    using '_scheduleVizFlush' to prevent UI thread blocking on large payloads.
  final List<String> _terminalLines = [];
  Timer? _flushTimer;
  final List<String> _vizJsonQueue = [];
  Timer? _vizTimer;
  String? _currentProjectDir;

  void _scheduleFlush() {
    _flushTimer ??= Timer(const Duration(milliseconds: 80), () {
      _flushTimer = null;
      if (_terminalLines.isNotEmpty) {
        TerminalService().writeLines(List<String>.from(_terminalLines));
        _terminalLines.clear();
      }
    });
  }

  void _scheduleVizFlush() {
    _vizTimer ??= Timer(const Duration(milliseconds: 60), () {
      _vizTimer = null;
      if (_vizJsonQueue.isEmpty) return;

      // Only decode a few at a time to keep UI responsive
      final take = _vizJsonQueue.length > 5 ? 5 : _vizJsonQueue.length;
      for (int i = 0; i < take; i++) {
        _processVizMessage(_vizJsonQueue[i]);
      }
      _vizJsonQueue.removeRange(0, take);
      if (_vizJsonQueue.isNotEmpty) _scheduleVizFlush();
    });
  }

  void _processVizMessage(String jsonStr) {
    try {
      final msg = jsonDecode(jsonStr) as Map<String, dynamic>;
      String kind0 = (msg['kind'] ?? msg['type'] ?? "")
          .toString()
          .toLowerCase();
      final payload = msg['payload'] ?? msg['data'];

      if (kind0 == "quantum" || kind0 == "histogram") kind0 = "histogram";
      if (kind0 == "plot" || kind0 == "chart") kind0 = "chart";
      if (kind0 == "state" || kind0 == "statevector") kind0 = "statevector";

      final type = VizType.values.firstWhere(
        (e) => e.name == kind0.trim(),
        orElse: () => VizType.none,
      );

      if (type != VizType.none) {
        // Fix relative image paths
        if (type == VizType.image || type == VizType.circuit) {
          String? path = (payload is Map)
              ? payload['path']
              : payload.toString();
          if (path != null &&
              !File(path).isAbsolute &&
              _currentProjectDir != null) {
            if (payload is Map) {
              payload['path'] = "$_currentProjectDir/$path";
            }
          }
        }

        // Safety: Limit Inspector data size
        if (type == VizType.inspector && payload is Map) {
          final frames = payload['frames'];
          if (frames is List && frames.length > 100) {
            payload['frames'] = frames.sublist(0, 100);
          }
        }
        VizService().updateData(type, payload);
      }
    } catch (_) {}
  }

  void _flushVizInstant() {
    while (_vizJsonQueue.isNotEmpty) {
      _processVizMessage(_vizJsonQueue.removeAt(0));
    }
  }

  // CRITICAL: Clean malformed UTF-16 (lone surrogates) which cause crashes in Flutter/SelectableText
  String _safe(String s) {
    try {
      // Create a safely encoded UTF-16 string by re-encoding as UTF-8 with replacement
      return utf8.decode(utf8.encode(s), allowMalformed: true);
    } catch (_) {
      return s.replaceAll(RegExp(r'[\uD800-\uDFFF]'), '');
    }
  }

  void _handleVizLine(String line) {
    final cleaned = _safe(line);
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return;

    final jsonStr = cleaned.substring(start, end + 1);
    _vizJsonQueue.add(jsonStr);
    if (_vizJsonQueue.length > 100) {
      _vizJsonQueue.removeRange(0, _vizJsonQueue.length - 100);
    }
    _scheduleVizFlush();
  }

  Future<void> runPython(String filePath, {String? content}) async {
    final terminal = TerminalService();
    if (_process != null) stop();

    try {
      terminal.clear();
      _terminalLines.clear();
      _vizJsonQueue.clear();

      Future.microtask(() => isRunning.value = true);
      final sessionId = "v_${DateTime.now().millisecondsSinceEpoch}";
      VizService().startSession(sessionId);

      String actualFilePath = filePath;
      String projectDir;

      if (filePath.startsWith('/fake')) {
        final tempSystemDir = Directory.systemTemp.createTempSync(
          'ket_studio_exec_',
        );
        projectDir = tempSystemDir.path.replaceAll(r'\', '/');
        actualFilePath = "$projectDir/temp_script.py";
        if (content != null) {
          await File(actualFilePath).writeAsString(content);
        } else {
          isRunning.value = false;
          return;
        }
      } else {
        projectDir = Directory(
          File(filePath).parent.path,
        ).absolute.path.replaceAll(r'\', '/');
      }

      _currentProjectDir = projectDir; // Store for path fixing

      final outDir = "$projectDir/.ket/out";
      await Directory(outDir).create(recursive: true);

      final tempDir = "$projectDir/.ket/temp";
      await Directory(tempDir).create(recursive: true);

      final launcherPath = "$tempDir/launcher.py";
      final scriptToRun = actualFilePath.replaceAll(r'\', '/');

      // (launcher code is already good from previous turn)
      // ... I'll keep the launcher as is but ensure it's provided in full ...
      final launcherCode = """
import sys, os, json, time, io, runpy

if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def _viz(kind, payload):
    msg = {"kind": kind, "payload": payload, "ts": int(time.time()*1000)}
    print(f"KET_VIZ {json.dumps(msg, ensure_ascii=True)}", flush=True)

import builtins
builtins.ket_viz = _viz
builtins.ket_histogram = lambda data, title="Counts": _viz("histogram", {"histogram": data, "title": title})
builtins.ket_heatmap = lambda data, title="Heatmap": _viz("heatmap", {"data": data, "title": title})
builtins.ket_text = lambda content: _viz("text", {"content": content})
builtins.ket_inspector = lambda title, frames: _viz("inspector", {"title": title, "frames": frames})
builtins.ket_metrics = lambda metrics: _viz("metrics", metrics)
builtins.ket_estimator = lambda estimation: _viz("estimator", estimation)
builtins.ket_statevector = lambda data, title="Statevector": _viz("statevector", {"amplitudes": data, "title": title})

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    def _ket_plt_show(*args, **kwargs):
        vdir = os.environ.get("KET_OUT", ".")
        if not os.path.exists(vdir): os.makedirs(vdir)
        path = os.path.join(vdir, f"viz_{int(time.time()*1000)}.png")
        plt.savefig(path, bbox_inches='tight')
        _viz("image", {"path": path, "title": "Plot Output"})
        plt.close()
    plt.show = _ket_plt_show
except:
    pass

class _Mock:
    def __getattr__(self, n):
        if n == "histogram": return builtins.ket_histogram
        if n == "heatmap": return builtins.ket_heatmap
        if n == "text": return builtins.ket_text
        if n == "inspector": return builtins.ket_inspector
        if n == "metrics": return builtins.ket_metrics
        if n == "estimator": return builtins.ket_estimator
        if n == "statevector": return builtins.ket_statevector
        return lambda *a, **k: _viz(n, a[0] if a else k)
    def __call__(self, k, p): _viz(k, p)

sys.modules['ket_viz'] = _Mock()

try:
    target = sys.argv[1]
    s_dir = os.path.dirname(os.path.abspath(target))
    if s_dir not in sys.path: sys.path.insert(0, s_dir)
    sys.argv = sys.argv[1:]
    runpy.run_path(target, run_name="__main__")
except Exception:
    import traceback
    traceback.print_exc()
""";
      await File(launcherPath).writeAsString(launcherCode);

      String executable = SettingsService().pythonPath;

      _process = await Process.start(
        executable,
        ['-u', launcherPath, scriptToRun],
        workingDirectory: projectDir,
        environment: {"KET_OUT": outDir, "PYTHONUNBUFFERED": "1"},
      );

      final stderrCollector = <String>[];
      _process!.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
            if (line.isEmpty) return;
            final safeLine = _safe(line);
            if (safeLine.contains("KET_VIZ")) {
              _handleVizLine(safeLine);
              return;
            }
            _terminalLines.add(safeLine);
            if (_terminalLines.length >= 200) {
              terminal.writeLines(List<String>.from(_terminalLines));
              _terminalLines.clear();
              _flushTimer?.cancel();
              _flushTimer = null;
            } else {
              _scheduleFlush();
            }
          });

      _process!.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
            if (line.isEmpty) return;
            final safeLine = _safe(line);
            stderrCollector.add(safeLine);
            _terminalLines.add("❌ $safeLine");
            _scheduleFlush();
          });

      final exitCode = await _process!.exitCode;
      _flushTimer?.cancel();

      // Final Terminal Flush
      if (_terminalLines.isNotEmpty) {
        terminal.writeLines(List<String>.from(_terminalLines));
        _terminalLines.clear();
      }

      // CRITICAL: Final Viz Flush - don't lose data if process ends quickly
      _flushVizInstant();
      _vizTimer?.cancel();

      VizService().endSession(
        exitCode: exitCode,
        error: stderrCollector.isNotEmpty ? stderrCollector.join('\n') : null,
      );
      terminal.write("----------------------------------------");
      terminal.write("Process finished with exit code $exitCode");
      _process = null;
      Future.microtask(() => isRunning.value = false);
    } catch (e) {
      terminal.write("⚠️ System Error: $e");
      isRunning.value = false;
    }
  }

  void writeToStdin(String text) {
    _process?.stdin.writeln(text);
  }

  void stop() {
    if (_process != null) {
      _process!.kill();
      _process = null;
      isRunning.value = false;
      TerminalService().write("\n🛑 Process stopped by user.");
    }
  }
}
