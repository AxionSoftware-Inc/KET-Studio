import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/debug/debug_adapter.dart';
import '../core/experiments/experiment_lab.dart';
import '../core/experiments/experiment_record.dart';
import '../core/language/language_services.dart';
import '../core/quantum/circuit_diagram.dart';
import '../core/quantum/ket_ir.dart';
import '../core/quantum/quantum_backend.dart';
import '../core/quantum/quantum_debugger.dart';
import '../core/quantum/transpiler_pipeline.dart';
import '../core/workspace/workspace_graph.dart';
import '../core/workspace/workspace_session.dart';
import 'quantum/provider_registry.dart';
import 'search/project_search_service.dart';

enum WorkbenchSection { explorer, search, quantum, experiments, extensions }

enum WorkbenchBottomPanel { terminal, problems, output, debugConsole }

final class WorkbenchDocument {
  WorkbenchDocument({
    required this.id,
    required this.title,
    required this.languageId,
    required String text,
    String? savedText,
    this.path,
  })  : _text = text,
        _savedText = savedText ?? text;

  final String id;
  String title;
  final String languageId;
  String? path;
  String _text;
  String _savedText;
  int version = 1;

  String get text => _text;
  String get savedText => _savedText;
  bool get isDirty => _text != _savedText;
  Uri? get uri => path == null ? null : File(path!).absolute.uri;

  void update(String value) {
    if (_text == value) return;
    _text = value;
    version++;
  }

  void markSaved({String? newPath}) {
    if (newPath != null) {
      path = newPath;
      title = p.basename(newPath);
    }
    _savedText = _text;
  }
}

final class WorkbenchController extends ChangeNotifier {
  WorkbenchController() {
    _documents.addAll(<WorkbenchDocument>[
      WorkbenchDocument(
        id: 'bell.qasm',
        title: 'bell.qasm',
        languageId: 'openqasm3',
        text: _bellQasm,
      ),
      WorkbenchDocument(
        id: 'scratch.py',
        title: 'scratch.py',
        languageId: 'python',
        text: _scratchPython,
      ),
    ]);
    _activeDocumentId = _documents.first.id;
  }

  static const String _bellQasm = '''OPENQASM 3.0;
include "stdgates.inc";
qubit[2] q;
bit[2] c;
h q[0];
cx q[0], q[1];
measure q -> c;
''';

  static const String _scratchPython = '''from math import sqrt

amplitude = 1 / sqrt(2)
print("Bell amplitudes:", amplitude, amplitude)
''';

  WorkbenchSection _section = WorkbenchSection.explorer;
  WorkbenchBottomPanel _bottomPanel = WorkbenchBottomPanel.terminal;
  bool _bottomVisible = true;
  bool _inspectorVisible = true;
  final List<WorkbenchDocument> _documents = <WorkbenchDocument>[];
  late String _activeDocumentId;
  List<LanguageDiagnostic> _diagnostics = const <LanguageDiagnostic>[];
  final List<String> _output = <String>[];
  List<DebugStackFrame> _debugFrames = const <DebugStackFrame>[];
  QuantumResult? _quantumResult;
  QuantumDebugSnapshot? _quantumDebugSnapshot;
  ExperimentRecord? _lastExperiment;
  List<ExperimentRecord> _experimentHistory = const <ExperimentRecord>[];
  ExperimentComparison? _experimentComparison;
  KetCircuit? _quantumCircuit;
  CircuitDiagram? _circuitDiagram;
  TranspilationTrace? _transpilationTrace;
  WorkspaceGraph? _workspaceGraph;
  List<ProviderSnapshot> _providers = const <ProviderSnapshot>[];
  List<ProjectSearchMatch> _searchResults = const <ProjectSearchMatch>[];
  String _searchQuery = '';
  String _selectedBackendId = 'ket.local.statevector';
  String _selectedTargetId = 'local-statevector';
  String _noisePresetId = 'ideal';
  bool _running = false;
  String? _statusMessage;

