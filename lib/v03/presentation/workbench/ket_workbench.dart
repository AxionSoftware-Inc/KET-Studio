import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../../application/editor/editor_intelligence_coordinator.dart';
import '../../application/quantum/circuit_document_sync.dart';
import '../../application/quantum/provider_registry.dart';
import '../../application/quantum/quantum_execution_service.dart';
import '../../application/runtime/runtime_supervisor.dart';
import '../../application/workbench_controller.dart';
import '../../application/workspace/workspace_graph_builder.dart';
import '../../core/debug/debug_adapter.dart';
import '../../core/kernel/kernel.dart';
import '../../core/protocol/ket_event.dart';
import '../../core/quantum/circuit_diagram.dart';
import '../../infrastructure/debug/dap_stdio_debug_adapter.dart';
import '../../infrastructure/experiments/file_experiment_store.dart';
import '../../infrastructure/language/pyright_language_service.dart';
import '../../infrastructure/quantum/basic_transpiler_inspector.dart';
import '../../infrastructure/quantum/circuit_layout_engine.dart';
import '../../infrastructure/quantum/local_density_matrix_backend.dart';
import '../../infrastructure/quantum/local_statevector_backend.dart';
import '../../infrastructure/quantum/openqasm3_codec.dart';
import '../editor/code_editor_surface.dart';
import '../quantum/quantum_workspace_surface.dart';
import '../terminal/terminal_panel.dart';

final class KetWorkbench extends StatefulWidget {
  const KetWorkbench({super.key});

  @override
  State<KetWorkbench> createState() => _KetWorkbenchState();
}

final class _KetWorkbenchState extends State<KetWorkbench> {
  late final WorkbenchController _controller;
  late final RuntimeSupervisor _runtime;
  late final EditorIntelligenceCoordinator _intelligence;
  late final LocalStatevectorBackend _statevector;
  late final LocalDensityMatrixBackend _densityMatrix;
  late final QuantumProviderRegistry _providers;
  late final CircuitDocumentSynchronizer _circuitSync;
  late final BasicTranspilerInspector _transpiler;
  late final WorkspaceGraphBuilder _graphBuilder;
  late final QuantumExecutionService _quantum;

  DebugSession? _debugSession;
  StreamSubscription<String>? _debugOutputSub;
  StreamSubscription<DebugStackFrame>? _debugFrameSub;
  StreamSubscription<KetEvent>? _kernelEventSub;
  StreamSubscription<List<ProviderSnapshot>>? _providerSub;
  String? _kernelExecutionId;

  @override
  void initState() {
    super.initState();
    _controller = WorkbenchController();
    _runtime = RuntimeSupervisor();
    _intelligence = EditorIntelligenceCoordinator(
      host: const PyrightLanguageServiceHost(),
    );

    const codec = OpenQasm3CodecImpl();
    const layout = DeterministicCircuitLayoutEngine();
    _statevector = LocalStatevectorBackend(openQasm3Codec: codec);
    _densityMatrix = LocalDensityMatrixBackend(openQasm3Codec: codec);
    _providers = QuantumProviderRegistry()
      ..register(_statevector)
      ..register(_densityMatrix);
    _providerSub = _providers.changes.listen(_controller.setProviders);
    _circuitSync = const CircuitDocumentSynchronizer(
      codec: codec,
      layoutEngine: layout,
    );
    _transpiler = const BasicTranspilerInspector();
    _graphBuilder = const WorkspaceGraphBuilder();
    _quantum = QuantumExecutionService(
      openQasm3Codec: codec,
      backend: _statevector,
      debugger: const LocalQuantumDebugger(),
      experimentStore: FileExperimentStore(
        Directory(p.join(Directory.current.path, '.ket', 'experiments')),
      ),
    );

    unawaited(_runtime.initialize());
    unawaited(_providers.refreshAll().then(_controller.setProviders));
  }

  Future<void> _activateIntelligence() async {
    final document = _controller.activeDocument;
    if (document.languageId != 'python' || document.uri == null) {
      _controller.clearDiagnostics();
      return;
    }
    await _intelligence.activate(
      document,
      onDiagnostics: _controller.setDiagnostics,
    );
    if (!_intelligence.available) {
      _controller.setStatus(_intelligence.unavailableReason);
    }
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['py', 'qasm', 'json', 'txt'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await _controller.openFile(path);
      await _activateIntelligence();
    } catch (error) {
      _controller.setStatus('Open failed: $error');
    }
  }

