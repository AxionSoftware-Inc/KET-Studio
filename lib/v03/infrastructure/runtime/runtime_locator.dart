import 'dart:io';

import 'package:path/path.dart' as p;

final class RuntimePaths {
  const RuntimePaths({
    required this.nativeHost,
    required this.kernelScript,
    required this.pythonInterpreter,
    required this.defaultShell,
  });

  final String? nativeHost;
  final String? kernelScript;
  final String pythonInterpreter;
  final String defaultShell;

  bool get hasNativeHost => nativeHost != null;
  bool get hasKernel => kernelScript != null;
}

final class RuntimeLocator {
  const RuntimeLocator();

  Future<RuntimePaths> resolve() async {
    final executableDir = p.dirname(Platform.resolvedExecutable);
    final projectDir = Directory.current.path;
    final hostName = Platform.isWindows ? 'ket_host.exe' : 'ket_host';

    final nativeHost = _firstExisting(<String?>[
      Platform.environment['KET_NATIVE_HOST'],
      p.join(executableDir, hostName),
      p.join(executableDir, 'bin', hostName),
      p.join(projectDir, 'native', 'ket_host', 'build', hostName),
      if (Platform.isWindows)
        p.join(projectDir, 'native', 'ket_host', 'build', 'Release', hostName),
    ]);

    final kernelScript = _firstExisting(<String?>[
      Platform.environment['KET_KERNEL_SCRIPT'],
      p.join(projectDir, 'runtime', 'python', 'ket_kernel.py'),
      p.join(
        executableDir,
        'data',
        'flutter_assets',
        'runtime',
        'python',
        'ket_kernel.py',
      ),
    ]);

    return RuntimePaths(
      nativeHost: nativeHost,
      kernelScript: kernelScript,
      pythonInterpreter: Platform.environment['KET_PYTHON'] ??
          (Platform.isWindows ? 'python.exe' : 'python3'),
      defaultShell: _defaultShell(),
    );
  }

  String _defaultShell() {
    if (Platform.isWindows) {
      return Platform.environment['COMSPEC'] ?? 'powershell.exe';
    }
    if (Platform.isMacOS) return '/bin/zsh';
    return Platform.environment['SHELL'] ?? '/bin/bash';
  }

  String? _firstExisting(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      final normalized = p.normalize(candidate);
      if (File(normalized).existsSync()) return normalized;
    }
    return null;
  }
}
