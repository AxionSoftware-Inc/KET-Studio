import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import '../core/services/command_service.dart';
import '../core/services/editor_service.dart';
import '../core/services/execution_service.dart';
import '../core/services/layout_service.dart';
import '../core/services/file_service.dart';
import '../modules/settings/settings_widget.dart';
import '../layout/widgets/package_dialog.dart';

void setupCommands(BuildContext context) {
  final commands = CommandService();
  final editor = EditorService();
  final file = FileService();
  final layout = LayoutService();
  final exec = ExecutionService();

  // --- FILE COMMANDS ---
  commands.registerCommand(
    Command(
      id: "file.new",
      title: "New Text File",
      icon: FluentIcons.page_add,
      shortcut: "Ctrl+N",
      action: () => editor.openFile("untitled.py", ""),
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.open",
      title: "Open File...",
      icon: FluentIcons.open_file,
      shortcut: "Ctrl+O",
      action: () async {
        final f = await file.pickFile();
        if (f != null) {
          final content = await f.readAsString();
          editor.openFile(
            f.path.split(Platform.pathSeparator).last,
            content,
            realPath: f.path,
          );
        }
      },
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.openFolder",
      title: "Open Folder...",
      icon: FluentIcons.folder_open,
      shortcut: "Ctrl+K",
      action: () => file.pickDirectory(),
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.save",
      title: "Save",
      icon: FluentIcons.save,
      shortcut: "Ctrl+S",
      isEnabled: () => editor.hasActiveFile.value,
      action: () async {
        final active = editor.activeFile;
        if (active == null) return;

        if (active.path.startsWith('/fake')) {
          final newPath = await file.saveFileAs(
            active.name,
            active.controller.text,
          );
          if (newPath != null) {
            // Success handled in service usually, or we can show InfoBar here
          }
        } else {
          await editor.saveActiveFile();
        }
      },
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.saveAs",
      title: "Save As...",
      icon: FluentIcons.save_as,
      isEnabled: () => editor.hasActiveFile.value,
      action: () async {
        final active = editor.activeFile;
        if (active != null) {
          await file.saveFileAs(active.name, active.controller.text);
        }
      },
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.saveAll",
      title: "Save All",
      isEnabled: () => editor.files.isNotEmpty,
      action: () => editor.saveAll(),
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.revert",
      title: "Revert File",
      icon: FluentIcons.refresh,
      isEnabled: () =>
          editor.hasActiveFile.value &&
          !editor.activeFile!.path.startsWith('/fake'),
      action: () => editor.revertFile(),
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.close",
      title: "Close File",
      icon: FluentIcons.cancel,
      shortcut: "Ctrl+W",
      isEnabled: () => editor.hasActiveFile.value,
      action: () => editor.closeActiveFile(),
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.closeAll",
      title: "Close All Files",
      isEnabled: () => editor.files.isNotEmpty,
      action: () => editor.closeAll(),
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.exit",
      title: "Exit",
      icon: FluentIcons.power_button,
      action: () => exit(0),
    ),
  );

  // --- EXPLORER / PROFESSIONAL COMMANDS ---
  commands.registerCommand(
    Command(
      id: "file.reveal",
      title: "Reveal in Explorer",
      icon: FluentIcons.folder_open,
      action: () {
        final active = editor.activeFile;
        if (active != null && !active.path.startsWith('/fake')) {
          file.revealInExplorer(active.path);
        }
      },
    ),
  );

  commands.registerCommand(
    Command(
      id: "file.copyPath",
      title: "Copy Path",
      icon: FluentIcons.copy,
      action: () {
        final active = editor.activeFile;
        if (active != null && !active.path.startsWith('/fake')) {
          file.copyPath(active.path);
        }
      },
    ),
  );

  // --- EDIT COMMANDS ---
  commands.registerCommand(
    Command(
      id: "edit.copyAll",
      title: "Copy All",
      icon: FluentIcons.copy,
      action: () async {
        final text = editor.activeFile?.controller.text ?? "";
        await Clipboard.setData(ClipboardData(text: text));
      },
    ),
  );

  // --- VIEW COMMANDS ---
  commands.registerCommand(
    Command(
      id: "view.toggleExplorer",
      title: "Toggle Explorer",
      icon: FluentIcons.fabric_folder_search,
      action: () => layout.toggleLeftPanel('explorer'),
    ),
  );

  commands.registerCommand(
    Command(
      id: "view.toggleViz",
      title: "Toggle Visualization",
      icon: FluentIcons.view_dashboard,
      action: () => layout.toggleRightPanel('vizualization'),
    ),
  );

  commands.registerCommand(
    Command(
      id: "view.toggleTerminal",
      title: "Toggle Terminal",
      icon: FluentIcons.command_prompt,
      action: () => layout.toggleBottomPanel(),
    ),
  );

  // --- RUN COMMANDS ---
  commands.registerCommand(
    Command(
      id: "run.start",
      title: "Run Script",
      icon: FluentIcons.play,
      shortcut: "F5",
      isEnabled: () => !exec.isRunning.value,
      action: () async {
        final active = editor.activeFile;
        if (active != null) {
          await editor.saveActiveFile();
          if (!layout.isBottomPanelVisible) layout.toggleBottomPanel();
          exec.runPython(active.path, content: active.controller.text);
        }
      },
    ),
  );

  commands.registerCommand(
    Command(
      id: "run.stop",
      title: "Stop",
      icon: FluentIcons.stop,
      shortcut: "Shift+F5",
      isEnabled: () => exec.isRunning.value,
      action: () => exec.stop(),
    ),
  );

  // --- HELP COMMANDS ---
  commands.registerCommand(
    Command(
      id: "help.packages",
      title: "Manage Packages",
      icon: FluentIcons.packages,
      action: () {
        showDialog(
          context: context,
          builder: (context) => const PackageDialog(),
        );
      },
    ),
  );

  commands.registerCommand(
    Command(
      id: "settings.open",
      title: "Settings",
      icon: FluentIcons.settings,
      shortcut: "Ctrl+,",
      action: () {
        showDialog(
          context: context,
          builder: (context) => const SettingsWidget(),
        );
      },
    ),
  );
}