  Future<void> _save() async {
    try {
      var path = _controller.activeDocument.path;
      if (path == null) {
        path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save ${_controller.activeDocument.title}',
          fileName: _controller.activeDocument.title,
        );
      }
      if (path == null) return;
      await _controller.saveActive(path: path);
      await _activateIntelligence();
    } catch (error) {
      _controller.setStatus('Save failed: $error');
    }
  }

  Future<void> _runActive() async {
    final document = _controller.activeDocument;
    if (_controller.running) return;
    if (document.languageId == 'openqasm3') {
      await _runQuantum();
    } else if (document.languageId == 'python') {
      await _runPython();
    } else {
      _controller.setStatus('No runner is registered for ${document.languageId}.');
    }
  }

  Future<void> _runQuantum() async {
    _controller.setRunning(true, status: 'Running exact local quantum simulation…');
    _controller.showBottomPanel(WorkbenchBottomPanel.output);
    try {
      final source = _controller.activeDocument.text;
      final sync = _circuitSync.parse(source);
      final report = await _quantum.runOpenQasm(
        source: source,
        projectId: Directory.current.absolute.path,
        shots: 1024,
        seed: 7,
      );
      final transpilation = await _transpiler.transpile(
        circuit: sync.circuit,
        backendId: report.job.backendId,
        targetId: report.job.targetId,
      );
      final graph = _graphBuilder.build(
        sourceLabel: _controller.activeDocument.title,
        circuit: sync.circuit,
        backendId: report.job.backendId,
        targetId: report.job.targetId,
        result: report.result,
        experiment: report.record,
        transpilation: transpilation,
      );
      _controller.setQuantumExecution(
        result: report.result,
        debugSnapshot: report.debugSnapshot,
        experiment: report.record,
        circuit: sync.circuit,
        diagram: sync.diagram,
        transpilation: transpilation,
        workspaceGraph: graph,
      );
      _controller.appendOutput(
        '[quantum] ${report.job.backendId}/${report.job.targetId} completed: '
        '${report.result.counts} • compiler ${transpilation.input.operations.length}→'
        '${transpilation.output.operations.length} ops',
      );
      _controller.setRunning(false, status: 'Quantum execution + compiler trace complete.');
    } catch (error) {
      _controller.appendOutput('[quantum error] $error');
      _controller.setRunning(false, status: 'Quantum execution failed.');
    }
  }

  void _applyCircuitEdit(CircuitEdit edit) {
    final document = _controller.activeDocument;
    if (document.languageId != 'openqasm3') {
      _controller.setStatus('Visual circuit edits require an OpenQASM document.');
      return;
    }
    try {
      final updated = _circuitSync.apply(document.text, edit);
      _controller.setCircuitPreview(
        source: updated.source,
        circuit: updated.circuit,
        diagram: updated.diagram,
      );
    } catch (error) {
      _controller.setStatus('Circuit edit rejected: $error');
    }
  }

  Future<void> _ensureKernelEvents(KernelSession kernel) async {
    if (_kernelEventSub != null) return;
    _kernelEventSub = kernel.events.listen((event) {
      final executionId = event.payload['executionId'];
      if (_kernelExecutionId != null && executionId != null && executionId != _kernelExecutionId) {
        return;
      }
      switch (event.kind) {
        case KetEventKind.stdout:
        case KetEventKind.stderr:
          final text = event.payload['text'];
          if (text != null) _controller.appendOutput('$text'.trimRight());
          break;
        case KetEventKind.error:
          _controller.appendOutput('[python error] ${event.payload['message'] ?? event.payload}');
          _controller.setRunning(false, status: 'Python execution failed.');
          break;
        case KetEventKind.lifecycle:
          if (event.payload['state'] == 'idle' && _kernelExecutionId != null) {
            _controller.setRunning(false, status: 'Python execution complete.');
            _kernelExecutionId = null;
          }
          break;
        default:
          break;
      }
    });
  }

  Future<void> _runPython() async {
    _controller.setRunning(true, status: 'Running in persistent Python kernel…');
    _controller.showBottomPanel(WorkbenchBottomPanel.output);
    try {
      final kernel = await _runtime.ensureKernel(
        workingDirectory: _controller.activeDocument.path == null
            ? Directory.current.path
            : File(_controller.activeDocument.path!).parent.path,
      );
      await _ensureKernelEvents(kernel);
      final executionId = 'run-${DateTime.now().microsecondsSinceEpoch}';
      _kernelExecutionId = executionId;
      await kernel.execute(KernelExecutionRequest(
        code: _controller.activeDocument.text,
        executionId: executionId,
        fileName: _controller.activeDocument.path,
      ));
    } catch (error) {
      _kernelExecutionId = null;
      _controller.appendOutput('[kernel error] $error');
      _controller.setRunning(false, status: 'Python kernel failed.');
    }
  }

  Future<void> _debugPython() async {
    if (_controller.activeDocument.languageId != 'python') {
      _controller.setStatus('Python debugger requires a Python document.');
      return;
    }
    _controller.showBottomPanel(WorkbenchBottomPanel.debugConsole);
    _controller.setRunning(true, status: 'Starting debugpy adapter…');
    try {
      await _disposeDebugSession();
      final program = await _controller.materializePythonScratch();
      final paths = _runtime.paths ?? (await _runtime.initialize()).paths;
      if (paths == null) throw StateError('Runtime paths are unavailable.');
      final session = await const DapStdioDebugAdapterHost().launch(
        adapterExecutable: paths.pythonInterpreter,
        adapterArguments: const <String>['-m', 'debugpy.adapter'],
        program: program,
        workingDirectory: File(program).parent.path,
      );
      _debugSession = session;
      _debugOutputSub = session.output.listen(_controller.appendOutput);
      _debugFrameSub = session.stoppedFrames.listen((frame) {
        _controller.setDebugFrames(<DebugStackFrame>[frame]);
        _controller.setRunning(false, status: 'Debugger stopped at line ${frame.line}.');
      });
      _controller.setStatus('debugpy session started.');
    } catch (error) {
      _controller.appendOutput('[debugger error] $error');
      _controller.setRunning(false, status: 'debugpy unavailable or failed.');
    }
  }

  Future<void> _stepQuantum({required bool forward}) async {
    try {
      final snapshot = forward
          ? await _quantum.stepForward()
          : await _quantum.stepBackward();
      _controller.setQuantumDebugSnapshot(snapshot);
    } catch (error) {
      _controller.setStatus('Quantum debugger: $error');
    }
  }

  Future<void> _disposeDebugSession() async {
    await _debugOutputSub?.cancel();
    await _debugFrameSub?.cancel();
    _debugOutputSub = null;
    _debugFrameSub = null;
    final session = _debugSession;
    _debugSession = null;
    if (session != null) await session.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => NavigationView(
        content: ScaffoldPage(
          padding: EdgeInsets.zero,
          content: ColoredBox(
            color: const Color(0xFF0B0F14),
            child: Column(
              children: <Widget>[
                _TitleBar(
                  controller: _controller,
                  onOpen: _openFile,
                  onSave: _save,
                  onRun: _runActive,
                  onDebugPython: _debugPython,
                ),
                const Divider(size: 1),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _ActivityBar(controller: _controller),
                      const VerticalDivider(size: 1),
                      SizedBox(width: 238, child: _Sidebar(controller: _controller)),
                      const VerticalDivider(size: 1),
                      Expanded(
                        child: _CenterWorkspace(
                          controller: _controller,
                          runtime: _runtime,
                          onChanged: (value) {
                            _controller.updateActiveText(value);
                            _intelligence.scheduleChange(_controller.activeDocument);
                          },
                          onCircuitEdit: _applyCircuitEdit,
                        ),
                      ),
                      if (_controller.inspectorVisible) ...<Widget>[
                        const VerticalDivider(size: 1),
                        SizedBox(
                          width: 300,
                          child: _Inspector(
                            controller: _controller,
                            runtime: _runtime,
                            onStepBack: () => _stepQuantum(forward: false),
                            onStepForward: () => _stepQuantum(forward: true),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(size: 1),
                _StatusBar(controller: _controller, runtime: _runtime),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_kernelEventSub?.cancel() ?? Future<void>.value());
    unawaited(_providerSub?.cancel() ?? Future<void>.value());
    unawaited(_disposeDebugSession());
    unawaited(_intelligence.dispose());
    unawaited(_quantum.dispose());
    unawaited(_providers.dispose());
    unawaited(_runtime.dispose());
    _controller.dispose();
    super.dispose();
  }
}

final class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.controller,
    required this.onOpen,
    required this.onSave,
    required this.onRun,
    required this.onDebugPython,
  });

  final WorkbenchController controller;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onRun;
  final VoidCallback onDebugPython;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 12),
            const Icon(FluentIcons.processing, size: 16),
            const SizedBox(width: 8),
            const Text('KET Studio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 14),
            Button(onPressed: onOpen, child: const Text('Open')),
            const SizedBox(width: 4),
            Button(onPressed: onSave, child: const Text('Save')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: controller.running ? null : onRun,
              child: Text(controller.running ? 'Running…' : 'Run'),
            ),
            const SizedBox(width: 4),
            Button(onPressed: onDebugPython, child: const Text('Debug Python')),
            const SizedBox(width: 12),
            Expanded(
              child: DragToMoveArea(
                child: Center(
                  child: Text(
                    '${controller.activeDocument.title}${controller.activeDocument.isDirty ? ' •' : ''}  —  v0.3',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8D99A7)),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.command_prompt, size: 15),
              onPressed: () => controller.showBottomPanel(WorkbenchBottomPanel.terminal),
            ),
            IconButton(
              icon: const Icon(FluentIcons.side_panel, size: 15),
              onPressed: controller.toggleInspector,
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
}

final class _ActivityBar extends StatelessWidget {
  const _ActivityBar({required this.controller});
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 6),
            for (final item in <(WorkbenchSection, IconData)>[
              (WorkbenchSection.explorer, FluentIcons.folder),
              (WorkbenchSection.search, FluentIcons.search),
              (WorkbenchSection.quantum, FluentIcons.processing),
              (WorkbenchSection.experiments, FluentIcons.history),
              (WorkbenchSection.extensions, FluentIcons.plug),
            ])
              _ActivityButton(
                icon: item.$2,
                selected: controller.section == item.$1,
                onPressed: () => controller.selectSection(item.$1),
              ),
            const Spacer(),
            _ActivityButton(icon: FluentIcons.settings, selected: false, onPressed: () {}),
            const SizedBox(height: 6),
          ],
        ),
      );
}

