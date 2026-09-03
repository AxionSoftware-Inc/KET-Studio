import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/experiments/experiment_lab.dart';
import '../../core/quantum/circuit_diagram.dart';
import '../../core/quantum/noise_model.dart';
import '../../core/quantum/quantum_backend.dart';
import '../../infrastructure/experiments/file_experiment_lab.dart';
import '../../infrastructure/experiments/file_experiment_store.dart';
import '../../infrastructure/quantum/basic_transpiler_inspector.dart';
import '../../infrastructure/quantum/builtin_noise_presets.dart';
import '../../infrastructure/quantum/circuit_layout_engine.dart';
import '../../infrastructure/quantum/file_remote_job_store.dart';
import '../../infrastructure/quantum/local_density_matrix_backend.dart';
import '../../infrastructure/quantum/local_statevector_backend.dart';
import '../../infrastructure/quantum/openqasm3_codec.dart';
import '../../infrastructure/quantum/python_provider_bridge_client.dart';
import '../../infrastructure/quantum/python_vendor_backend.dart';
import '../../infrastructure/workspace/file_workspace_session_store.dart';
import '../quantum/circuit_document_sync.dart';
import '../quantum/provider_registry.dart';
import '../quantum/quantum_execution_service.dart';
import '../quantum/remote_job_coordinator.dart';
import '../runtime/runtime_supervisor.dart';
import '../search/project_search_service.dart';
import '../workspace/workspace_graph_builder.dart';
import '../workspace/workspace_recovery_coordinator.dart';
import '../workbench_controller.dart';

final class WorkbenchProductCoordinator {
  WorkbenchProductCoordinator({
    required this.controller,
    required this.runtime,
  }) {
    const codec = OpenQasm3CodecImpl();
    const layout = DeterministicCircuitLayoutEngine();
    _statevector = LocalStatevectorBackend(openQasm3Codec: codec);
    _densityMatrix = LocalDensityMatrixBackend(openQasm3Codec: codec);
    _providers = QuantumProviderRegistry()
      ..register(_statevector)
      ..register(_densityMatrix);
    _providerSub = _providers.changes.listen(controller.setProviders);
    _circuitSync = const CircuitDocumentSynchronizer(
      codec: codec,
      layoutEngine: layout,
    );
    _transpiler = const BasicTranspilerInspector();
    _graphBuilder = const WorkspaceGraphBuilder();
    _experimentStore = FileExperimentStore(
      Directory(p.join(Directory.current.path, '.ket', 'experiments')),
    );
    _experimentLab = FileExperimentLab(_experimentStore);
    _quantum = QuantumExecutionService(
      openQasm3Codec: codec,
      backend: _statevector,
      debugger: const LocalQuantumDebugger(),
      experimentStore: _experimentStore,
    );
    _remoteJobs = RemoteJobCoordinator(
      registry: _providers,
      store: FileRemoteJobStore(
        Directory(p.join(Directory.current.path, '.ket', 'remote-jobs')),
      ),
    );
    _recovery = WorkspaceRecoveryCoordinator(
      controller: controller,
      store: FileWorkspaceSessionStore(
        Directory(p.join(Directory.current.path, '.ket', 'session')),
      ),
    );
  }

  final WorkbenchController controller;
  final RuntimeSupervisor runtime;

  late final LocalStatevectorBackend _statevector;
  late final LocalDensityMatrixBackend _densityMatrix;
  late final QuantumProviderRegistry _providers;
  late final CircuitDocumentSynchronizer _circuitSync;
  late final BasicTranspilerInspector _transpiler;
  late final WorkspaceGraphBuilder _graphBuilder;
  late final FileExperimentStore _experimentStore;
  late final FileExperimentLab _experimentLab;
  late final QuantumExecutionService _quantum;
  late final RemoteJobCoordinator _remoteJobs;
  late final WorkspaceRecoveryCoordinator _recovery;
  StreamSubscription<List<ProviderSnapshot>>? _providerSub;
  PythonProviderBridgeClient? _providerBridge;
  List<NoisePreset> _noisePresets = const <NoisePreset>[];
  bool _disposed = false;

  List<NoisePreset> get noisePresets => List<NoisePreset>.unmodifiable(_noisePresets);
  QuantumProviderRegistry get providers => _providers;
  QuantumExecutionService get quantum => _quantum;

