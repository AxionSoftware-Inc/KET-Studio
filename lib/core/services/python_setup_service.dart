import 'package:flutter/foundation.dart';
import 'package:process_run/shell.dart';
import 'terminal_service.dart';

class PythonSetupService {
  static final PythonSetupService _instance = PythonSetupService._internal();

  factory PythonSetupService() {
    return _instance;
  }

  PythonSetupService._internal();

  bool _isSetupComplete = false;
  bool get isSetupComplete => _isSetupComplete;

  final ValueNotifier<String?> currentTask = ValueNotifier<String?>(null);
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  Future<void> checkAndInstallDependencies() async {
    if (_isSetupComplete) return;

    final terminal = TerminalService();
    terminal.write("Checking Python environment...");

    var shell = Shell();

    try {
      // 1. Check Python version
      var result = await shell.run('python --version');
      final versionOutput = result.first.stdout.toString().trim();
      terminal.write("Python found: $versionOutput");

      // 2. Comprehensive library list
      final libraries = [
        'qiskit',
        'qiskit-aer',
        'matplotlib',
        'pylatexenc',
        'numpy',
        'pandas',
      ];

      for (var i = 0; i < libraries.length; i++) {
        final lib = libraries[i];
        currentTask.value = "Installing $lib...";
        progress.value = (i + 1) / libraries.length;

        terminal.write("Checking $lib...");
        try {
          await shell.run('pip show $lib');
          terminal.write("$lib is already installed.");
        } catch (e) {
          terminal.write("$lib not found. Installing...");
          await shell.run('pip install $lib');
          terminal.write("$lib installation completed.");
        }
      }

      currentTask.value = "Cleaning up...";
      await Future.delayed(const Duration(seconds: 1));

      _isSetupComplete = true;
      currentTask.value = null;
      terminal.write("Environment setup complete. Ready for Quantum tasks.");
    } catch (e) {
      terminal.write("Error during setup: $e");
      terminal.write("Please ensure Python is installed and added to PATH.");
    }
  }
}
