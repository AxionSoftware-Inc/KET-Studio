import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/core/quantum/ket_ir.dart';
import 'package:ket_studio/v03/infrastructure/quantum/openqasm3_codec.dart';

void main() {
  const codec = OpenQasm3CodecImpl();

  test('decodes Bell circuit into canonical controlled gate', () {
    final circuit = codec.decode('''
OPENQASM 3.0;
include "stdgates.inc";
qubit[2] q;
bit[2] c;
h q[0];
cx q[0], q[1];
measure q -> c;
''');

    expect(circuit.qubitCount, 2);
    expect(circuit.classicalBitCount, 2);
    expect(circuit.operations.length, 4);
    final controlled = circuit.operations[1] as KetGate;
    expect(controlled.name, 'x');
    expect(controlled.controls, <int>[0]);
    expect(controlled.qubits, <int>[1]);
  });

  test('rejects gate after measurement', () {
    expect(
      () => codec.decode('''
OPENQASM 3.0;
qubit[1] q;
bit[1] c;
measure q[0] -> c[0];
x q[0];
'''),
      throwsA(isA<OpenQasm3ParseException>()),
    );
  });

  test('round trips supported canonical OpenQASM', () {
    final first = codec.decode('''
OPENQASM 3.0;
include "stdgates.inc";
qubit[2] q;
bit[2] c;
ry(pi/2) q[0];
cz q[0], q[1];
measure q -> c;
''');
    final second = codec.decode(codec.encode(first));
    expect(second.qubitCount, first.qubitCount);
    expect(second.operations.length, first.operations.length);
  });
}
