import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

final class ProjectSearchMatch {
  const ProjectSearchMatch({
    required this.path,
    required this.line,
    required this.column,
    required this.preview,
  });

  final String path;
  final int line;
  final int column;
  final String preview;
}

final class ProjectSearchService {
  const ProjectSearchService({
    this.maxFileBytes = 2 * 1024 * 1024,
    this.maxResults = 500,
  });

  final int maxFileBytes;
  final int maxResults;

  Future<List<ProjectSearchMatch>> search({
    required String rootPath,
    required String query,
    bool caseSensitive = false,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const <ProjectSearchMatch>[];
    return Isolate.run(() => _scanProject(<String, Object?>{
          'rootPath': rootPath,
          'query': normalized,
          'caseSensitive': caseSensitive,
          'maxFileBytes': maxFileBytes,
          'maxResults': maxResults,
        }));
  }
}

List<ProjectSearchMatch> _scanProject(Map<String, Object?> input) {
  final rootPath = input['rootPath']! as String;
  final query = input['query']! as String;
  final caseSensitive = input['caseSensitive']! as bool;
  final maxFileBytes = input['maxFileBytes']! as int;
  final maxResults = input['maxResults']! as int;
  final root = Directory(rootPath);
  if (!root.existsSync()) return const <ProjectSearchMatch>[];

  const ignoredDirectories = <String>{
    '.git',
    '.ket',
    '.dart_tool',
    'build',
    'dist',
    'node_modules',
    '.idea',
    '.vscode',
  };
  const allowedExtensions = <String>{
    '.py', '.qasm', '.dart', '.cpp', '.cc', '.c', '.h', '.hpp', '.json',
    '.yaml', '.yml', '.toml', '.md', '.txt', '.cmake', '.sh', '.ps1', '.bat',
  };

  final needle = caseSensitive ? query : query.toLowerCase();
  final results = <ProjectSearchMatch>[];
  final stack = <Directory>[root];
  while (stack.isNotEmpty && results.length < maxResults) {
    final directory = stack.removeLast();
    List<FileSystemEntity> entities;
    try {
      entities = directory.listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final entity in entities) {
      if (results.length >= maxResults) break;
      if (entity is Directory) {
        if (!ignoredDirectories.contains(p.basename(entity.path))) stack.add(entity);
        continue;
      }
      if (entity is! File) continue;
      final extension = p.extension(entity.path).toLowerCase();
      if (!allowedExtensions.contains(extension) && p.basename(entity.path) != 'CMakeLists.txt') {
        continue;
      }
      try {
        final length = entity.lengthSync();
        if (length <= 0 || length > maxFileBytes) continue;
        final lines = entity.readAsLinesSync();
        for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
          final raw = lines[lineIndex];
          final haystack = caseSensitive ? raw : raw.toLowerCase();
          var cursor = 0;
          while (results.length < maxResults) {
            final found = haystack.indexOf(needle, cursor);
            if (found < 0) break;
            results.add(ProjectSearchMatch(
              path: p.relative(entity.path, from: rootPath),
              line: lineIndex + 1,
              column: found + 1,
              preview: raw.trim().length > 240
                  ? '${raw.trim().substring(0, 237)}...'
                  : raw.trim(),
            ));
            cursor = found + needle.length;
          }
        }
      } catch (_) {
        // Permissions, encoding or races on one file must not abort project search.
      }
    }
  }
  results.sort((a, b) {
    final pathOrder = a.path.compareTo(b.path);
    if (pathOrder != 0) return pathOrder;
    final lineOrder = a.line.compareTo(b.line);
    return lineOrder != 0 ? lineOrder : a.column.compareTo(b.column);
  });
  return List<ProjectSearchMatch>.unmodifiable(results);
}
