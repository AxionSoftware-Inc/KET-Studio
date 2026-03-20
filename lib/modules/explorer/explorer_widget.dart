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
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isCreatingFile = false;
  bool _isCreatingFolder = false;
  int _treeVersion = 0;

  @override
  void initState() {
    super.initState();
    FileService().addListener(_onFileServiceChanged);
    EditorService().addListener(_onFileServiceChanged);
  }

  @override
  void dispose() {
    FileService().removeListener(_onFileServiceChanged);
    EditorService().removeListener(_onFileServiceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onFileServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rootPath = FileService().rootPath;
    final folderName = rootPath.split(Platform.pathSeparator).last.toUpperCase();

    return Column(
      children: [
        // Header with Actions
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: KetTheme.bgHeader,
            border: Border(bottom: BorderSide(color: KetTheme.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  folderName,
                  style: KetTheme.headerStyle.copyWith(
                    color: KetTheme.textMain,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ActionButton(
                icon: FluentIcons.page_add,
                onPressed: () => setState(() => _isCreatingFile = true),
                tooltip: "New File",
              ),
              _ActionButton(
                icon: FluentIcons.folder_horizontal,
                onPressed: () => setState(() => _isCreatingFolder = true),
                tooltip: "New Folder",
              ),
              _ActionButton(
                icon: FluentIcons.refresh,
                onPressed: () => setState(() {}),
                tooltip: "Refresh Explorer",
              ),
              _ActionButton(
                icon: FluentIcons.collapse_content,
                onPressed: () {
                  setState(() => _treeVersion++);
                },
                tooltip: "Collapse All",
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextBox(
            controller: _searchController,
            placeholder: "Filter files...",
            prefix: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(FluentIcons.search, size: 12),
            ),
            suffix: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(FluentIcons.clear, size: 10),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    },
                  )
                : null,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: KetTheme.bodyStyle.copyWith(fontSize: 12),
          ),
        ),

        // Recursive Tree
        Expanded(
          child: Container(
            color: KetTheme.bgSidebar,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  if (_isCreatingFile || _isCreatingFolder)
                    _InlineCreationItem(
                      isFile: _isCreatingFile,
                      parentPath: rootPath,
                      onCancel: () => setState(() {
                        _isCreatingFile = false;
                        _isCreatingFolder = false;
                      }),
                      onCreated: () => setState(() {
                        _isCreatingFile = false;
                        _isCreatingFolder = false;
                      }),
                    ),
                  FileTreeItem(
                    key: ValueKey(rootPath + _searchQuery + _treeVersion.toString()),
                    path: rootPath,
                    isRoot: true,
                    level: 0,
                    searchQuery: _searchQuery,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 12, color: KetTheme.textMuted),
        onPressed: onPressed,
        style: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isHovered) return KetTheme.bgHover;
            return Colors.transparent;
          }),
        ),
      ),
    );
  }
}

class FileTreeItem extends StatefulWidget {
  final String path;
  final bool isRoot;
  final int level;
  final String searchQuery;

  const FileTreeItem({
    super.key,
    required this.path,
    this.isRoot = false,
    required this.level,
    this.searchQuery = "",
  });

  @override
  State<FileTreeItem> createState() => _FileTreeItemState();
}

class _FileTreeItemState extends State<FileTreeItem> {
  bool _isExpanded = false;
  List<FileSystemEntity> _children = [];
  final FlyoutController _flyoutController = FlyoutController();
  bool _isCreatingFile = false;
  bool _isCreatingFolder = false;

