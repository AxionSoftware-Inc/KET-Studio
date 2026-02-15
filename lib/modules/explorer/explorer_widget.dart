import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/file_service.dart';
import '../../core/services/editor_service.dart';
import '../../core/theme/ket_theme.dart';
import 'explorer_logic.dart';

class ExplorerWidget extends StatefulWidget {
  const ExplorerWidget({super.key});

  @override
  State<ExplorerWidget> createState() => _ExplorerWidgetState();
}

class _ExplorerWidgetState extends State<ExplorerWidget> {
  @override
  void initState() {
    super.initState();
    FileService().addListener(_onFileServiceChanged);
  }

  @override
  void dispose() {
    FileService().removeListener(_onFileServiceChanged);
    super.dispose();
  }

  void _onFileServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rootPath = FileService().rootPath;
    return Column(
      children: [
        // Header
        Container(
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          color: KetTheme.bgHeader,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "EXPLORER: ${rootPath.split(Platform.pathSeparator).last.toUpperCase()}",
                  style: const TextStyle(
                    color: KetTheme.textMain,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(FluentIcons.add_notes, size: 14),
                    onPressed: () => ExplorerLogic.showNameDialog(
                      context,
                      rootPath,
                      isFile: true,
                      onDone: () => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.folder_horizontal, size: 14),
                    onPressed: () => ExplorerLogic.showNameDialog(
                      context,
                      rootPath,
                      isFile: false,
                      onDone: () => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.refresh, size: 14),
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Recursive Tree
        Expanded(
          child: SingleChildScrollView(
            child: FileTreeItem(
              key: ValueKey(rootPath),
              path: rootPath,
              isRoot: true,
              level: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class FileTreeItem extends StatefulWidget {
  final String path;
  final bool isRoot;
  final int level;

  const FileTreeItem({
    super.key,
    required this.path,
    this.isRoot = false,
    required this.level,
  });

  @override
  State<FileTreeItem> createState() => _FileTreeItemState();
}

class _FileTreeItemState extends State<FileTreeItem> {
  bool _isExpanded = false;
  List<FileSystemEntity> _children = [];
  final FlyoutController _flyoutController = FlyoutController();

  @override
  void initState() {
    super.initState();
    if (widget.isRoot) _isExpanded = true;
    _loadChildren();
  }

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _loadChildren() {
    if (FileSystemEntity.isDirectorySync(widget.path)) {
      _children = FileService().getFiles(widget.path);
    }
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) _loadChildren();
    });
  }

  void _onTap() async {
    if (FileSystemEntity.isDirectorySync(widget.path)) {
      _toggle();
    } else {
      try {
        final content = await FileService().readFile(widget.path);
        final name = widget.path.split(Platform.pathSeparator).last;
        EditorService().openFile(name, content, realPath: widget.path);
      } catch (e) {
        debugPrint("Error reading file: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRoot && widget.level == 0) {
      // Don't show the root folder itself, just its children
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _children
            .map((e) => FileTreeItem(path: e.path, level: widget.level + 1))
            .toList(),
      );
    }

    final name = widget.path.split(Platform.pathSeparator).last;
    final isDirectory = FileSystemEntity.isDirectorySync(widget.path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlyoutTarget(
          controller: _flyoutController,
          child: GestureDetector(
            onSecondaryTap: () {
              ExplorerLogic.showContextMenu(
                context,
                widget.path,
                _flyoutController,
                () => setState(() => _loadChildren()),
              );
            },
            child: HoverButton(
              onPressed: _onTap,
              builder: (context, states) {
                return Container(
                  padding: EdgeInsets.only(left: 12.0 * widget.level, right: 8),
                  height: 28,
                  color: states.isHovered
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Icon(
                        isDirectory
                            ? (_isExpanded
                                  ? FluentIcons.chevron_down
                                  : FluentIcons.chevron_right)
                            : FluentIcons.page_list,
                        size: isDirectory ? 8 : 14,
                        color: isDirectory
                            ? Colors.grey
                            : const Color(0xFF599E5E),
                      ),
                      const SizedBox(width: 6),
                      if (isDirectory)
                        const Icon(
                          FluentIcons.folder_horizontal,
                          size: 14,
                          color: Color(0xFFDCB67A),
                        ),
                      if (isDirectory) const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: KetTheme.textMain,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (isDirectory && _isExpanded)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _children
                .map((e) => FileTreeItem(path: e.path, level: widget.level + 1))
                .toList(),
          ),
      ],
    );
  }
}
