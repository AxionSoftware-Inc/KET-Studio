import '../../core/quantum/circuit_diagram.dart';
import '../../core/quantum/ket_ir.dart';

final class CircuitSyncSnapshot {
  const CircuitSyncSnapshot({
    required this.source,
    required this.circuit,
    required this.diagram,
  });

  final String source;
  final KetCircuit circuit;
  final CircuitDiagram diagram;
}

final class CircuitDocumentSynchronizer {
  const CircuitDocumentSynchronizer({
    required OpenQasm3Codec codec,
    required CircuitLayoutEngine layoutEngine,
  })  : _codec = codec,
        _layoutEngine = layoutEngine;

  final OpenQasm3Codec _codec;
  final CircuitLayoutEngine _layoutEngine;

  CircuitSyncSnapshot parse(String source) {
    final circuit = _codec.decode(source);
    return CircuitSyncSnapshot(
      source: source,
      circuit: circuit,
      diagram: _layoutEngine.layout(circuit),
    );
  }

  CircuitSyncSnapshot apply(String source, CircuitEdit edit) {
    final circuit = _codec.decode(source);
    final operations = List<KetOperation>.of(circuit.operations);
    switch (edit) {
      case RemoveCircuitOperation():
        _checkIndex(edit.operationIndex, operations.length, allowEnd: false);
        operations.removeAt(edit.operationIndex);
      case ReplaceCircuitGate():
        _checkIndex(edit.operationIndex, operations.length, allowEnd: false);
        _validateQubits(circuit, edit.qubits, edit.controls);
        operations[edit.operationIndex] = KetGate(
          name: edit.name,
          qubits: edit.qubits,
          controls: edit.controls,
          parameters: edit.parameters,
        );
      case InsertCircuitGate():
        _checkIndex(edit.operationIndex, operations.length, allowEnd: true);
        _validateQubits(circuit, edit.qubits, edit.controls);
        final firstMeasurement = operations.indexWhere((op) => op is KetMeasure);
        if (firstMeasurement >= 0 && edit.operationIndex > firstMeasurement) {
          throw StateError('KET circuit edits cannot insert a gate after terminal measurement.');
        }
        operations.insert(
          edit.operationIndex,
          KetGate(
            name: edit.name,
            qubits: edit.qubits,
            controls: edit.controls,
            parameters: edit.parameters,
          ),
        );
    }
    final updated = KetCircuit(
      qubitCount: circuit.qubitCount,
      classicalBitCount: circuit.classicalBitCount,
      operations: List<KetOperation>.unmodifiable(operations),
      metadata: circuit.metadata,
    );
    final encoded = _codec.encode(updated);
    return CircuitSyncSnapshot(
      source: encoded,
      circuit: updated,
      diagram: _layoutEngine.layout(updated),
    );
  }

  void _checkIndex(int index, int length, {required bool allowEnd}) {
    final max = allowEnd ? length : length - 1;
    if (index < 0 || index > max) throw RangeError.range(index, 0, max);
  }

  void _validateQubits(KetCircuit circuit, List<int> targets, List<int> controls) {
    if (targets.isEmpty) throw ArgumentError('A gate requires at least one target qubit.');
    final seen = <int>{};
    for (final qubit in <int>[...targets, ...controls]) {
      if (qubit < 0 || qubit >= circuit.qubitCount) {
        throw RangeError.range(qubit, 0, circuit.qubitCount - 1, 'qubit');
      }
      if (!seen.add(qubit)) throw ArgumentError('Gate qubits must be unique.');
    }
  }
}
