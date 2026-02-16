import 'package:fluent_ui/fluent_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  Color _accentColor = const Color(0xFF9C27B0);
  Color get accentColor => _accentColor;

  double _fontSize = 14.0;
  double get fontSize => _fontSize;

  bool _autoSave = true;
  bool get autoSave => _autoSave;

  String _pythonPath = "python";
  String get pythonPath => _pythonPath;

  final List<Color> availableAccents = [
    const Color(0xFF9C27B0), // Purple/Pink
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF9800), // Orange
    const Color(0xFFE91E63), // Pink
    const Color(0xFF00BCD4), // Cyan
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Theme
    final themeStr = prefs.getString('themeMode') ?? 'dark';
    _themeMode = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;

    // Load Accent
    final accentVal = prefs.getInt('accentColor');
    if (accentVal != null) {
      _accentColor = Color(accentVal);
    }

    // Load Font Size
    _fontSize = prefs.getDouble('fontSize') ?? 14.0;

    // Load Auto Save
    _autoSave = prefs.getBool('autoSave') ?? true;

    // Load Python Path
    _pythonPath = prefs.getString('pythonPath') ?? "python";

    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeMode',
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  void setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColor', color.value);
  }

  void setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
  }

  void setAutoSave(bool value) async {
    _autoSave = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSave', value);
  }

  void setPythonPath(String path) async {
    _pythonPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pythonPath', path);
  }
}
