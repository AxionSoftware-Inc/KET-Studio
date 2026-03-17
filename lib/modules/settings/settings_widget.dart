import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../core/services/python_setup_service.dart';
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

  String _section = 'appearance';

  @override
  void dispose() {
    _pythonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([SettingsService(), PythonSetupService()]),
      builder: (context, _) {
        final settings = SettingsService();
        final setup = PythonSetupService();
        if (_pythonController.text != settings.pythonPath) {
          _pythonController.text = settings.pythonPath;
        }

        return ContentDialog(
          title: Row(
            children: [
              Icon(FluentIcons.settings, color: KetTheme.accent, size: 18),
              const SizedBox(width: 10),
              const Text('Settings'),
            ],
          ),
          constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
          content: SizedBox(
            width: 980,
            height: 620,
            child: Row(
              children: [
                _buildSidebar(),
                const SizedBox(width: 18),
                Expanded(
                  child: DecoratedBox(
                    decoration: KetTheme.panelSurface(),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: _buildSection(settings, setup),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: _copySettingsJson,
              child: const Text('Copy JSON'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 210,
      child: DecoratedBox(
        decoration: KetTheme.panelSurface(elevated: true),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CONFIGURATION', style: KetTheme.headerStyle),
              const SizedBox(height: 14),
              _SectionButton(
                label: 'Appearance',
                icon: FluentIcons.color,
                selected: _section == 'appearance',
                onPressed: () => setState(() => _section = 'appearance'),
              ),
              _SectionButton(
                label: 'Editor',
                icon: FluentIcons.edit,
                selected: _section == 'editor',
                onPressed: () => setState(() => _section = 'editor'),
              ),
              _SectionButton(
                label: 'Terminal',
                icon: FluentIcons.command_prompt,
                selected: _section == 'terminal',
                onPressed: () => setState(() => _section = 'terminal'),
              ),
              _SectionButton(
                label: 'Environment',
                icon: FluentIcons.processing,
                selected: _section == 'environment',
                onPressed: () => setState(() => _section = 'environment'),
              ),
              _SectionButton(
                label: 'Advanced',
                icon: FluentIcons.developer_tools,
                selected: _section == 'advanced',
                onPressed: () => setState(() => _section = 'advanced'),
              ),
              const Spacer(),
              Text(
                'KET Studio professional configuration surface',
                style: KetTheme.descriptionStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(SettingsService settings, PythonSetupService setup) {
    switch (_section) {
      case 'appearance':
        return _buildAppearance(settings);
      case 'editor':
        return _buildEditor(settings);
      case 'terminal':
        return _buildTerminal(settings);
      case 'environment':
        return _buildEnvironment(settings, setup);
      case 'advanced':
        return _buildAdvanced(settings, setup);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAppearance(SettingsService settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Appearance',
          subtitle: 'Global application shell, density, and theme controls.',
        ),
        const SizedBox(height: 18),
        _SettingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabeledRow(
                title: 'Theme mode',
                subtitle: 'Switch between light and dark desktop themes.',
                trailing: SizedBox(
                  width: 180,
                  child: ComboBox<ThemeMode>(
                    value: settings.themeMode,
                    items: const [
                      ComboBoxItem(value: ThemeMode.dark, child: Text('Dark')),
                      ComboBoxItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) settings.setThemeMode(value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Accent color', style: KetTheme.bodyStyle),
              const SizedBox(height: 6),
              Text(
                'Used across active panels, buttons, and emphasis states.',
                style: KetTheme.descriptionStyle,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: settings.availableAccents.map((color) {
                  final selected =
                      settings.accentColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => settings.setAccentColor(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              FluentIcons.check_mark,
                              color: Colors.white,
                              size: 12,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ToggleCard(
          title: 'Compact density',
          subtitle: 'Use tighter spacing across menus, bars, and controls.',
          value: settings.compactMode,
          onChanged: settings.setCompactMode,
        ),
        const SizedBox(height: 14),
        _ToggleCard(
          title: 'Start maximized',
          subtitle: 'Open the desktop shell maximized on startup.',
          value: settings.startMaximized,
          onChanged: settings.setStartMaximized,
        ),
      ],
    );
  }

  Widget _buildEditor(SettingsService settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Editor',
          subtitle: 'Code editing behavior, readability, and save workflow.',
        ),
        const SizedBox(height: 18),
        _SliderCard(
          title: 'Editor font size',
          subtitle: 'Controls the main code editor text size.',
          valueLabel: '${settings.fontSize.toStringAsFixed(1)} px',
          value: settings.fontSize,
          min: 10,
          max: 24,
          onChanged: settings.setFontSize,
        ),
        const SizedBox(height: 14),
        _SliderCard(
          title: 'Editor line height',
          subtitle: 'Increase vertical spacing for denser or airier code.',
          valueLabel: settings.editorLineHeight.toStringAsFixed(2),
          value: settings.editorLineHeight,
          min: 1.1,
          max: 2.0,
          onChanged: settings.setEditorLineHeight,
        ),
        const SizedBox(height: 14),
        _ToggleCard(
          title: 'Word wrap',
          subtitle: 'Wrap long lines inside the editor viewport.',
          value: settings.editorWordWrap,
          onChanged: settings.setEditorWordWrap,
        ),
        const SizedBox(height: 14),
        _ToggleCard(
          title: 'Auto save',
          subtitle: 'Persist real files automatically after edits settle.',
          value: settings.autoSave,
          onChanged: settings.setAutoSave,
        ),
      ],
    );
  }

  Widget _buildTerminal(SettingsService settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Terminal',
          subtitle: 'Runtime output rendering, retention, and run logging.',
        ),
        const SizedBox(height: 18),
        _SliderCard(
          title: 'Terminal font size',
          subtitle: 'Controls terminal output and stdin input text size.',
          valueLabel: '${settings.terminalFontSize.toStringAsFixed(1)} px',
          value: settings.terminalFontSize,
          min: 10,
          max: 22,
          onChanged: settings.setTerminalFontSize,
        ),
        const SizedBox(height: 14),
        _SettingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maximum retained terminal lines',
                style: KetTheme.bodyStyle,
              ),
              const SizedBox(height: 6),
              Text(
                'Older lines are trimmed once this limit is reached.',
                style: KetTheme.descriptionStyle,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: settings.terminalMaxLines.toDouble(),
                      min: 200,
                      max: 5000,
                      divisions: 24,
                      onChanged: (value) {
                        settings.setTerminalMaxLines(value.round());
                      },
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '${settings.terminalMaxLines}',
                      textAlign: TextAlign.end,
                      style: KetTheme.statusStyle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ToggleCard(
          title: 'Auto scroll terminal',
          subtitle: 'Keep the terminal pinned to the latest output.',
          value: settings.terminalAutoScroll,
          onChanged: settings.setTerminalAutoScroll,
        ),
        const SizedBox(height: 14),
        _ToggleCard(
          title: 'Clear terminal on run',
          subtitle: 'Clear previous output before starting a new execution.',
          value: settings.clearTerminalOnRun,
          onChanged: settings.setClearTerminalOnRun,
        ),
        const SizedBox(height: 14),
        _ToggleCard(
          title: 'Show execution details',
          subtitle: 'Print interpreter, project, and entrypoint metadata.',
          value: settings.showExecutionDetails,
          onChanged: settings.setShowExecutionDetails,
        ),
      ],
    );
  }

  Widget _buildEnvironment(SettingsService settings, PythonSetupService setup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Environment',
          subtitle: 'Interpreter path, Python environment, and Qiskit status.',
        ),
        const SizedBox(height: 18),
        _SettingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Python interpreter', style: KetTheme.bodyStyle),
              const SizedBox(height: 6),
              Text(
                'This path is used for script execution and package management.',
                style: KetTheme.descriptionStyle,
              ),
              const SizedBox(height: 12),
              TextBox(
                controller: _pythonController,
                placeholder: 'python or full path to python.exe',
                onChanged: settings.setPythonPath,
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Button(
                      onPressed: () => _selectPythonExecutable(settings),
                      child: const Text('Browse'),
                    ),
                    const SizedBox(width: 6),
                    Button(
                      onPressed: () {
                        _pythonController.text = 'python';
                        settings.setPythonPath('python');
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Environment status', style: KetTheme.bodyStyle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatusPill(
                    label: setup.isSetupComplete ? 'Ready' : 'Not ready',
                    accent: setup.isSetupComplete
                        ? KetTheme.success
                        : KetTheme.warning,
                  ),
                  _StatusPill(
                    label: setup.isBusy ? 'Provisioning' : 'Idle',
                    accent: setup.isBusy ? KetTheme.accent : KetTheme.textMuted,
                  ),
                  _StatusPill(
                    label: 'Qiskit ${setup.qiskitVersion}',
                    accent: KetTheme.accent,
                  ),
                ],
              ),
              if (setup.currentTask.value != null) ...[
                const SizedBox(height: 14),
                Text(
                  setup.currentTask.value!,
                  style: KetTheme.descriptionStyle,
                ),
                const SizedBox(height: 8),
                ProgressBar(value: setup.progress.value * 100),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  FilledButton(
                    onPressed: setup.isBusy
                        ? null
                        : () => setup.checkAndInstallDependencies(force: true),
                    child: const Text('Rebuild Environment'),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: _copySettingsJson,
                    child: const Text('Copy Config'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvanced(SettingsService settings, PythonSetupService setup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Advanced',
          subtitle: 'Diagnostics, configuration export, and recovery actions.',
        ),
        const SizedBox(height: 18),
        _SettingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configuration preview', style: KetTheme.bodyStyle),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KetTheme.bgCanvas.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KetTheme.border),
                ),
                child: SelectableText(
                  settings.exportJson(),
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reset settings', style: KetTheme.bodyStyle),
                    const SizedBox(height: 6),
                    Text(
                      'Restore all persisted settings to their default values.',
                      style: KetTheme.descriptionStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () async {
                  await settings.resetToDefaults();
                  _pythonController.text = settings.pythonPath;
                  if (mounted) setState(() {});
                },
                child: const Text('Reset Defaults'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Runtime snapshot', style: KetTheme.bodyStyle),
              const SizedBox(height: 8),
              Text(
                'Platform: ${Platform.operatingSystem}\nInterpreter: ${settings.pythonPath}\nEnvironment ready: ${setup.isSetupComplete}',
                style: KetTheme.descriptionStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectPythonExecutable(SettingsService settings) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: Platform.isWindows ? ['exe'] : [],
    );
    if (result?.files.single.path == null) return;

    final path = result!.files.single.path!;
    _pythonController.text = path;
    settings.setPythonPath(path);
  }

  Future<void> _copySettingsJson() async {
    await Clipboard.setData(
      ClipboardData(text: SettingsService().exportJson()),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: KetTheme.bodyStyle.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text(subtitle, style: KetTheme.descriptionStyle),
      ],
    );
  }
}

class _SectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _SectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? KetTheme.accentSoft
                  : (states.isHovered ? KetTheme.bgHover : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? KetTheme.accent.withValues(alpha: 0.28)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? KetTheme.accent : KetTheme.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: KetTheme.bodyStyle.copyWith(
                    color: selected
                        ? KetTheme.textMain
                        : KetTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;

  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: KetTheme.panelSurface(elevated: true),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      child: _LabeledRow(
        title: title,
        subtitle: subtitle,
        trailing: ToggleSwitch(checked: value, onChanged: onChanged),
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderCard({
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: KetTheme.bodyStyle)),
              Text(valueLabel, style: KetTheme.statusStyle),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: KetTheme.descriptionStyle),
          const SizedBox(height: 12),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _LabeledRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KetTheme.bodyStyle),
              const SizedBox(height: 6),
              Text(subtitle, style: KetTheme.descriptionStyle),
            ],
          ),
        ),
        const SizedBox(width: 16),
        trailing,
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusPill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: KetTheme.statusStyle.copyWith(color: accent)),
    );
  }
}
