import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/application/workbench/workbench_controller.dart';

void main() {
  test('workbench controller exposes deterministic desktop defaults', () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);

    expect(controller.section, WorkbenchSection.explorer);
    expect(controller.bottomPanel, WorkbenchBottomPanel.terminal);
    expect(controller.bottomVisible, isTrue);
    expect(controller.inspectorVisible, isTrue);
    expect(controller.activeDocument, 'bell_state.py');
  });

  test('bottom panel selection makes the panel visible', () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);

    controller.toggleBottomPanel();
    expect(controller.bottomVisible, isFalse);

    controller.showBottomPanel(WorkbenchBottomPanel.debugConsole);
    expect(controller.bottomVisible, isTrue);
    expect(controller.bottomPanel, WorkbenchBottomPanel.debugConsole);
  });

  test('navigation and document state can change independently', () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);

    controller.selectSection(WorkbenchSection.quantum);
    controller.openDocument('grover_search.py');

    expect(controller.section, WorkbenchSection.quantum);
    expect(controller.activeDocument, 'grover_search.py');
  });
}