final class _ActivityButton extends StatelessWidget {
  const _ActivityButton({required this.icon, required this.selected, required this.onPressed});
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        height: 48,
        child: Stack(
          children: <Widget>[
            Center(
              child: IconButton(
                icon: Icon(
                  icon,
                  size: 21,
                  color: selected ? const Color(0xFFE6EEF8) : const Color(0xFF7F8A96),
                ),
                onPressed: onPressed,
              ),
            ),
            if (selected)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 2, height: 28, color: const Color(0xFF4EA1FF)),
              ),
          ],
        ),
      );
}

final class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.controller});
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.section == WorkbenchSection.explorer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SidebarHeader('EXPLORER'),
          for (final document in controller.documents)
            GestureDetector(
              onTap: () => controller.activateDocument(document.id),
              child: Container(
                height: 30,
                color: document.id == controller.activeDocument.id
                    ? const Color(0xFF18212B)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: Text(
                  '${document.isDirty ? '● ' : ''}${document.title}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      );
    }
    final content = switch (controller.section) {
      WorkbenchSection.search => 'Project search is ready to bind LSP workspace symbols.',
      WorkbenchSection.quantum => controller.quantumCircuit == null
          ? 'Run an OpenQASM 3 document to build circuit, compiler and debugger state.'
          : '${controller.quantumCircuit!.qubitCount} qubits • '
            '${controller.circuitDiagram?.depth ?? 0} depth • '
            '${controller.transpilationTrace?.stages.length ?? 0} compiler passes',
      WorkbenchSection.experiments => controller.lastExperiment == null
          ? 'No reproducible experiment has been persisted yet.'
          : '${controller.lastExperiment!.id}\n'
            '${controller.workspaceGraph?.nodes.length ?? 0} graph nodes',
      WorkbenchSection.extensions => controller.providers.isEmpty
          ? 'No providers registered.'
          : controller.providers
              .map((provider) => '${provider.displayName}: ${provider.health.name}')
              .join('\n'),
      WorkbenchSection.explorer => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SidebarHeader(controller.section.name.toUpperCase()),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            content,
            style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF8995A3)),
          ),
        ),
      ],
    );
  }
}

