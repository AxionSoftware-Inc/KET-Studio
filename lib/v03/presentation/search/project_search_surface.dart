import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../application/workbench_controller.dart';
import '../../application/search/project_search_service.dart';

final class ProjectSearchSurface extends StatefulWidget {
  const ProjectSearchSurface({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onOpenMatch,
  });

  final WorkbenchController controller;
  final Future<void> Function(String query) onSearch;
  final Future<void> Function(ProjectSearchMatch match) onOpenMatch;

  @override
  State<ProjectSearchSurface> createState() => _ProjectSearchSurfaceState();
}

final class _ProjectSearchSurfaceState extends State<ProjectSearchSurface> {
  late final TextEditingController _query;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.controller.searchQuery);
  }

  Future<void> _run() async {
    final query = _query.text.trim();
    if (query.isEmpty || _searching) return;
    setState(() => _searching = true);
    try {
      await widget.onSearch(query);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.controller.searchResults;
    return ColoredBox(
      color: const Color(0xFF0D1218),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextBox(
                    controller: _query,
                    placeholder: 'Search project files',
                    onSubmitted: (_) => unawaited(_run()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : () => unawaited(_run()),
                  child: Text(_searching ? 'Searching…' : 'Search'),
                ),
              ],
            ),
          ),
          const Divider(size: 1),
          SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.controller.searchQuery.isEmpty
                      ? 'Project-wide text search'
                      : '${results.length} matches for “${widget.controller.searchQuery}”',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF7F8A96)),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final match = results[index];
                return GestureDetector(
                  onTap: () => unawaited(widget.onOpenMatch(match)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF18222C))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${match.path}:${match.line}:${match.column}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF79B8FF)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          match.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }
}
