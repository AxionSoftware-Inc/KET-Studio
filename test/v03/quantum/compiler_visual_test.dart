import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/application/quantum/circuit_document_sync.dart';
import 'package:ket_studio/v03/core/quantum/circuit_diagram.dart';
import 'package:ket_studio/v03/core/quantum/ket_ir.dart';
import 'package:ket_studio/v03/infrastructure/quantum/basic_transpiler_inspector.dart';
import 'package:ket_studio/v03/infrastructure/quantum/circuit_layout_engine.dart';
import 'package:ket_studio/v03/infrastructure/quantum/openqasm3_codec.dart';

void main() {
  const codec = OpenQasm3CodecImpl();
  const layout = DeterministicCircuitLayoutEngine();
  const sync = CircuitDocumentSynchronizer(codec: codec, layoutEngine: layout);
  const transpiler = BasicTranspilerInspector();

  test('Bell circuit gets deterministic parallel-safe layout', () {
    final snapshot = sync.parse('''
OPENQASM 3.0;
qubit[2] q;
h q[0];
x q[1];
cx q[0], q[1];
''');
    expect(snapshot.diagram.qubitCount, 2);
    expect(snapshot.diagram.depth, 2);
    expect(snapshot.diagram.columns.first.nodes.length, 2);
  });

  test('visual edit rewrites canonical OpenQASM and round-trips', () {
    final updated = sync.apply(
      '''
OPENQASM 3.0;
qubit[1] q;
h q[0];
''',
      const ReplaceCircuitGate(
        operationIndex: 0,
        name: 'x',
        qubits: <int>[0],
      ),
    );
    expect(updated.source, contains('x q[0];'));
    expect((updated.circuit.operations.single as KetGate).name, 'x');
  });

  test('compiler trace removes adjacent self-inverse gates', () async {
    final circuit = codec.decode('''
OPENQASM 3.0;
qubit[1] q;
h q[0];
h q[0];
x q[0];
''');
    final trace = await transpiler.transpile(
      circuit: circuit,
      backendId: 'local',
      targetId: 'sim',
    );
    expect(trace.stages.length, 3);
    expect(trace.output.operations.length, 1);
    expect((trace.output.operations.single as KetGate).name, 'x');
  });
}