  WorkbenchSection get section => _section;
  WorkbenchBottomPanel get bottomPanel => _bottomPanel;
  bool get bottomVisible => _bottomVisible;
  bool get inspectorVisible => _inspectorVisible;
  List<WorkbenchDocument> get documents => List.unmodifiable(_documents);
  WorkbenchDocument get activeDocument =>
      _documents.firstWhere((document) => document.id == _activeDocumentId);
  List<LanguageDiagnostic> get diagnostics => _diagnostics;
  List<String> get output => List.unmodifiable(_output);
  List<DebugStackFrame> get debugFrames => _debugFrames;
  QuantumResult? get quantumResult => _quantumResult;
  QuantumDebugSnapshot? get quantumDebugSnapshot => _quantumDebugSnapshot;
  ExperimentRecord? get lastExperiment => _lastExperiment;
  List<ExperimentRecord> get experimentHistory => _experimentHistory;
  ExperimentComparison? get experimentComparison => _experimentComparison;
  KetCircuit? get quantumCircuit => _quantumCircuit;
  CircuitDiagram? get circuitDiagram => _circuitDiagram;
  TranspilationTrace? get transpilationTrace => _transpilationTrace;
  WorkspaceGraph? get workspaceGraph => _workspaceGraph;
  List<ProviderSnapshot> get providers => _providers;
  List<ProjectSearchMatch> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  String get selectedBackendId => _selectedBackendId;
  String get selectedTargetId => _selectedTargetId;
  String get noisePresetId => _noisePresetId;
  bool get running => _running;
  String? get statusMessage => _statusMessage;

  void selectSection(WorkbenchSection value) {
    if (_section == value) return;
    _section = value;
    notifyListeners();
  }

  void showBottomPanel(WorkbenchBottomPanel value) {
    final changed = !_bottomVisible || _bottomPanel != value;
    _bottomVisible = true;
    _bottomPanel = value;
    if (changed) notifyListeners();
  }

  void toggleBottomPanel() {
    _bottomVisible = !_bottomVisible;
    notifyListeners();
  }

  void toggleInspector() {
    _inspectorVisible = !_inspectorVisible;
    notifyListeners();
  }

  void activateDocument(String id) {
    if (_activeDocumentId == id) return;
    if (_documents.every((document) => document.id != id)) return;
    _activeDocumentId = id;
    _diagnostics = const <LanguageDiagnostic>[];
    notifyListeners();
  }

  void updateActiveText(String text) {
    activeDocument.update(text);
    notifyListeners();
  }

  Future<WorkbenchDocument> openFile(String filePath) async {
    final absolute = File(filePath).absolute.path;
    final existing = _documents.where((document) => document.path == absolute).firstOrNull;
    if (existing != null) {
      activateDocument(existing.id);
      return existing;
    }
    final file = File(absolute);
    final text = await file.readAsString();
    final document = WorkbenchDocument(
      id: 'file:${file.absolute.uri}',
      title: p.basename(absolute),
      languageId: _languageForPath(absolute),
      text: text,
      path: absolute,
    );
    _documents.add(document);
    _activeDocumentId = document.id;
    _diagnostics = const <LanguageDiagnostic>[];
    notifyListeners();
    return document;
  }

