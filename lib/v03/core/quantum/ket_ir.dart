/// KET's vendor-neutral circuit IR.
///
/// Keep this deliberately small and deterministic. Provider adapters are
/// responsible for lowering/raising between KET IR and SDK-specific objects.
final class KetCircuit {
  const KetCircuit({
    required this.qubitCount,
    required this.operations,
    this.classicalBitCount = 0,
    this.metadata = const <String, Object?>{},
  })  : assert(qubitCount > 0),
        assert(classicalBitCount >= 0);

  final int qubitCount;
  final int classicalBitCount;
  final List<KetOperation> operations;
  final Map<String, Object?> metadata;
}

sealed class KetOperation {
  const KetOperation();
}

final class KetGate extends KetOperation {
  const KetGate({
    required this.name,
    required this.qubits,
    this.parameters = const <KetParameter>[],
    this.controls = const <int>[],
  });

  final String name;
  final List<int> qubits;
  final List<KetParameter> parameters;
  final List<int> controls;
}

final class KetMeasure extends KetOperation {
  const KetMeasure({required this.qubit, required this.classicalBit});

  final int qubit;
  final int classicalBit;
}

final class KetBarrier extends KetOperation {
  const KetBarrier(this.qubits);

  final List<int> qubits;
}

sealed class KetParameter {
  const KetParameter();
}

final class KetLiteralParameter extends KetParameter {
  const KetLiteralParameter(this.value);

  final double value;
}

final class KetSymbolParameter extends KetParameter {
  const KetSymbolParameter(this.name);

  final String name;
}

abstract interface class KetIrCodec {
  String encode(KetCircuit circuit);
  KetCircuit decode(String source);
}

abstract interface class OpenQasm3Codec {
  String encode(KetCircuit circuit);
  KetCircuit decode(String source);
}
