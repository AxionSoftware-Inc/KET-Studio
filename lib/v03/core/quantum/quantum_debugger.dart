import 'ket_ir.dart';
import 'quantum_backend.dart';

abstract interface class QuantumDebugger {
  Future<QuantumDebugSession> start(QuantumDebugRequest request);
}

final class QuantumDebugRequest {
  const QuantumDebugRequest({
    required this.circuit,
    this.parameters = const <String, double>{},
  });

  final KetCircuit circuit;
  final Map<String, double> parameters;
}

abstract interface class QuantumDebugSession {
  int get operationIndex;
  Future<QuantumDebugSnapshot> current();
  Future<QuantumDebugSnapshot> stepForward();
  Future<QuantumDebugSnapshot> stepBackward();
  Future<QuantumDebugSnapshot> seek(int operationIndex);
  Future<void> dispose();
}

final class QuantumDebugSnapshot {
  const QuantumDebugSnapshot({
    required this.operationIndex,
    required this.operation,
    required this.probabilities,
    this.statevector,
    this.densityMatrix,
    this.qubits = const <QubitSnapshot>[],
    this.entanglement = const <EntanglementEdge>[],
  });

  final int operationIndex;
  final KetOperation? operation;
  final Map<String, double> probabilities;
  final List<ComplexValue>? statevector;
  final List<List<ComplexValue>>? densityMatrix;
  final List<QubitSnapshot> qubits;
  final List<EntanglementEdge> entanglement;
}

final class QubitSnapshot {
  const QubitSnapshot({
    required this.index,
    required this.blochX,
    required this.blochY,
    required this.blochZ,
    required this.purity,
  });

  final int index;
  final double blochX;
  final double blochY;
  final double blochZ;
  final double purity;
}

final class EntanglementEdge {
  const EntanglementEdge({
    required this.a,
    required this.b,
    required this.strength,
  });

  final int a;
  final int b;
  final double strength;
}