  Future<void> saveActive({String? path}) async {
    final document = activeDocument;
    final target = path ?? document.path;
    if (target == null) throw StateError('A path is required to save ${document.title}.');
    final file = File(target).absolute;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.ket-tmp');
    await temporary.writeAsString(document.text, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    document.markSaved(newPath: file.path);
    _statusMessage = 'Saved ${file.path}';
    notifyListeners();
  }

  Future<String> materializePythonScratch() async {
    final document = activeDocument;
    if (document.languageId != 'python') throw StateError('Active document is not Python.');
    if (document.path != null) {
      if (document.isDirty) await saveActive();
      return document.path!;
    }
    final directory = Directory(p.join(Directory.current.path, '.ket', 'scratch'));
    await directory.create(recursive: true);
    final path = p.join(
      directory.path,
      '${document.id.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}.py',
    );
    final file = File(path);
    await file.writeAsString(document.text, flush: true);
    return file.path;
  }

  void setDiagnostics(List<LanguageDiagnostic> value) {
    _diagnostics = List.unmodifiable(value);
    if (_diagnostics.isNotEmpty) showBottomPanel(WorkbenchBottomPanel.problems);
    notifyListeners();
  }

  void clearDiagnostics() {
    _diagnostics = const <LanguageDiagnostic>[];
    notifyListeners();
  }

  void appendOutput(String value) {
    _output.add(value);
    if (_output.length > 2000) _output.removeRange(0, _output.length - 2000);
    notifyListeners();
  }

  void clearOutput() {
    _output.clear();
    notifyListeners();
  }

  void setDebugFrames(List<DebugStackFrame> frames) {
    _debugFrames = List.unmodifiable(frames);
    notifyListeners();
  }

  void setProviders(List<ProviderSnapshot> value) {
    _providers = List<ProviderSnapshot>.unmodifiable(value);
    notifyListeners();
  }

  void setExecutionTarget(String backendId, String targetId) {
    if (_selectedBackendId == backendId && _selectedTargetId == targetId) return;
    _selectedBackendId = backendId;
    _selectedTargetId = targetId;
    _statusMessage = 'Execution target: $backendId/$targetId';
    notifyListeners();
  }

  void setExperimentHistory(List<ExperimentRecord> value) {
    _experimentHistory = List<ExperimentRecord>.unmodifiable(value);
    notifyListeners();
  }

  void setExperimentComparison(ExperimentComparison? value) {
    _experimentComparison = value;
    notifyListeners();
  }

  void setSearchResults(String query, List<ProjectSearchMatch> value) {
    _searchQuery = query;
    _searchResults = List<ProjectSearchMatch>.unmodifiable(value);
    _section = WorkbenchSection.search;
    notifyListeners();
  }

  void setNoisePreset(String id) {
    if (_noisePresetId == id) return;
    _noisePresetId = id;
    _statusMessage = 'Noise preset: $id';
    notifyListeners();
  }

  void setQuantumExecution({
    required QuantumResult result,
    required QuantumDebugSnapshot debugSnapshot,
    required ExperimentRecord experiment,
    required KetCircuit circuit,
    required CircuitDiagram diagram,
    required TranspilationTrace transpilation,
    required WorkspaceGraph workspaceGraph,
  }) {
    _quantumResult = result;
    _quantumDebugSnapshot = debugSnapshot;
    _lastExperiment = experiment;
    _quantumCircuit = circuit;
    _circuitDiagram = diagram;
    _transpilationTrace = transpilation;
    _workspaceGraph = workspaceGraph;
    _section = WorkbenchSection.quantum;
    notifyListeners();
  }

  void setCircuitPreview({
    required String source,
    required KetCircuit circuit,
    required CircuitDiagram diagram,
  }) {
    activeDocument.update(source);
    _quantumCircuit = circuit;
    _circuitDiagram = diagram;
    _transpilationTrace = null;
    _workspaceGraph = null;
    _quantumResult = null;
    _quantumDebugSnapshot = null;
    _statusMessage = 'Circuit edited. Run again to refresh compiler/results.';
    notifyListeners();
  }

  void setQuantumDebugSnapshot(QuantumDebugSnapshot snapshot) {
    _quantumDebugSnapshot = snapshot;
    notifyListeners();
  }

  void setRunning(bool value, {String? status}) {
    _running = value;
    _statusMessage = status;
    notifyListeners();
  }

  void setStatus(String? value) {
    _statusMessage = value;
    notifyListeners();
  }

  WorkspaceSession snapshotSession() {
    return WorkspaceSession(
      savedAt: DateTime.now().toUtc(),
      documents: <WorkspaceDocumentState>[
        for (final document in _documents)
          WorkspaceDocumentState(
            id: document.id,
            title: document.title,
            languageId: document.languageId,
            text: document.text,
            savedText: document.savedText,
            path: document.path,
          ),
      ],
      activeDocumentId: _activeDocumentId,
      section: _section.name,
      bottomPanel: _bottomPanel.name,
      bottomVisible: _bottomVisible,
      inspectorVisible: _inspectorVisible,
      selectedBackendId: _selectedBackendId,
      selectedTargetId: _selectedTargetId,
      noisePresetId: _noisePresetId,
    );
  }

  void restoreSession(WorkspaceSession session) {
    if (session.documents.isEmpty) return;
    _documents
      ..clear()
      ..addAll(session.documents.map((state) => WorkbenchDocument(
            id: state.id,
            title: state.title,
            languageId: state.languageId,
            text: state.text,
            savedText: state.savedText,
            path: state.path,
          )));
    _activeDocumentId = _documents.any((item) => item.id == session.activeDocumentId)
        ? session.activeDocumentId
        : _documents.first.id;
    _section = WorkbenchSection.values.where((item) => item.name == session.section).firstOrNull ??
        WorkbenchSection.explorer;
    _bottomPanel = WorkbenchBottomPanel.values
            .where((item) => item.name == session.bottomPanel)
            .firstOrNull ??
        WorkbenchBottomPanel.terminal;
    _bottomVisible = session.bottomVisible;
    _inspectorVisible = session.inspectorVisible;
    _selectedBackendId = session.selectedBackendId;
    _selectedTargetId = session.selectedTargetId;
    _noisePresetId = session.noisePresetId;
    _diagnostics = const <LanguageDiagnostic>[];
    _statusMessage = 'Workspace recovered from ${session.savedAt.toLocal()}.';
    notifyListeners();
  }

  String _languageForPath(String path) {
    final extension = p.extension(path).toLowerCase();
    return switch (extension) {
      '.py' => 'python',
      '.qasm' => 'openqasm3',
      '.json' => 'json',
      _ => 'plaintext',
    };
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
