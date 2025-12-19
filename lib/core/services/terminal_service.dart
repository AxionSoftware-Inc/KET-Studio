import 'package:flutter/material.dart';

class TerminalService extends ChangeNotifier {
  static final TerminalService _instance = TerminalService._internal();
  factory TerminalService() => _instance;
  TerminalService._internal();

  // Terminaldagi qatorlar
  final List<String> _logs = [];

  // Getter
  List<String> get logs => _logs;

  // Yozuv qo'shish (Masalan: "Process started...")
  void write(String text) {
    _logs.add(text);
    // Agar 1000 qatordan oshsa, eskilarini o'chiramiz (xotirani tejash uchun)
    if (_logs.length > 1000) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  // Tozalash (clear)
  void clear() {
    _logs.clear();
    notifyListeners();
  }
}