final class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFAAB5C2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
}

final class _CenterWorkspace extends StatelessWidget {
  const _CenterWorkspace({
    required this.controller,
    required this.runtime,
    required this.onChanged,
    required this.onCircuitEdit,
  });

  final WorkbenchController controller;
  final RuntimeSupervisor runtime;
  final ValueChanged<String> onChanged;
  final ValueChanged<CircuitEdit> onCircuitEdit;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          SizedBox(
            height: 36,
            child: Row(
              children: <Widget>[
                for (final document in controller.documents)
                  GestureDetector(
                    onTap: () {
                      controller.activateDocument(document.id);
                      controller.selectSection(WorkbenchSection.explorer);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 120, maxWidth: 190),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: document.id == controller.activeDocument.id
                            ? const Color(0xFF10161E)
                            : const Color(0xFF0C1117),
                        border: Border(
                          top: BorderSide(
                            color: document.id == controller.activeDocument.id
                                ? const Color(0xFF4EA1FF)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        '${document.title}${document.isDirty ? ' •' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                const Spacer(),
                if (controller.quantumCircuit != null)
                  Button(
                    onPressed: () => controller.selectSection(
                      controller.section == WorkbenchSection.quantum
                          ? WorkbenchSection.explorer
                          : WorkbenchSection.quantum,
                    ),
                    child: Text(
                      controller.section == WorkbenchSection.quantum ? 'Code' : 'Circuit',
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    controller.bottomVisible ? FluentIcons.chevron_down : FluentIcons.chevron_up,
                    size: 12,
                  ),
                  onPressed: controller.toggleBottomPanel,
                ),
              ],
            ),
          ),
          const Divider(size: 1),
          Expanded(
            child: controller.section == WorkbenchSection.quantum &&
                    controller.circuitDiagram != null
                ? QuantumWorkspaceSurface(
                    controller: controller,
                    onEdit: onCircuitEdit,
                  )
                : CodeEditorSurface(
                    key: ValueKey<String>(controller.activeDocument.id),
                    document: controller.activeDocument,
                    onChanged: onChanged,
                  ),
          ),
          if (controller.bottomVisible) ...<Widget>[
            const Divider(size: 1),
            SizedBox(
              height: 270,
              child: _BottomPanel(controller: controller, runtime: runtime),
            ),
          ],
        ],
      );
}

final class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.controller, required this.runtime});
  final WorkbenchController controller;
  final RuntimeSupervisor runtime;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          SizedBox(
            height: 34,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 8),
                for (final panel in WorkbenchBottomPanel.values)
                  _PanelTab(
                    label: switch (panel) {
                      WorkbenchBottomPanel.terminal => 'TERMINAL',
                      WorkbenchBottomPanel.problems => 'PROBLEMS (${controller.diagnostics.length})',
                      WorkbenchBottomPanel.output => 'OUTPUT',
                      WorkbenchBottomPanel.debugConsole => 'DEBUG CONSOLE',
                    },
                    selected: controller.bottomPanel == panel,
                    onPressed: () => controller.showBottomPanel(panel),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 11),
                  onPressed: controller.toggleBottomPanel,
                ),
              ],
            ),
          ),
          const Divider(size: 1),
          Expanded(child: _content()),
        ],
      );

  Widget _content() => switch (controller.bottomPanel) {
        WorkbenchBottomPanel.terminal => TerminalPanel(runtime: runtime),
        WorkbenchBottomPanel.problems => ListView.builder(
            itemCount: controller.diagnostics.length,
            itemBuilder: (context, index) {
              final diagnostic = controller.diagnostics[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  '${diagnostic.severity.name.toUpperCase()}  '
                  '${diagnostic.range.start.line + 1}:${diagnostic.range.start.character + 1}  '
                  '${diagnostic.message}',
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
        WorkbenchBottomPanel.output => ListView(
            padding: const EdgeInsets.all(10),
            children: <Widget>[
              for (final line in controller.output)
                SelectableText(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.35),
                ),
            ],
          ),
        WorkbenchBottomPanel.debugConsole => ListView(
            padding: const EdgeInsets.all(10),
            children: <Widget>[
              if (controller.debugFrames.isEmpty)
                const Text(
                  'No active Python stop frame.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7F8A96)),
                )
              else
                for (final frame in controller.debugFrames)
                  Text(
                    '${frame.name} — ${frame.sourcePath ?? ''}:${frame.line}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
              const SizedBox(height: 10),
              for (final line in controller.output.reversed.take(40).toList().reversed)
                SelectableText(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
            ],
          ),
      };
}

final class _PanelTab extends StatelessWidget {
  const _PanelTab({required this.label, required this.selected, required this.onPressed});
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFF4EA1FF) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: selected ? const Color(0xFFE2EAF3) : const Color(0xFF7F8A96),
            ),
          ),
        ),
      );
}

