import 'package:flutter/foundation.dart';

enum VizStatus { idle, running, hasOutput, error, stopped }

enum VizType {
  bloch,
  matrix,
  chart,
  dashboard,
  circuit,
  image,
  table,
  text,
  heatmap,
  inspector,
  error,
  none,
}

class VizEvent {
  final String sessionId;
  final VizType type;
  final dynamic payload;
  final DateTime timestamp;

  VizEvent({required this.sessionId, required this.type, required this.payload})
    : timestamp = DateTime.now();

  String get timeStr =>
      "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
}

class VizSession {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final List<VizEvent> events = [];
  VizStatus status;
  String? errorMessage;

  VizSession({required this.id, this.status = VizStatus.running})
    : startTime = DateTime.now();

  void addEvent(VizEvent event) {
    events.add(event);
    status = VizStatus.hasOutput;
  }
}

class VizService extends ChangeNotifier {
  static final VizService _instance = VizService._internal();
  factory VizService() => _instance;
  VizService._internal();

  final List<VizSession> _sessions = [];
  List<VizSession> get sessions => _sessions;

  VizSession? _currentSession;
  VizSession? get currentSession => _currentSession;

  VizStatus _status = VizStatus.idle;
  VizStatus get status => _status;

  VizEvent? _selectedEvent;
  VizEvent? get selectedEvent => _selectedEvent;

  void startSession(String id) {
    _currentSession = VizSession(id: id);
    _sessions.insert(0, _currentSession!);
    if (_sessions.length > 50) _sessions.removeLast();
    _status = VizStatus.running;
    _selectedEvent = null;
    notifyListeners();
  }

  void updateData(VizType type, dynamic payload) {
    if (_currentSession == null) return;

    final event = VizEvent(
      sessionId: _currentSession!.id,
      type: type,
      payload: payload,
    );

    _currentSession!.addEvent(event);
    _status = VizStatus.hasOutput;
    notifyListeners();
  }

  void endSession({int exitCode = 0, String? error}) {
    if (_currentSession == null) return;

    _currentSession!.endTime = DateTime.now();
    if (exitCode != 0 || error != null) {
      _currentSession!.status = VizStatus.error;
      _currentSession!.errorMessage = error;
      _status = VizStatus.error;
    } else if (_currentSession!.events.isEmpty) {
      _currentSession!.status = VizStatus.stopped;
      _status = VizStatus.stopped;
    } else {
      _currentSession!.status = VizStatus.stopped;
      _status = VizStatus.hasOutput;
    }
    notifyListeners();
  }

  void selectEvent(VizEvent? event) {
    _selectedEvent = event;
    notifyListeners();
  }

  void clear() {
    _currentSession = null;
    _sessions.clear();
    _selectedEvent = null;
    _status = VizStatus.idle;
    notifyListeners();
  }
}
