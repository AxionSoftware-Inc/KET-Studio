import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/ket_theme.dart';

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  final _pythonController = TextEditingController(
    text: SettingsService().pythonPath,
  );

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();

    return ContentDialog(
      title: const Text('IDE Settings'),
      constraints: const BoxConstraints(maxWidth: 500),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Appearance'),
            const SizedBox(height: 10),

            // Theme Mode
            ListTile(
              title: const Text('Theme Mode'),
              subtitle: const Text('Select light or dark interface'),
              trailing: ComboBox<ThemeMode>(
                value: settings.themeMode,
                items: ThemeMode.values.map((mode) {
                  return ComboBoxItem(
                    value: mode,
                    child: Text(mode.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (mode) {
                  if (mode != null) {
                    settings.setThemeMode(mode);
                  }
                },
              ),
            ),

            // Accent Color
            const SizedBox(height: 15),
            const Text(
              'Accent Color',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: settings.availableAccents.map((color) {
                bool isSelected =
                    settings.accentColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => settings.setAccentColor(color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            FluentIcons.check_mark,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 25),
            _buildSection('Editor'),

            // Font Size
            ListTile(
              title: const Text('Font Size'),
              subtitle: Text('${settings.fontSize.toInt()} px'),
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: settings.fontSize,
                  min: 10,
                  max: 24,
                  onChanged: (v) => settings.setFontSize(v),
                ),
              ),
            ),

            // Auto Save
            ToggleSwitch(
              checked: settings.autoSave,
              onChanged: (v) => settings.setAutoSave(v),
              content: const Text('Auto Save changes'),
            ),

            const SizedBox(height: 25),
            _buildSection('Environment'),

            // Python Path
            const SizedBox(height: 10),
            const Text('Python Interpreter Path'),
            const SizedBox(height: 5),
            TextBox(
              controller: _pythonController,
              placeholder: 'path/to/python.exe',
              onChanged: (v) => settings.setPythonPath(v),
              suffix: IconButton(
                icon: const Icon(FluentIcons.folder_open),
                onPressed: () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: Platform.isWindows ? ['exe'] : [],
                      );
                  if (result != null && result.files.single.path != null) {
                    final path = result.files.single.path!;
                    _pythonController.text = path;
                    settings.setPythonPath(path);
                  }
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: KetTheme.accent,
            letterSpacing: 1.2,
          ),
        ),
        const Divider(),
      ],
    );
  }
}