  @override
  void initState() {
    super.initState();
    if (widget.isRoot || widget.searchQuery.isNotEmpty) _isExpanded = true;
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
      if (widget.searchQuery.isNotEmpty) {
        _children = _children.where((e) {
          final name = e.path.split(Platform.pathSeparator).last.toLowerCase();
          return name.contains(widget.searchQuery);
        }).toList();
      }
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _children
            .map((e) => FileTreeItem(
                  path: e.path,
                  level: widget.level + 1,
                  searchQuery: widget.searchQuery,
                ))
            .toList(),
      );
    }

    final name = widget.path.split(Platform.pathSeparator).last;
    final isDirectory = FileSystemEntity.isDirectorySync(widget.path);
    final activePath = EditorService().activeFile?.path;
    final isActive = !isDirectory && activePath == widget.path;

    if (widget.searchQuery.isNotEmpty && !isDirectory && !name.toLowerCase().contains(widget.searchQuery)) {
      return const SizedBox.shrink();
    }

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
                onRefresh: () => setState(() => _loadChildren()),
                onCreateFile: () => setState(() {
                  _isExpanded = true;
                  _isCreatingFile = true;
                }),
                onCreateFolder: () => setState(() {
                  _isExpanded = true;
                  _isCreatingFolder = true;
                }),
              );
            },
            child: HoverButton(
              onPressed: _onTap,
              builder: (context, states) {
                return Container(
                  padding: EdgeInsets.only(left: 14.0 * widget.level, right: 8),
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive
                        ? KetTheme.accentSoft
                        : (states.isHovered ? KetTheme.bgHover : Colors.transparent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      if (isDirectory)
                        Icon(
                          _isExpanded ? FluentIcons.chevron_down : FluentIcons.chevron_right,
                          size: 10,
                          color: KetTheme.textMuted,
                        )
                      else
                        const SizedBox(width: 10),
                      const SizedBox(width: 4),
                      _FileIcon(path: widget.path, isDirectory: isDirectory, isExpanded: _isExpanded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: KetTheme.bodyStyle.copyWith(
                            color: isActive ? KetTheme.textMain : KetTheme.textSecondary,
                            fontSize: 12.5,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (states.isHovered && !isActive)
                        Icon(
                          isDirectory ? FluentIcons.folder_open : FluentIcons.open_file,
                          size: 10,
                          color: KetTheme.textMuted.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (isDirectory && _isExpanded) ...[
          if (_isCreatingFile || _isCreatingFolder)
            _InlineCreationItem(
              isFile: _isCreatingFile,
              parentPath: widget.path,
              level: widget.level + 1,
              onCancel: () => setState(() {
                _isCreatingFile = false;
                _isCreatingFolder = false;
              }),
              onCreated: () => setState(() {
                _isCreatingFile = false;
                _isCreatingFolder = false;
                _loadChildren();
              }),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _children
                .map((e) => FileTreeItem(
                      path: e.path,
                      level: widget.level + 1,
                      searchQuery: widget.searchQuery,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _FileIcon extends StatelessWidget {
  final String path;
  final bool isDirectory;
  final bool isExpanded;

  const _FileIcon({
    required this.path,
    required this.isDirectory,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDirectory) {
      return Icon(
        isExpanded ? FluentIcons.folder_open : FluentIcons.folder_horizontal,
        size: 14,
        color: KetTheme.warning,
      );
    }

    final ext = path.split('.').last.toLowerCase();
    IconData iconData = FluentIcons.page_list;
    Color color = KetTheme.textMuted;

    switch (ext) {
      case 'dart':
        iconData = FluentIcons.process_meta_task;
        color = const Color(0xFF00C4FF);
        break;
      case 'py':
        iconData = FluentIcons.code;
        color = const Color(0xFF3776AB);
        break;
      case 'md':
        iconData = FluentIcons.edit;
        color = const Color(0xFF6A7686);
        break;
      case 'json':
      case 'yaml':
      case 'yml':
        iconData = FluentIcons.settings;
        color = KetTheme.accent;
        break;
      case 'html':
      case 'htm':
        iconData = FluentIcons.embed;
        color = const Color(0xFFE34F26);
        break;
      case 'css':
        iconData = FluentIcons.css;
        color = const Color(0xFF1572B6);
        break;
      case 'js':
      case 'ts':
        iconData = FluentIcons.code;
        color = const Color(0xFFF7DF1E);
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'svg':
        iconData = FluentIcons.photo;
        color = const Color(0xFF2ACF8B);
        break;
    }

    return Icon(iconData, size: 14, color: color);
  }
}

class _InlineCreationItem extends StatefulWidget {
  final bool isFile;
  final String parentPath;
  final int level;
  final VoidCallback onCancel;
  final VoidCallback onCreated;

  const _InlineCreationItem({
    required this.isFile,
    required this.parentPath,
    this.level = 1,
    required this.onCancel,
    required this.onCreated,
  });

  @override
  State<_InlineCreationItem> createState() => _InlineCreationItemState();
}

class _InlineCreationItemState extends State<_InlineCreationItem> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      final fullPath = "${widget.parentPath}${Platform.pathSeparator}$name";
      try {
        if (widget.isFile) {
          await FileService().createFile(fullPath);
        } else {
          await FileService().createFolder(fullPath);
        }
        widget.onCreated();
      } catch (e) {
        debugPrint("Creation error: $e");
      }
    } else {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 14.0 * widget.level, right: 8, bottom: 2),
      child: Row(
        children: [
          _FileIcon(
            path: widget.isFile ? "file.txt" : "folder",
            isDirectory: !widget.isFile,
            isExpanded: false,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextBox(
              controller: _controller,
              focusNode: _focusNode,
              onSubmitted: (_) => _submit(),
              onEditingComplete: _submit,
              placeholder: widget.isFile ? "file name..." : "folder name...",
              style: KetTheme.bodyStyle.copyWith(fontSize: 12),
              decoration: WidgetStateProperty.all(
                BoxDecoration(
                  border: Border(bottom: BorderSide(color: KetTheme.accent, width: 1.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
