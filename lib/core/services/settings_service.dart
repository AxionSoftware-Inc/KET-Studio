import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const _keyThemeMode = 'themeMode';
  static const _keyAccentColor = 'accentColor';
  static const _keyEditorFontSize = 'editorFontSize';
  static const _keyEditorLineHeight = 'editorLineHeight';
  static const _keyEditorWordWrap = 'editorWordWrap';
  static const _keyAutoSave = 'autoSave';
  static const _keyPythonPath = 'pythonPath';
  static const _keyTerminalFontSize = 'terminalFontSize';
  static const _keyTerminalAutoScroll = 'terminalAutoScroll';
  static const _keyTerminalMaxLines = 'terminalMaxLines';
  static const _keyClearTerminalOnRun = 'clearTerminalOnRun';
  static const _keyShowExecutionDetails = 'showExecutionDetails';
  static const _keyCompactMode = 'compactMode';
  static const _keyStartMaximized = 'startMaximized';

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  Color _accentColor = const Color(0xFF39C6AA);
  Color get accentColor => _accentColor;

  double _fontSize = 14.0;
  double get fontSize => _fontSize;

  double _editorLineHeight = 1.5;
  double get editorLineHeight => _editorLineHeight;

  bool _editorWordWrap = false;
  bool get editorWordWrap => _editorWordWrap;

  bool _autoSave = true;
  bool get autoSave => _autoSave;

  String _pythonPath = 'python';
  String get pythonPath => _pythonPath;

  double _terminalFontSize = 12.5;
  double get terminalFontSize => _terminalFontSize;

  bool _terminalAutoScroll = true;
  bool get terminalAutoScroll => _terminalAutoScroll;

  int _terminalMaxLines = 1000;
  int get terminalMaxLines => _terminalMaxLines;

  bool _clearTerminalOnRun = true;
  bool get clearTerminalOnRun => _clearTerminalOnRun;

  bool _showExecutionDetails = true;
  bool get showExecutionDetails => _showExecutionDetails;

  bool _compactMode = true;
  bool get compactMode => _compactMode;

  bool _startMaximized = true;
  bool get startMaximized => _startMaximized;

  final List<Color> availableAccents = const [
    Color(0xFF39C6AA),
    Color(0xFF43A5FF),
    Color(0xFF6FD36D),
    Color(0xFFFFB547),
    Color(0xFFFF7A59),
    Color(0xFF8B7CFF),
    Color(0xFFEF5DA8),
    Color(0xFF00B7C3),
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final themeStr = prefs.getString(_keyThemeMode) ?? 'dark';
    _themeMode = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;

    final accentVal = prefs.getInt(_keyAccentColor);
    if (accentVal != null) {
      _accentColor = Color(accentVal);
    }

    _fontSize = prefs.getDouble(_keyEditorFontSize) ?? 14.0;
    _editorLineHeight = prefs.getDouble(_keyEditorLineHeight) ?? 1.5;
    _editorWordWrap = prefs.getBool(_keyEditorWordWrap) ?? false;
    _autoSave = prefs.getBool(_keyAutoSave) ?? true;
    _pythonPath = prefs.getString(_keyPythonPath) ?? 'python';
    _terminalFontSize = prefs.getDouble(_keyTerminalFontSize) ?? 12.5;
    _terminalAutoScroll = prefs.getBool(_keyTerminalAutoScroll) ?? true;
    _terminalMaxLines = prefs.getInt(_keyTerminalMaxLines) ?? 1000;
    _clearTerminalOnRun = prefs.getBool(_keyClearTerminalOnRun) ?? true;
    _showExecutionDetails = prefs.getBool(_keyShowExecutionDetails) ?? true;
    _compactMode = prefs.getBool(_keyCompactMode) ?? true;
    _startMaximized = prefs.getBool(_keyStartMaximized) ?? true;

    notifyListeners();
  }

  Map<String, dynamic> snapshot() {
    return {
      'themeMode': _themeMode.name,
      'accentColor': _accentColor.toARGB32(),
      'editorFontSize': _fontSize,
      'editorLineHeight': _editorLineHeight,
      'editorWordWrap': _editorWordWrap,
      'autoSave': _autoSave,
      'pythonPath': _pythonPath,
      'terminalFontSize': _terminalFontSize,
      'terminalAutoScroll': _terminalAutoScroll,
      'terminalMaxLines': _terminalMaxLines,
      'clearTerminalOnRun': _clearTerminalOnRun,
      'showExecutionDetails': _showExecutionDetails,
      'compactMode': _compactMode,
      'startMaximized': _startMaximized,
    };
  }

  String exportJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(snapshot());
  }

  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.dark;
    _accentColor = const Color(0xFF39C6AA);
    _fontSize = 14.0;
    _editorLineHeight = 1.5;
    _editorWordWrap = false;
    _autoSave = true;
    _pythonPath = 'python';
    _terminalFontSize = 12.5;
    _terminalAutoScroll = true;
    _terminalMaxLines = 1000;
    _clearTerminalOnRun = true;
    _showExecutionDetails = true;
    _compactMode = true;
    _startMaximized = true;
    notifyListeners();
    await _persistAll();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
  }

  void setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentColor, color.toARGB32());
  }

  void setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyEditorFontSize, size);
  }

  void setEditorLineHeight(double value) async {
    _editorLineHeight = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyEditorLineHeight, value);
  }

  void setEditorWordWrap(bool value) async {
    _editorWordWrap = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEditorWordWrap, value);
  }

  void setAutoSave(bool value) async {
    _autoSave = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSave, value);
  }

  void setPythonPath(String path) async {
    _pythonPath = path.trim().isEmpty ? 'python' : path.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPythonPath, _pythonPath);
  }

  void setTerminalFontSize(double value) async {
    _terminalFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTerminalFontSize, value);
  }

  void setTerminalAutoScroll(bool value) async {
    _terminalAutoScroll = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTerminalAutoScroll, value);
  }

  void setTerminalMaxLines(int value) async {
    _terminalMaxLines = value.clamp(200, 10000);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTerminalMaxLines, _terminalMaxLines);
  }

  void setClearTerminalOnRun(bool value) async {
    _clearTerminalOnRun = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyClearTerminalOnRun, value);
  }

  void setShowExecutionDetails(bool value) async {
    _showExecutionDetails = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowExecutionDetails, value);
  }

  void setCompactMode(bool value) async {
    _compactMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompactMode, value);
  }

  void setStartMaximized(bool value) async {
    _startMaximized = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStartMaximized, value);
  }

  Future<void> _persistAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeMode.name);
    await prefs.setInt(_keyAccentColor, _accentColor.toARGB32());
    await prefs.setDouble(_keyEditorFontSize, _fontSize);
    await prefs.setDouble(_keyEditorLineHeight, _editorLineHeight);
    await prefs.setBool(_keyEditorWordWrap, _editorWordWrap);
    await prefs.setBool(_keyAutoSave, _autoSave);
    await prefs.setString(_keyPythonPath, _pythonPath);
    await prefs.setDouble(_keyTerminalFontSize, _terminalFontSize);
    await prefs.setBool(_keyTerminalAutoScroll, _terminalAutoScroll);
    await prefs.setInt(_keyTerminalMaxLines, _terminalMaxLines);
    await prefs.setBool(_keyClearTerminalOnRun, _clearTerminalOnRun);
    await prefs.setBool(_keyShowExecutionDetails, _showExecutionDetails);
    await prefs.setBool(_keyCompactMode, _compactMode);
    await prefs.setBool(_keyStartMaximized, _startMaximized);
  }
}
