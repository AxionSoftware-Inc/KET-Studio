import '../../core/quantum/ket_ir.dart';
import '../../core/quantum/transpiler_pipeline.dart';
import 'circuit_layout_engine.dart';

final class BasicTranspilerInspector implements TranspilerInspector {
  const BasicTranspilerInspector();

  @override
  Future<TranspilationTrace> transpile({
    required KetCircuit circuit,
    required String backendId,
    required String targetId,
    Map<String, Object?> options = const <String, Object?>{},
  }) async {
    final stages = <TranspilationStage>[];
    var current = circuit;

    final noBarriers = _withoutBarriers(current);
    stages.add(_stage('strip-barriers', 'Strip barriers', current, noBarriers));
    current = noBarriers;

    final cancelled = _cancelAdjacentSelfInverse(current);
    stages.add(_stage('cancel-inverses', 'Cancel adjacent inverses', current, cancelled));
    current = cancelled;

    final noZeroRotations = _removeZeroRotations(current);
    stages.add(_stage('drop-zero-rotations', 'Drop zero rotations', current, noZeroRotations));
    current = noZeroRotations;

    return TranspilationTrace(
      input: circuit,
      stages: List<TranspilationStage>.unmodifiable(stages),
      output: current,
    );
  }

  KetCircuit _withoutBarriers(KetCircuit circuit) => _copy(
        circuit,
        circuit.operations.where((operation) => operation is! KetBarrier).toList(),
      );

  KetCircuit _cancelAdjacentSelfInverse(KetCircuit circuit) {
    final result = <KetOperation>[];
    for (final operation in circuit.operations) {
      if (result.isNotEmpty && _cancels(result.last, operation)) {
        result.removeLast();
      } else {
        result.add(operation);
      }
    }
    return _copy(circuit, result);
  }

  bool _cancels(KetOperation a, KetOperation b) {
    if (a is! KetGate || b is! KetGate) return false;
    const selfInverse = <String>{'x', 'y', 'z', 'h', 'swap'};
    if (!selfInverse.contains(a.name) || a.name != b.name) return false;
    if (!_sameInts(a.qubits, b.qubits) || !_sameInts(a.controls, b.controls)) return false;
    return a.parameters.isEmpty && b.parameters.isEmpty;
  }

  KetCircuit _removeZeroRotations(KetCircuit circuit) {
    final operations = circuit.operations.where((operation) {
      if (operation is! KetGate || !const <String>{'rx', 'ry', 'rz'}.contains(operation.name)) {
        return true;
      }
      if (operation.parameters.length != 1 || operation.parameters.single is! KetLiteralParameter) {
        return true;
      }
      final value = (operation.parameters.single as KetLiteralParameter).value;
      return value.abs() > 1e-12;
    }).toList(growable: false);
    return _copy(circuit, operations);
  }

  TranspilationStage _stage(String id, String name, KetCircuit before, KetCircuit after) {
    final beforeMetrics = _metrics(before);
    final afterMetrics = _metrics(after);
    return TranspilationStage(
      id: id,
      name: name,
      before: before,
      after: after,
      metrics: TranspilationMetrics(
        depthBefore: beforeMetrics.$1,
        depthAfter: afterMetrics.$1,
        gateCountBefore: beforeMetrics.$2,
        gateCountAfter: afterMetrics.$2,
        twoQubitGateCountBefore: beforeMetrics.$3,
        twoQubitGateCountAfter: afterMetrics.$3,
      ),
      notes: before.operations.length == after.operations.length
          ? const <String>['No change for this circuit.']
          : <String>['Removed ${before.operations.length - after.operations.length} operation(s).'],
    );
  }

  (int, int, int) _metrics(KetCircuit circuit) {
    final depth = const DeterministicCircuitLayoutEngine().layout(circuit).depth;
    final gates = circuit.operations.whereType<KetGate>().toList(growable: false);
    final twoQubit = gates.where((gate) => gate.qubits.length + gate.controls.length >= 2).length;
    return (depth, gates.length, twoQubit);
  }

  bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  KetCircuit _copy(KetCircuit circuit, List<KetOperation> operations) => KetCircuit(
        qubitCount: circuit.qubitCount,
        classicalBitCount: circuit.classicalBitCount,
        operations: List<KetOperation>.unmodifiable(operations),
        metadata: circuit.metadata,
      );
}
