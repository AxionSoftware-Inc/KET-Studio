import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/application/search/project_search_service.dart';

void main() {
  test('project search scans text files and skips generated directories', () async {
    final root = await Directory.systemTemp.createTemp('ket-search-');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/main.py').writeAsString('alpha\nquantum target\nomega\n');
    final ignored = Directory('${root.path}/build')..createSync();
    await File('${ignored.path}/generated.py').writeAsString('quantum target');

    final results = await const ProjectSearchService().search(
      rootPath: root.path,
      query: 'quantum target',
    );

    expect(results.length, 1);
    expect(results.single.path, 'main.py');
    expect(results.single.line, 2);
    expect(results.single.column, 1);
  });
}
