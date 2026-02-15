import 'package:flutter/foundation.dart';

enum VizType { bloch, matrix, chart, quantum, circuit, image, none }

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

  VizData? _currentData;
  VizData? get currentData => _currentData;

  void updateData(VizType type, dynamic data) {
    _currentData = VizData(type: type, data: data);
    notifyListeners();
  }

  void clear() {
    _currentData = null;
    notifyListeners();
  }
}
