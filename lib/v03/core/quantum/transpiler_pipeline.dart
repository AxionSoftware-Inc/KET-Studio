import 'ket_ir.dart';

final class TranspilationTrace {
  const TranspilationTrace({
    required this.input,
    required this.stages,
    required this.output,
  });

  final KetCircuit input;
  final List<TranspilationStage> stages;
  final KetCircuit output;
}

final class TranspilationStage {
  const TranspilationStage({
    required this.id,
    required this.name,
    required this.before,
    required this.after,
    required this.metrics,
    this.notes = const <String>[],
  });

  final String id;
  final String name;
  final KetCircuit before;
  final KetCircuit after;
  final TranspilationMetrics metrics;
  final List<String> notes;
}

final class TranspilationMetrics {
  const TranspilationMetrics({
    required this.depthBefore,
    required this.depthAfter,
    required this.gateCountBefore,
    required this.gateCountAfter,
    required this.twoQubitGateCountBefore,
    required this.twoQubitGateCountAfter,
    this.estimatedErrorBefore,
    this.estimatedErrorAfter,
  });

  final int depthBefore;
  final int depthAfter;
  final int gateCountBefore;
  final int gateCountAfter;
  final int twoQubitGateCountBefore;
  final int twoQubitGateCountAfter;
  final double? estimatedErrorBefore;
  final double? estimatedErrorAfter;
}

abstract interface class TranspilerInspector {
  Future<TranspilationTrace> transpile({
    required KetCircuit circuit,
    required String backendId,
    required String targetId,
    Map<String, Object?> options = const <String, Object?>{},
  });
}
