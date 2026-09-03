import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/application/workbench/command_registry.dart';

void main() {
  test('command registry ranks direct and fuzzy matches and invokes handlers', () async {
    final registry = CommandRegistry();
    var invoked = false;
    registry.register(
      const CommandDescriptor(
        id: 'file.open',
        title: 'Open File',
        category: 'File',
        keybinding: 'Ctrl+O',
        keywords: <String>['browse'],
      ),
      () => invoked = true,
    );
    registry.register(
      const CommandDescriptor(
        id: 'quantum.providers.refresh',
        title: 'Refresh Quantum Providers',
        category: 'Quantum',
        keywords: <String>['qiskit', 'cirq'],
      ),
      () {},
    );

    expect(registry.search('open').first.id, 'file.open');
    expect(registry.search('qprov').first.id, 'quantum.providers.refresh');
    await registry.invoke('file.open');
    expect(invoked, isTrue);
  });
}
