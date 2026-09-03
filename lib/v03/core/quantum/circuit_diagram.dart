import 'ket_ir.dart';

enum CircuitNodeKind { gate, measurement, barrier }

final class CircuitDiagram {
  const CircuitDiagram({
    required this.qubitCount,
    required this.columns,
    required this.depth,
  });

  final int qubitCount;
  final List<CircuitColumn> columns;
  final int depth;
}

final class CircuitColumn {
  const CircuitColumn({required this.index, required this.nodes});

  final int index;
  final List<CircuitNode> nodes;
}

final class CircuitNode {
  const CircuitNode({
    required this.operationIndex,
    required this.column,
    required this.kind,
    required this.label,
    required this.qubits,
    this.controls = const <int>[],
    this.parameters = const <String>[],
  });

  final int operationIndex;
  final int column;
  final CircuitNodeKind kind;
  final String label;
  final List<int> qubits;
  final List<int> controls;
  final List<String> parameters;
}

sealed class CircuitEdit {
  const CircuitEdit();
}

final class RemoveCircuitOperation extends CircuitEdit {
  const RemoveCircuitOperation(this.operationIndex);
  final int operationIndex;
}

final class ReplaceCircuitGate extends CircuitEdit {
  const ReplaceCircuitGate({
    required this.operationIndex,
    required this.name,
    required this.qubits,
    this.controls = const <int>[],
    this.parameters = const <KetParameter>[],
  });

  final int operationIndex;
  final String name;
  final List<int> qubits;
  final List<int> controls;
  final List<KetParameter> parameters;
}

final class InsertCircuitGate extends CircuitEdit {
  const InsertCircuitGate({
    required this.operationIndex,
    required this.name,
    required this.qubits,
    this.controls = const <int>[],
    this.parameters = const <KetParameter>[],
  });

  final int operationIndex;
  final String name;
  final List<int> qubits;
  final List<int> controls;
  final List<KetParameter> parameters;
}

abstract interface class CircuitLayoutEngine {
  CircuitDiagram layout(KetCircuit circuit);
}
