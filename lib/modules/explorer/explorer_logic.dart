import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/file_service.dart';
import '../../core/services/editor_service.dart';
import '../../core/services/command_service.dart';
import 'package:flutter/services.dart';

class ExplorerLogic {
  static void showContextMenu(
    BuildContext context,
    String path,
    FlyoutController controller, {
    required VoidCallback onRefresh,
    required VoidCallback onCreateFile,
    required VoidCallback onCreateFolder,
  }) {
    bool isDirectory = FileSystemEntity.isDirectorySync(path);

    controller.showFlyout(
      builder: (context) {
        return MenuFlyout(
          items: [
            if (isDirectory) ...[
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.page_add, size: 14),
                text: const Text('New File'),
                onPressed: onCreateFile,
              ),
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.folder_horizontal, size: 14),
                text: const Text('New Folder'),
                onPressed: onCreateFolder,
              ),
              const MenuFlyoutSeparator(),
            ],
            if (!isDirectory) ...[
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.play, size: 14),
                text: const Text('Run Script'),
                onPressed: () => CommandService().execute("run.start"),
              ),
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.save, size: 14),
                text: const Text('Save'),
                onPressed: () => CommandService().execute("file.save"),
              ),
              const MenuFlyoutSeparator(),
            ],
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.copy, size: 14),
              text: const Text('Copy Path'),
              onPressed: () => FileService().copyPath(path),
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.link, size: 14),
              text: const Text('Copy Relative Path'),
              onPressed: () {
                final String root = FileService().rootPath;
                final String rel = path.replaceAll(root, "");
                Clipboard.setData(ClipboardData(text: rel));
              },
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.edit, size: 14),
              text: const Text('Rename'),
              onPressed: () =>
                  showRenameDialog(context, path, onDone: onRefresh),
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.move, size: 14),
              text: const Text('Move to...'),
              onPressed: () => showMoveDialog(context, path, onDone: onRefresh),
            ),
            MenuFlyoutItem(
              leading: Icon(FluentIcons.delete, size: 14, color: Colors.red),
              text: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => deleteItem(context, path, onRefresh),
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.folder_open, size: 14),
              text: const Text('Reveal in Explorer'),
              onPressed: () => FileService().revealInExplorer(path),
            ),
          ],
        );
      },
    );
  }

  static void showMoveDialog(
    BuildContext context,
    String oldPath, {
    required VoidCallback onDone,
  }) async {
    final name = oldPath.split(Platform.pathSeparator).last;
    final String? newParent = await FileService().pickDirectory();
    if (newParent != null) {
      final newPath = "$newParent${Platform.pathSeparator}$name";
      try {
        await FileService().moveEntity(oldPath, newPath);
        onDone();
      } catch (e) {
        debugPrint("Move error: $e");
      }
    }
  }

  static void showRenameDialog(
    BuildContext context,
    String oldPath, {
    required VoidCallback onDone,
  }) {
    final oldName = oldPath.split(Platform.pathSeparator).last;
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text("Rename"),
        content: TextBox(
          controller: controller,
          autofocus: true,
          onSubmitted: (_) async {
            final newName = controller.text.trim();
            if (newName.isNotEmpty) {
              try {
                final parentPath = File(oldPath).parent.path;
                final newPath = "$parentPath${Platform.pathSeparator}$newName";
                await FileService().renameEntity(oldPath, newName);
                EditorService().renameFile(oldPath, newPath);
                onDone();
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                debugPrint("Rename error: $e");
              }
            }
          },
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                try {
                  final parentPath = File(oldPath).parent.path;
                  final newPath =
                      "$parentPath${Platform.pathSeparator}$newName";

                  await FileService().renameEntity(oldPath, newName);
                  EditorService().renameFile(oldPath, newPath);

                  onDone();
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint("Rename error: $e");
                }
              }
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  static void deleteItem(
    BuildContext context,
    String path,
    VoidCallback onDone,
  ) async {
    final name = path.split(Platform.pathSeparator).last;

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text("Confirm Delete"),
        content: Text(
          "Are you sure you want to delete '$name'? This action cannot be undone.",
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final editor = EditorService();
                final index = editor.files.indexWhere((f) => f.path == path);
                if (index != -1) editor.closeFile(index);

                await FileService().deleteEntity(path);
                onDone();
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                debugPrint("Delete error: $e");
              }
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
