import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../application/runtime/runtime_supervisor.dart';
import '../../application/workbench/workbench_controller.dart';
import '../terminal/terminal_panel.dart';

final class KetWorkbench extends StatefulWidget {
  const KetWorkbench({super.key});

  @override
  State<KetWorkbench> createState() => _KetWorkbenchState();
}

final class _KetWorkbenchState extends State<KetWorkbench> {
  late final WorkbenchController _controller;
  late final RuntimeSupervisor _runtime;

  @override
  void initState() {
    super.initState();
    _controller = WorkbenchController();
    _runtime = RuntimeSupervisor();
    unawaited(_runtime.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return NavigationView(
          content: ScaffoldPage(
            padding: EdgeInsets.zero,
            content: ColoredBox(
              color: const Color(0xFF0B0F14),
              child: Column(
                children: <Widget>[
                  _TitleBar(controller: _controller),
                  const Divider(size: 1),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _ActivityBar(controller: _controller),
                        const VerticalDivider(size: 1),
                        SizedBox(
                          width: 238,
                          child: _Sidebar(controller: _controller),
                        ),
                        const VerticalDivider(size: 1),
                        Expanded(
                          child: _CenterWorkspace(
                            controller: _controller,
                            runtime: _runtime,
                          ),
                        ),
                        if (_controller.inspectorVisible) ...<Widget>[
                          const VerticalDivider(size: 1),
                          SizedBox(
                            width: 286,
                            child: _Inspector(runtime: _runtime),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(size: 1),
                  _StatusBar(runtime: _runtime),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_runtime.dispose());
    super.dispose();
  }
}

final class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 12),
          const Icon(FluentIcons.processing, size: 16),
          const SizedBox(width: 9),
          const Text(
            'KET Studio',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 18),
          Button(
            onPressed: () {},
            child: const Text('File', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          Button(
            onPressed: () {},
            child: const Text('Run', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          Button(
            onPressed: () {},
            child: const Text('Quantum', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DragToMoveArea(
              child: Center(
                child: Container(
                  width: 420,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111820),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFF26313D)),
                  ),
                  child: const Text(
                    'KET Studio v0.3  •  Quantum Engineering Workbench',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA9B8)),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.command_prompt, size: 15),
            onPressed: () => controller.showBottomPanel(
              WorkbenchBottomPanel.terminal,
            ),
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
}

final class _ActivityBar extends StatelessWidget {
  const _ActivityBar({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 6),
          _ActivityButton(
            icon: FluentIcons.folder,
            selected: controller.section == WorkbenchSection.explorer,
            onPressed: () => controller.selectSection(WorkbenchSection.explorer),
          ),
          _ActivityButton(
            icon: FluentIcons.search,
            selected: controller.section == WorkbenchSection.search,
            onPressed: () => controller.selectSection(WorkbenchSection.search),
          ),
          _ActivityButton(
            icon: FluentIcons.processing,
            selected: controller.section == WorkbenchSection.quantum,
            onPressed: () => controller.selectSection(WorkbenchSection.quantum),
          ),
          _ActivityButton(
            icon: FluentIcons.history,
            selected: controller.section == WorkbenchSection.experiments,
            onPressed: () => controller.selectSection(WorkbenchSection.experiments),
          ),
          _ActivityButton(
            icon: FluentIcons.plug,
            selected: controller.section == WorkbenchSection.extensions,
            onPressed: () => controller.selectSection(WorkbenchSection.extensions),
          ),
          const Spacer(),
          _ActivityButton(
            icon: FluentIcons.settings,
            selected: false,
            onPressed: () {},
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

final class _ActivityButton extends StatelessWidget {
  const _ActivityButton({
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 48,
      child: Stack(
        children: <Widget>[
          Center(
            child: IconButton(
              icon: Icon(
                icon,
                size: 21,
                color: selected
                    ? const Color(0xFFE6EEF8)
                    : const Color(0xFF7F8A96),
              ),
              onPressed: onPressed,
            ),
          ),
          if (selected)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 28,
                color: const Color(0xFF4EA1FF),
              ),
            ),
        ],
      ),
    );
  }
}

final class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.section) {
      case WorkbenchSection.explorer:
        return _Explorer(controller: controller);
      case WorkbenchSection.search:
        return const _SimpleSidebar(
          title: 'SEARCH',
          message: 'Workspace search will be backed by indexed project symbols.',
        );
      case WorkbenchSection.quantum:
        return const _SimpleSidebar(
          title: 'QUANTUM',
          message: 'Circuits, backends, transpilation and debugger sessions.',
        );
      case WorkbenchSection.experiments:
        return const _SimpleSidebar(
          title: 'EXPERIMENTS',
          message: 'Reproducible runs, parameters, artifacts and remote jobs.',
        );
      case WorkbenchSection.extensions:
        return const _SimpleSidebar(
          title: 'EXTENSIONS',
          message: 'Versioned KET plugins and provider adapters.',
        );
    }
  }
}

final class _Explorer extends StatelessWidget {
  const _Explorer({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SidebarHeader('EXPLORER'),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 7),
          child: Text(
            'KET-QUANTUM-LAB',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        _FileRow(
          name: 'bell_state.py',
          active: controller.activeDocument == 'bell_state.py',
          onTap: () => controller.openDocument('bell_state.py'),
        ),
        _FileRow(
          name: 'grover_search.py',
          active: controller.activeDocument == 'grover_search.py',
          onTap: () => controller.openDocument('grover_search.py'),
        ),
        _FileRow(
          name: 'experiment.ket.json',
          active: controller.activeDocument == 'experiment.ket.json',
          onTap: () => controller.openDocument('experiment.ket.json'),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Text('▾  .ket', style: TextStyle(fontSize: 12)),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 32, top: 5),
          child: Text(
            'workspace.json',
            style: TextStyle(fontSize: 12, color: Color(0xFF8D99A7)),
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
  Widget build(BuildContext context) {
    return SizedBox(
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
}

final class _SimpleSidebar extends StatelessWidget {
  const _SimpleSidebar({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SidebarHeader(title),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF8995A3),
            ),
          ),
        ),
      ],
    );
  }
}

final class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.name,
    required this.active,
    required this.onTap,
  });

  final String name;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        color: active ? const Color(0xFF18212B) : Colors.transparent,
        padding: const EdgeInsets.only(left: 22, right: 8),
        child: Row(
          children: <Widget>[
            const Text(
              '◆',
              style: TextStyle(fontSize: 8, color: Color(0xFF4EA1FF)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CenterWorkspace extends StatelessWidget {
  const _CenterWorkspace({
    required this.controller,
    required this.runtime,
  });

  final WorkbenchController controller;
  final RuntimeSupervisor runtime;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _DocumentTabs(controller: controller),
        const Divider(size: 1),
        const Expanded(child: _EditorSurface()),
        if (controller.bottomVisible) ...<Widget>[
          const Divider(size: 1),
          SizedBox(
            height: 270,
            child: _BottomPanel(
              controller: controller,
              runtime: runtime,
            ),
          ),
        ],
      ],
    );
  }
}

final class _DocumentTabs extends StatelessWidget {
  const _DocumentTabs({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: <Widget>[
          Container(
            width: 178,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF10161E),
              border: Border(
                top: BorderSide(color: Color(0xFF4EA1FF), width: 2),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    controller.activeDocument,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Icon(FluentIcons.chrome_close, size: 10),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              controller.bottomVisible
                  ? FluentIcons.chevron_down
                  : FluentIcons.chevron_up,
              size: 12,
            ),
            onPressed: controller.toggleBottomPanel,
          ),
        ],
      ),
    );
  }
}

final class _EditorSurface extends StatelessWidget {
  const _EditorSurface();

  static const String _code = '''from qiskit import QuantumCircuit\n\nqc = QuantumCircuit(2, 2)\nqc.h(0)\nqc.cx(0, 1)\nqc.measure([0, 1], [0, 1])\n\n# KET Studio v0.3 will bind this circuit to\n# the debugger, transpiler inspector and experiment timeline.\nprint(qc)''';

  @override
  Widget build(BuildContext context) {
    final lines = _code.split('\n');
    return ColoredBox(
      color: const Color(0xFF0D1218),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 48,
            color: const Color(0xFF0B1016),
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10, bottom: 5),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF46515E),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: SelectableText(
                _code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFFD9E2EC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.controller,
    required this.runtime,
  });

  final WorkbenchController controller;
  final RuntimeSupervisor runtime;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 34,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 8),
              _PanelTab(
                label: 'TERMINAL',
                selected: controller.bottomPanel == WorkbenchBottomPanel.terminal,
                onPressed: () => controller.showBottomPanel(
                  WorkbenchBottomPanel.terminal,
                ),
              ),
              _PanelTab(
                label: 'PROBLEMS',
                selected: controller.bottomPanel == WorkbenchBottomPanel.problems,
                onPressed: () => controller.showBottomPanel(
                  WorkbenchBottomPanel.problems,
                ),
              ),
              _PanelTab(
                label: 'OUTPUT',
                selected: controller.bottomPanel == WorkbenchBottomPanel.output,
                onPressed: () => controller.showBottomPanel(
                  WorkbenchBottomPanel.output,
                ),
              ),
              _PanelTab(
                label: 'DEBUG CONSOLE',
                selected: controller.bottomPanel == WorkbenchBottomPanel.debugConsole,
                onPressed: () => controller.showBottomPanel(
                  WorkbenchBottomPanel.debugConsole,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 11),
                onPressed: controller.toggleBottomPanel,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const Divider(size: 1),
        Expanded(child: _bottomContent()),
      ],
    );
  }

  Widget _bottomContent() {
    switch (controller.bottomPanel) {
      case WorkbenchBottomPanel.terminal:
        return TerminalPanel(runtime: runtime);
      case WorkbenchBottomPanel.problems:
        return const _PanelPlaceholder(
          icon: FluentIcons.error,
          title: 'No diagnostics yet',
          subtitle: 'LSP diagnostics will appear here.',
        );
      case WorkbenchBottomPanel.output:
        return const _PanelPlaceholder(
          icon: FluentIcons.info,
          title: 'Structured Output',
          subtitle: 'Kernel, transpiler and provider events will stream here.',
        );
      case WorkbenchBottomPanel.debugConsole:
        return const _PanelPlaceholder(
          icon: FluentIcons.bug,
          title: 'Debug Console',
          subtitle: 'DAP and quantum debugger evaluation will share this surface.',
        );
    }
  }
}

