import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/application/workbench_controller.dart';

void main() {
  test('workbench boots with editable OpenQASM and Python documents', () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);

    expect(controller.section, WorkbenchSection.explorer);
    expect(controller.bottomPanel, WorkbenchBottomPanel.terminal);
    expect(controller.bottomVisible, isTrue);
    expect(controller.inspectorVisible, isTrue);
    expect(controller.documents.map((item) => item.title), containsAll(<String>['bell.qasm', 'scratch.py']));
    expect(controller.activeDocument.languageId, 'openqasm3');
  });

  test('document dirty state and versions are deterministic', () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);

    final original = controller.activeDocument.text;
    final version = controller.activeDocument.version;
    controller.updateActiveText('$original\n// changed');

    expect(controller.activeDocument.isDirty, isTrue);
    expect(controller.activeDocument.version, version + 1);
  });

  test('navigation and active document state change independently', () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);

    controller.selectSection(WorkbenchSection.quantum);
    controller.activateDocument('scratch.py');

    expect(controller.section, WorkbenchSection.quantum);
    expect(controller.activeDocument.title, 'scratch.py');
    expect(controller.activeDocument.languageId, 'python');
  });

  test('quantum execution status can expose busy state without changing documents', () {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);
    final active = controller.activeDocument.id;

    controller.setRunning(true, status: 'running');

    expect(controller.running, isTrue);
    expect(controller.statusMessage, 'running');
    expect(controller.activeDocument.id, active);
  });
}
