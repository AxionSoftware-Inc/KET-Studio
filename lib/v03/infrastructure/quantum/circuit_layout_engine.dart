import '../../core/quantum/circuit_diagram.dart';
import '../../core/quantum/ket_ir.dart';

final class DeterministicCircuitLayoutEngine implements CircuitLayoutEngine {
  const DeterministicCircuitLayoutEngine();

  @override
  CircuitDiagram layout(KetCircuit circuit) {
    final lastColumn = List<int>.filled(circuit.qubitCount, -1);
    final columns = <int, List<CircuitNode>>{};
    for (var i = 0; i < circuit.operations.length; i++) {
      final operation = circuit.operations[i];
      final touched = _touched(operation);
      var column = 0;
      for (final qubit in touched) {
        final candidate = lastColumn[qubit] + 1;
        if (candidate > column) column = candidate;
      }
      for (final qubit in touched) {
        lastColumn[qubit] = column;
      }
      columns.putIfAbsent(column, () => <CircuitNode>[]).add(
            _node(operation, i, column),
          );
    }
    final ordered = columns.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return CircuitDiagram(
      qubitCount: circuit.qubitCount,
      columns: <CircuitColumn>[
        for (final entry in ordered)
          CircuitColumn(index: entry.key, nodes: List<CircuitNode>.unmodifiable(entry.value)),
      ],
      depth: ordered.isEmpty ? 0 : ordered.last.key + 1,
    );
  }

  List<int> _touched(KetOperation operation) => switch (operation) {
        KetGate() => (<int>{...operation.controls, ...operation.qubits}.toList()..sort()),
        KetMeasure() => <int>[operation.qubit],
        KetBarrier() => operation.qubits,
      };

  CircuitNode _node(KetOperation operation, int index, int column) => switch (operation) {
        KetGate() => CircuitNode(
            operationIndex: index,
            column: column,
            kind: CircuitNodeKind.gate,
            label: operation.controls.isEmpty
                ? operation.name.toUpperCase()
                : '${List<String>.filled(operation.controls.length, 'C').join()}${operation.name.toUpperCase()}',
            qubits: operation.qubits,
            controls: operation.controls,
            parameters: operation.parameters.map(_parameter).toList(growable: false),
          ),
        KetMeasure() => CircuitNode(
            operationIndex: index,
            column: column,
            kind: CircuitNodeKind.measurement,
            label: 'M→c${operation.classicalBit}',
            qubits: <int>[operation.qubit],
          ),
        KetBarrier() => CircuitNode(
            operationIndex: index,
            column: column,
            kind: CircuitNodeKind.barrier,
            label: '│',
            qubits: operation.qubits,
          ),
      };

  String _parameter(KetParameter parameter) => switch (parameter) {
        KetLiteralParameter() => parameter.value.toStringAsPrecision(5),
        KetSymbolParameter() => parameter.name,
      };
}