final class _PanelTab extends StatelessWidget {
  const _PanelTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
            color: selected
                ? const Color(0xFFE2EAF3)
                : const Color(0xFF7F8A96),
          ),
        ),
      ),
    );
  }
}

final class _PanelPlaceholder extends StatelessWidget {
  const _PanelPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 24, color: const Color(0xFF536170)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF768392)),
          ),
        ],
      ),
    );
  }
}

final class _Inspector extends StatelessWidget {
  const _Inspector({required this.runtime});

  final RuntimeSupervisor runtime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SidebarHeader('QUANTUM INSPECTOR'),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _InspectorCard(
                title: 'Backend',
                value: 'Local Simulator',
                detail: 'Provider-neutral adapter',
              ),
              const SizedBox(height: 8),
              const _InspectorCard(
                title: 'Circuit',
                value: '2 qubits • 3 ops',
                detail: 'Depth 2 • Bell state',
              ),
              const SizedBox(height: 8),
              const _InspectorCard(
                title: 'Experiment',
                value: '1024 shots',
                detail: 'Reproducibility metadata enabled',
              ),
              const SizedBox(height: 12),
              const Text(
                'RUNTIME',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF778492),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              StreamBuilder<RuntimeSnapshot>(
                stream: runtime.snapshots,
                initialData: runtime.snapshot,
                builder: (context, snapshot) {
                  final value = snapshot.data ?? runtime.snapshot;
                  return Text(
                    value.message,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: Color(0xFFA6B2BF),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _InspectorCard extends StatelessWidget {
  const _InspectorCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        border: Border.all(color: const Color(0xFF222D38)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Color(0xFF788593)),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: const TextStyle(fontSize: 10, color: Color(0xFF75818E)),
          ),
        ],
      ),
    );
  }
}

final class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.runtime});

  final RuntimeSupervisor runtime;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
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
              Text(
                value.health.name,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 18),
              const Text(
                'v0.3-production-rewrite',
                style: TextStyle(fontSize: 10, color: Color(0xFF83909D)),
              ),
              const Spacer(),
              Text(
                '${value.terminalCount} terminal',
                style: const TextStyle(fontSize: 10, color: Color(0xFF83909D)),
              ),
              const SizedBox(width: 16),
              const Text(
                'UTF-8  •  Python  •  Quantum',
                style: TextStyle(fontSize: 10, color: Color(0xFF83909D)),
              ),
              const SizedBox(width: 12),
            ],
          );
        },
      ),
    );
  }
}

void unawaited(Future<void> future) {}
