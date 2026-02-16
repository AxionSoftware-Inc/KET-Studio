import 'package:flutter/foundation.dart';

enum VizType {
  bloch,
  matrix,
  chart,
  quantum,
  circuit,
  image,
  table,
  text,
  heatmap,
  error, // <--- New error type
  none,
}

class VizData {
  final VizType type;
  final dynamic data;
  final DateTime timestamp;

  VizData({required this.type, required this.data})
    : timestamp = DateTime.now();
}

class VizService extends ChangeNotifier {
  static final VizService _instance = VizService._internal();
  factory VizService() => _instance;
  VizService._internal();

  final List<VizData> _history = [];
  List<VizData> get history => _history;

  VizData? _currentData;
  VizData? get currentData => _currentData;

  void updateData(VizType type, dynamic data) {
    _currentData = VizData(type: type, data: data);
    _history.insert(0, _currentData!); // Add to history (newest first)
    if (_history.length > 50) _history.removeLast(); // Limit history
    notifyListeners();
  }

  void setCurrent(VizData data) {
    _currentData = data;
    notifyListeners();
  }

  void clear() {
    _currentData = null;
    _history.clear();
    notifyListeners();
  }
}