final class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.controller,
    required this.runtime,
    required this.onStepBack,
    required this.onStepForward,
  });

  final WorkbenchController controller;
  final RuntimeSupervisor runtime;
  final VoidCallback onStepBack;
  final VoidCallback onStepForward;

  @override
  Widget build(BuildContext context) {
    final result = controller.quantumResult;
    final debug = controller.quantumDebugSnapshot;
    final readyProviders = controller.providers
        .where((provider) => provider.health == ProviderHealth.ready)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SidebarHeader('QUANTUM INSPECTOR'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              _InspectorCard(
                title: 'Providers',
                value: '$readyProviders/${controller.providers.length} ready',
                detail: controller.providers.isEmpty
                    ? 'Registry initializing'
                    : controller.providers.map((item) => item.displayName).join(' • '),
              ),
              const SizedBox(height: 8),
              _InspectorCard(
                title: 'Circuit / Compiler',
                value: controller.quantumCircuit == null
                    ? 'Not compiled'
                    : '${controller.quantumCircuit!.qubitCount} qubits • depth ${controller.circuitDiagram?.depth ?? 0}',
                detail: controller.transpilationTrace == null
                    ? 'Run to create compiler trace'
                    : '${controller.transpilationTrace!.stages.length} passes • '
                      '${controller.transpilationTrace!.input.operations.length}→'
                      '${controller.transpilationTrace!.output.operations.length} ops',
              ),
              const SizedBox(height: 8),
              _InspectorCard(
                title: 'Result',
                value: result == null
                    ? 'Not executed'
                    : '${result.counts.values.fold<int>(0, (a, b) => a + b)} shots',
                detail: result == null ? 'Run an OpenQASM document' : '${result.counts}',
              ),
              const SizedBox(height: 8),
              _InspectorCard(
                title: 'Debugger',
                value: debug == null ? 'No session' : 'Operation ${debug.operationIndex}',
                detail: debug == null
                    ? 'State snapshots appear after execution'
                    : 'P=${debug.probabilities} • entanglement='
                      '${debug.entanglement.isEmpty ? 0 : debug.entanglement.first.strength.toStringAsFixed(3)}',
              ),
              if (debug != null) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(child: Button(onPressed: onStepBack, child: const Text('← Step'))),
                    const SizedBox(width: 6),
                    Expanded(child: Button(onPressed: onStepForward, child: const Text('Step →'))),
                  ],
                ),
                const SizedBox(height: 10),
                for (final qubit in debug.qubits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'q${qubit.index}: Bloch '
                      '(${qubit.blochX.toStringAsFixed(3)}, '
                      '${qubit.blochY.toStringAsFixed(3)}, '
                      '${qubit.blochZ.toStringAsFixed(3)}) • '
                      'purity ${qubit.purity.toStringAsFixed(3)}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF8D99A7)),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              StreamBuilder<RuntimeSnapshot>(
                stream: runtime.snapshots,
                initialData: runtime.snapshot,
                builder: (context, snapshot) => Text(
                  (snapshot.data ?? runtime.snapshot).message,
                  style: const TextStyle(fontSize: 10, height: 1.4, color: Color(0xFF8D99A7)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _InspectorCard extends StatelessWidget {
  const _InspectorCard({required this.title, required this.value, required this.detail});
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF111820),
          border: Border.all(color: const Color(0xFF222D38)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF788593))),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(fontSize: 10, color: Color(0xFF75818E))),
          ],
        ),
      );
}

