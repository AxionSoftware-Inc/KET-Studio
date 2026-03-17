import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'settings_service.dart';

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
    _limitLogs();
    _throttledNotify();
  }

  void writeLines(List<String> lines) {
    if (lines.isEmpty) return;
    _logs.addAll(lines);
    _limitLogs();
    _throttledNotify();
  }

  bool _isNotifyThrottled = false;
  void _throttledNotify() {
    if (!_isNotifyThrottled) {
      _isNotifyThrottled = true;
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 100), () {
        _isNotifyThrottled = false;
        notifyListeners();
      });
    }
  }

  void _limitLogs() {
    final maxLines = SettingsService().terminalMaxLines;
    if (_logs.length > maxLines) {
      _logs.removeRange(0, _logs.length - maxLines);
    }
  }

  bool _notifyScheduled = false;

  @override
  void notifyListeners() {
    if (_notifyScheduled) return;

    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle) {
      _notifyScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        super.notifyListeners();
      });
    } else {
      super.notifyListeners();
    }
  }

  // Tozalash (clear)
  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
