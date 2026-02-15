import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/file_service.dart';
import '../../core/services/editor_service.dart';

class ExplorerLogic {
  static void showContextMenu(
    BuildContext context,
    String path,
    FlyoutController controller,
    VoidCallback onRefresh,
  ) {
    bool isDirectory = FileSystemEntity.isDirectorySync(path);

    controller.showFlyout(
      builder: (context) {
        return MenuFlyout(
          items: [
            if (isDirectory) ...[
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.page_add, size: 14),
                text: const Text('New File'),
                onPressed: () => showNameDialog(
                  context,
                  path,
                  isFile: true,
                  onDone: onRefresh,
                ),
              ),
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.folder_horizontal, size: 14),
                text: const Text('New Folder'),
                onPressed: () => showNameDialog(
                  context,
                  path,
                  isFile: false,
                  onDone: onRefresh,
                ),
              ),
              const MenuFlyoutSeparator(),
            ],
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.edit, size: 14),
              text: const Text('Rename'),
              onPressed: () =>
                  showRenameDialog(context, path, onDone: onRefresh),
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.delete, size: 14),
              text: const Text('Delete'),
              onPressed: () => deleteItem(context, path, onRefresh),
            ),
          ],
        );
      },
    );
  }

  static void showNameDialog(
    BuildContext context,
    String parentPath, {
    required bool isFile,
    required VoidCallback onDone,
  }) {
    if (FileSystemEntity.isFileSync(parentPath)) {
      parentPath = File(parentPath).parent.path;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(isFile ? "New File" : "New Folder"),
        content: TextBox(
          controller: controller,
          placeholder: "Enter name...",
          autofocus: true,
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final fullPath = "$parentPath${Platform.pathSeparator}$name";
                try {
                  if (isFile) {
                    await FileService().createFile(fullPath);
                  } else {
                    await FileService().createFolder(fullPath);
                  }
                  onDone();
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint("Error creating: $e");
                }
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
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
        content: TextBox(controller: controller, autofocus: true),
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
    try {
      // Agar ochiq bo'lsa yopamiz
      final editor = EditorService();
      final index = editor.files.indexWhere((f) => f.path == path);
      if (index != -1) editor.closeFile(index);

      await FileService().deleteEntity(path);
      onDone();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }
}
