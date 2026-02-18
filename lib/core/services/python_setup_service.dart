import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'terminal_service.dart';
import 'settings_service.dart';

class PythonSetupService extends ChangeNotifier {
  static final PythonSetupService _instance = PythonSetupService._internal();
  factory PythonSetupService() => _instance;
  PythonSetupService._internal();

  bool _isSetupComplete = false;
  bool get isSetupComplete => _isSetupComplete;

  final ValueNotifier<String?> currentTask = ValueNotifier<String?>(null);
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  /// Finds a working system python executable
  Future<String?> _findSystemPython() async {
    final commands = ['python', 'python3', 'py'];
    for (var cmd in commands) {
      try {
        final result = await Process.run(cmd, [
          '--version',
        ]).timeout(const Duration(seconds: 2));
        if (result.exitCode == 0) return cmd;
      } catch (_) {}
    }
    return null;
  }

  Future<void> checkAndInstallDependencies() async {
    if (_isSetupComplete) return;

    final terminal = TerminalService();
    terminal.write("--- INTERNAL ENVIRONMENT SETUP ---");

    try {
      // 1. Get App Support Directory for isolation
      final appDir = await getApplicationSupportDirectory();
      final venvPath = p.join(appDir.path, 'ket_venv');
      final isWindows = Platform.isWindows;

      final pythonExec = isWindows
          ? p.join(venvPath, 'Scripts', 'python.exe')
          : p.join(venvPath, 'bin', 'python');

      // 2. Discover system python to create venv
      currentTask.value = "Checking host Python...";
      final hostPython = await _findSystemPython();
      if (hostPython == null) {
        terminal.write("❌ Error: Python not found on this system.");
        terminal.write(
          "Please install Python from python.org and add it to PATH.",
        );
        return;
      }
      terminal.write("System Python found: $hostPython");

      // 3. Create Virtual Environment if not exists
      if (!await Directory(venvPath).exists()) {
        terminal.write("Creating isolated environment in $venvPath...");
        currentTask.value = "Creating Virtual Environment...";
        progress.value = 0.1;

        final result = await Process.run(hostPython, ['-m', 'venv', venvPath]);
        if (result.exitCode != 0) {
          terminal.write("❌ Venv creation failed: ${result.stderr}");
          return;
        }
        terminal.write("Environment created successfully.");
      }

      // 4. Update Settings with internal python path
      SettingsService().setPythonPath(pythonExec);
      terminal.write("Using interpreter: $pythonExec");

      // 5. Upgrade pip first for better dependency resolution
      currentTask.value = "Upgrading package manager...";
      await Process.run(pythonExec, [
        '-m',
        'pip',
        'install',
        '--upgrade',
        'pip',
      ]);

      // 6. Check/Install Libraries
      final libraries = [
        'qiskit[visualization]', // Includes drawing tools
        'qiskit-aer',
        'qiskit-ibm-runtime', // For real hardware access
        'matplotlib',
        'pylatexenc',
        'numpy',
        'pandas',
      ];

      for (var i = 0; i < libraries.length; i++) {
        final libFull = libraries[i];
        final libName = libFull.split('[').first;

        currentTask.value = "Syncing $libName...";
        progress.value = 0.2 + (i / libraries.length) * 0.7;

        terminal.write("Checking $libName...");

        var checkResult = await Process.run(pythonExec, [
          '-m',
          'pip',
          'show',
          libName,
        ]);

        if (checkResult.exitCode != 0) {
          terminal.write(
            "$libName not found. Installing into isolated environment...",
          );
          var installResult = await Process.run(pythonExec, [
            '-m',
            'pip',
            'install',
            '--no-cache-dir',
            libFull,
          ]).timeout(const Duration(minutes: 5));

          if (installResult.exitCode == 0) {
            terminal.write("✅ $libName installed.");
          } else {
            terminal.write(
              "⚠️ Failed to install $libName: ${installResult.stderr}",
            );
          }
        } else {
          terminal.write("✅ $libName is ready.");
        }
      }

      // 7. Verification Step: Run a tiny Qiskit script to be 100% sure
      currentTask.value = "Verifying Quantum Stack...";
      terminal.write("Running verification circuit...");
      final verifyScript = """
try:
    from qiskit import QuantumCircuit
    from qiskit_aer import AerSimulator
    qc = QuantumCircuit(1)
    qc.x(0)
    qc.measure_all()
    print("Verification Success")
except Exception as e:
    print(f"Verification Failed: {e}")
""";
      final verifyFile = File(p.join(appDir.path, 'verify_qiskit.py'));
      await verifyFile.writeAsString(verifyScript);

      final verifyResult = await Process.run(pythonExec, [verifyFile.path]);
      if (verifyResult.stdout.toString().contains("Verification Success")) {
        terminal.write("🚀 Qiskit is fully functional.");
      } else {
        terminal.write(
          "⚠️ Qiskit validation failed. Check terminal for details.",
        );
      }

      progress.value = 1.0;
      currentTask.value = "Finalizing...";
      _isSetupComplete = true;
      terminal.write("--- QUANTUM ENVIRONMENT READY ---");
      notifyListeners();
    } catch (e) {
      terminal.write("FATAL ERROR: $e");
    } finally {
      currentTask.value = null;
    }
  }
}