final class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, required this.runtime});
  final WorkbenchController controller;
  final RuntimeSupervisor runtime;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 25,
        child: StreamBuilder<RuntimeSnapshot>(
          stream: runtime.snapshots,
          initialData: runtime.snapshot,
          builder: (context, snapshot) {
            final value = snapshot.data ?? runtime.snapshot;
            final color = switch (value.health) {
              RuntimeHealth.ready => const Color(0xFF45C486),
              RuntimeHealth.degraded => const Color(0xFFE6A23C),
              RuntimeHealth.failed => const Color(0xFFE05A5A),
              _ => const Color(0xFF73808D),
            };
            return Row(
              children: <Widget>[
                const SizedBox(width: 10),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(value.health.name, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    controller.statusMessage ?? value.message,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF83909D)),
                  ),
                ),
                Text(
                  controller.activeDocument.languageId,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF83909D)),
                ),
                const SizedBox(width: 10),
                Text(
                  '${controller.providers.where((p) => p.health == ProviderHealth.ready).length} providers',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF83909D)),
                ),
                const SizedBox(width: 10),
                Text(
                  '${value.terminalCount} terminal',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF83909D)),
                ),
                const SizedBox(width: 12),
              ],
            );
          },
        ),
      );
}

void unawaited(Future<void> future) {}