  Future<void> initialize() async {
    await _recovery.initialize();
    final runtimeSnapshot = await runtime.initialize();
    final paths = runtimeSnapshot.paths ?? runtime.paths;
    final bridgeScript = paths?.providerBridgeScript;
    if (paths != null && bridgeScript != null) {
      final bridge = PythonProviderBridgeClient(
        pythonExecutable: paths.pythonInterpreter,
        bridgeScript: bridgeScript,
        workingDirectory: Directory.current.path,
      );
      _providerBridge = bridge;
      for (final vendor in const <String>['qiskit', 'pennylane', 'cirq']) {
        _providers.register(PythonVendorBackend(vendor: vendor, client: bridge));
      }
    }
    _noisePresets = await const BuiltinNoisePresetRepository().list();
    controller.setProviders(await _providers.refreshAll());
    await refreshExperiments();
    _remoteJobs.start();
  }

  Future<void> runQuantum() async {
    final document = controller.activeDocument;
    if (document.languageId != 'openqasm3') {
      throw StateError('Quantum execution requires an OpenQASM 3 document.');
    }
    controller.setRunning(true, status: 'Running ${controller.selectedBackendId}…');
    controller.showBottomPanel(WorkbenchBottomPanel.output);
    try {
      final source = document.text;
      final sync = _circuitSync.parse(source);
      final backend = _providers.backend(controller.selectedBackendId);
      final options = <String, Object?>{};
      if (backend.id == _densityMatrix.id) {
        final preset = _noisePresets.where((item) => item.id == controller.noisePresetId).firstOrNull;
        if (preset != null) options['noise'] = preset.model;
      }
      final report = await _quantum.runOpenQasm(
        source: source,
        projectId: Directory.current.absolute.path,
        backend: backend,
        targetId: controller.selectedTargetId,
        shots: 1024,
        seed: 7,
        options: options,
      );
      final transpilation = await _transpiler.transpile(
        circuit: sync.circuit,
        backendId: report.job.backendId,
        targetId: report.job.targetId,
      );
      final graph = _graphBuilder.build(
        sourceLabel: document.title,
        circuit: sync.circuit,
        backendId: report.job.backendId,
        targetId: report.job.targetId,
        result: report.result,
        experiment: report.record,
        transpilation: transpilation,
      );
      controller.setQuantumExecution(
        result: report.result,
        debugSnapshot: report.debugSnapshot,
        experiment: report.record,
        circuit: sync.circuit,
        diagram: sync.diagram,
        transpilation: transpilation,
        workspaceGraph: graph,
      );
      controller.appendOutput(
        '[quantum] ${report.job.backendId}/${report.job.targetId} completed: '
        '${report.result.counts} • compiler ${transpilation.input.operations.length}→'
        '${transpilation.output.operations.length} ops',
      );
      controller.setRunning(false, status: 'Quantum execution + experiment persisted.');
      await refreshExperiments();
    } catch (error) {
      controller.appendOutput('[quantum error] $error');
      controller.setRunning(false, status: 'Quantum execution failed.');
      rethrow;
    }
  }

  void applyCircuitEdit(CircuitEdit edit) {
    final document = controller.activeDocument;
    if (document.languageId != 'openqasm3') {
      throw StateError('Visual circuit edits require an OpenQASM document.');
    }
    final updated = _circuitSync.apply(document.text, edit);
    controller.setCircuitPreview(
      source: updated.source,
      circuit: updated.circuit,
      diagram: updated.diagram,
    );
  }

  Future<void> refreshExperiments() async {
    final records = await _experimentLab.list(Directory.current.absolute.path);
    controller.setExperimentHistory(records);
  }

  Future<void> compareExperiments(String leftId, String rightId) async {
    controller.setExperimentComparison(await _experimentLab.compare(leftId, rightId));
  }

  Future<void> searchProject(String query) async {
    final results = await const ProjectSearchService().search(
      rootPath: Directory.current.absolute.path,
      query: query,
    );
    controller.setSearchResults(query, results);
  }

  Future<void> refreshProviders() async {
    controller.setProviders(await _providers.refreshAll());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _remoteJobs.dispose();
    await _recovery.dispose();
    await _providerSub?.cancel();
    await _quantum.dispose();
    await _providerBridge?.dispose();
    await _providers.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
