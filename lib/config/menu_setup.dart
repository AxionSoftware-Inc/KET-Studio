import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import '../core/services/menu_service.dart';
import '../core/services/editor_service.dart';
import '../core/services/execution_service.dart';
import '../core/services/layout_service.dart';
import '../core/services/file_service.dart';

void setupMenus(BuildContext context) {
  final menuService = MenuService();
  final editorService = EditorService();
  final fileService = FileService();
  final layout = LayoutService();
  menuService.clear();

  // ---------------- FILE MENU ----------------
  menuService.registerMenu("File", [
    MenuItemData(
      label: "New Text File",
      icon: FluentIcons.page_add,
      shortcut: "Ctrl+N",
      onTap: () {
        editorService.openFile("untitled.py", "");
      },
    ),
    MenuItemData(
      label: "Open File...",
      icon: FluentIcons.open_file,
      shortcut: "Ctrl+O",
      onTap: () async {
        final file = await fileService.pickFile();
        if (file != null) {
          final content = await file.readAsString();
          editorService.openFile(
            file.path.split(Platform.pathSeparator).last,
            content,
            realPath: file.path,
          );
        }
      },
    ),
    MenuItemData(
      label: "Open Folder...",
      icon: FluentIcons.folder_open,
      shortcut: "Ctrl+K",
      onTap: () async {
        await fileService.pickDirectory();
      },
    ),
    MenuItemData(
      label: "Save",
      icon: FluentIcons.save,
      shortcut: "Ctrl+S",
      onTap: () async {
        final active = editorService.activeFile;
        if (active != null) {
          if (active.path.startsWith('/fake')) {
            final newPath = await fileService.saveFileAs(
              active.name,
              active.controller.text,
            );
            if (newPath != null && context.mounted) {
              displayInfoBar(
                context,
                builder: (context, close) => const InfoBar(
                  title: Text('Saved As!'),
                  severity: InfoBarSeverity.success,
                ),
              );
            }
          } else {
            await editorService.saveActiveFile();
            if (context.mounted) {
              displayInfoBar(
                context,
                builder: (context, close) => const InfoBar(
                  title: Text('Saved!'),
                  severity: InfoBarSeverity.success,
                ),
                duration: const Duration(seconds: 2),
              );
            }
          }
        }
      },
    ),
    MenuItemData(
      label: "Save As...",
      icon: FluentIcons.save_as,
      onTap: () async {
        final active = editorService.activeFile;
        if (active != null) {
          await fileService.saveFileAs(active.name, active.controller.text);
        }
      },
    ),
    MenuItemData(
      label: "Save All",
      onTap: () async {
        await editorService.saveAll();
        if (context.mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => const InfoBar(
              title: Text('All Files Saved!'),
              severity: InfoBarSeverity.success,
            ),
          );
        }
      },
    ),
    MenuItemData.separator(),
    MenuItemData(
      label: "Close All",
      onTap: () {
        while (editorService.files.isNotEmpty) {
          editorService.closeFile(0);
        }
      },
    ),
    MenuItemData(
      label: "Exit",
      icon: FluentIcons.power_button,
      onTap: () => exit(0),
    ),
  ]);

  // ---------------- EDIT MENU ----------------
  menuService.registerMenu("Edit", [
    MenuItemData(
      label: "Copy All",
      icon: FluentIcons.copy,
      onTap: () async {
        final text = editorService.activeFile?.controller.text ?? "";
        await Clipboard.setData(ClipboardData(text: text));
      },
    ),
  ]);

  // ---------------- VIEW MENU ----------------
  menuService.registerMenu("View", [
    MenuItemData(
      label: "Toggle Explorer",
      icon: FluentIcons.fabric_folder_search,
      onTap: () => layout.toggleLeftPanel('explorer'),
    ),
    MenuItemData(
      label: "Toggle Visualization",
      icon: FluentIcons.view_dashboard,
      onTap: () => layout.toggleRightPanel('vizualization'),
    ),
    MenuItemData(
      label: "Toggle Terminal",
      icon: FluentIcons.command_prompt,
      onTap: () => layout.toggleBottomPanel(),
    ),
  ]);

  // ---------------- RUN MENU ----------------
  menuService.registerMenu("Run", [
    MenuItemData(
      label: "Run Script",
      icon: FluentIcons.play,
      shortcut: "F5",
      onTap: () async {
        final active = editorService.activeFile;
        if (active != null) {
          await editorService.saveActiveFile();
          if (!layout.isBottomPanelVisible) layout.toggleBottomPanel();
          ExecutionService().runPython(active.path);
        }
      },
    ),
    MenuItemData(
      label: "Stop",
      icon: FluentIcons.stop,
      shortcut: "Shift+F5",
      onTap: () => ExecutionService().stop(),
    ),
  ]);

  // ---------------- HELP MENU ----------------
  menuService.registerMenu("Help", [
    MenuItemData(
      label: "About KET Studio",
      icon: FluentIcons.info,
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text("About KET Studio"),
            content: const Text(
              "Quantum-Powered Python IDE.\nBuilt with Fluent UI & Flutter.",
            ),
            actions: [
              Button(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    ),
  ]);
}
