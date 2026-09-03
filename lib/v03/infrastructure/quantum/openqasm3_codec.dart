import 'dart:convert';
import 'dart:math' as math;

import '../../core/quantum/ket_ir.dart';

final class OpenQasm3ParseException implements Exception {
  const OpenQasm3ParseException(this.message);
  final String message;

  @override
  String toString() => 'OpenQasm3ParseException: $message';
}

final class KetJsonCodec implements KetIrCodec {
  const KetJsonCodec();

  @override
  String encode(KetCircuit circuit) => jsonEncode(<String, Object?>{
        'version': 1,
        'qubitCount': circuit.qubitCount,
        'classicalBitCount': circuit.classicalBitCount,
        'metadata': circuit.metadata,
        'operations': circuit.operations.map(_encodeOperation).toList(),
      });

  Map<String, Object?> _encodeOperation(KetOperation operation) {
    return switch (operation) {
      KetGate() => <String, Object?>{
          'kind': 'gate',
          'name': operation.name,
          'qubits': operation.qubits,
          'controls': operation.controls,
          'parameters': operation.parameters.map(_encodeParameter).toList(),
        },
      KetMeasure() => <String, Object?>{
          'kind': 'measure',
          'qubit': operation.qubit,
          'classicalBit': operation.classicalBit,
        },
      KetBarrier() => <String, Object?>{
          'kind': 'barrier',
          'qubits': operation.qubits,
        },
    };
  }

  Object _encodeParameter(KetParameter parameter) => switch (parameter) {
        KetLiteralParameter() => <String, Object?>{
            'kind': 'literal',
            'value': parameter.value,
          },
        KetSymbolParameter() => <String, Object?>{
            'kind': 'symbol',
            'name': parameter.name,
          },
      };

  @override
  KetCircuit decode(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map) {
      throw const FormatException('KET IR root must be an object.');
    }
    final map = Map<String, Object?>.from(raw);
    if (map['version'] != 1) {
      throw FormatException('Unsupported KET IR version: ${map['version']}');
    }
    final qubitCount = map['qubitCount'];
    final classicalBitCount = map['classicalBitCount'] ?? 0;
    final operations = map['operations'];
    if (qubitCount is! int || qubitCount <= 0) {
      throw const FormatException('qubitCount must be a positive integer.');
    }
    if (classicalBitCount is! int || classicalBitCount < 0) {
      throw const FormatException('classicalBitCount must be non-negative.');
    }
    if (operations is! List) {
      throw const FormatException('operations must be an array.');
    }

    return KetCircuit(
      qubitCount: qubitCount,
      classicalBitCount: classicalBitCount,
      operations: operations.map(_decodeOperation).toList(growable: false),
      metadata: map['metadata'] is Map
          ? Map<String, Object?>.from(map['metadata']! as Map)
          : const <String, Object?>{},
    );
  }

  KetOperation _decodeOperation(Object? value) {
    if (value is! Map) {
      throw const FormatException('Operation must be an object.');
    }
    final map = Map<String, Object?>.from(value);
    return switch (map['kind']) {
      'gate' => KetGate(
          name: _requiredString(map, 'name'),
          qubits: _intList(map['qubits']),
          controls: _intList(map['controls']),
          parameters: (map['parameters'] is List
                  ? map['parameters']! as List
                  : const <Object?>[])
              .map(_decodeParameter)
              .toList(growable: false),
        ),
      'measure' => KetMeasure(
          qubit: _requiredInt(map, 'qubit'),
          classicalBit: _requiredInt(map, 'classicalBit'),
        ),
      'barrier' => KetBarrier(_intList(map['qubits'])),
      final Object? kind => throw FormatException('Unknown operation kind: $kind'),
    };
  }

  KetParameter _decodeParameter(Object? value) {
    if (value is! Map) {
      throw const FormatException('Parameter must be an object.');
    }
    final map = Map<String, Object?>.from(value);
    return switch (map['kind']) {
      'literal' => KetLiteralParameter((map['value'] as num).toDouble()),
      'symbol' => KetSymbolParameter(_requiredString(map, 'name')),
      final Object? kind => throw FormatException('Unknown parameter kind: $kind'),
    };
  }

  String _requiredString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  int _requiredInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  List<int> _intList(Object? value) {
    if (value == null) return const <int>[];
    if (value is! List || value.any((item) => item is! int)) {
      throw const FormatException('Expected an integer array.');
    }
    return value.cast<int>();
  }
}

final class OpenQasm3CodecImpl implements OpenQasm3Codec {
  const OpenQasm3CodecImpl();

  static final RegExp _registerDeclaration = RegExp(
    r'^(qubit|bit)\s*\[\s*(\d+)\s*\]\s*([A-Za-z_]\w*)$',
    caseSensitive: false,
  );
  static final RegExp _indexedOperand = RegExp(r'^([A-Za-z_]\w*)\s*\[\s*(\d+)\s*\]$');
  static final RegExp _gate = RegExp(
    r'^([A-Za-z_]\w*)\s*(?:\((.*)\))?\s+(.+)$',
    caseSensitive: false,
  );
  static final RegExp _measureArrow = RegExp(
    r'^measure\s+(.+?)\s*->\s*(.+)$',
    caseSensitive: false,
  );
  static final RegExp _measureAssignment = RegExp(
    r'^(.+?)\s*=\s*measure\s+(.+)$',
    caseSensitive: false,
  );

  @override
  KetCircuit decode(String source) {
    final cleaned = _stripComments(source);
    final statements = _splitStatements(cleaned);
    if (statements.isEmpty ||
        !statements.first.toUpperCase().startsWith('OPENQASM 3')) {
      throw const OpenQasm3ParseException('Source must start with OPENQASM 3.');
    }

    final registers = <String, _Register>{};
    final operations = <KetOperation>[];
    var qubitCount = 0;
    var classicalBitCount = 0;
    var measurementStarted = false;

    for (final raw in statements.skip(1)) {
      final statement = raw.trim();
      if (statement.isEmpty || statement.toLowerCase().startsWith('include ')) {
        continue;
      }

      final declaration = _registerDeclaration.firstMatch(statement);
      if (declaration != null) {
        final kind = declaration.group(1)!.toLowerCase();
        final count = int.parse(declaration.group(2)!);
        final name = declaration.group(3)!;
        if (count <= 0 || registers.containsKey(name)) {
          throw OpenQasm3ParseException('Invalid or duplicate register: $statement');
        }
        if (kind == 'qubit') {
          registers[name] = _Register(count, qubitCount, true);
          qubitCount += count;
        } else {
          registers[name] = _Register(count, classicalBitCount, false);
          classicalBitCount += count;
        }
        continue;
      }

      final measure = _parseMeasure(statement, registers);
      if (measure != null) {
        measurementStarted = true;
        operations.addAll(measure);
        continue;
      }

      if (statement.toLowerCase().startsWith('barrier ')) {
        final operands = statement.substring('barrier '.length).trim();
        final qubits = _expandQubitOperands(operands, registers);
        operations.add(KetBarrier(qubits));
        continue;
      }

      if (measurementStarted) {
        throw const OpenQasm3ParseException(
          'KET v0.3 local simulator only accepts terminal measurements. '
          'A quantum gate was found after measurement.',
        );
      }

      final match = _gate.firstMatch(statement);
      if (match == null) {
        throw OpenQasm3ParseException('Unsupported OpenQASM statement: $statement');
      }
      final name = match.group(1)!.toLowerCase();
      final parameterSource = match.group(2)?.trim();
      final operandSource = match.group(3)!.trim();
      final operands = _parseIndexedQubits(operandSource, registers);
      final parameters = parameterSource == null || parameterSource.isEmpty
          ? const <KetParameter>[]
          : _splitComma(parameterSource).map(_parseParameter).toList(growable: false);
      operations.add(_canonicalGate(name, operands, parameters));
    }

    if (qubitCount <= 0) {
      throw const OpenQasm3ParseException('Circuit declares no qubits.');
    }

    return KetCircuit(
      qubitCount: qubitCount,
      classicalBitCount: classicalBitCount,
      operations: operations,
      metadata: const <String, Object?>{'sourceFormat': 'openqasm3'},
    );
  }

  KetGate _canonicalGate(
    String name,
    List<int> operands,
    List<KetParameter> parameters,
  ) {
    switch (name) {
      case 'cx':
      case 'cnot':
        _requireArity(name, operands, 2);
        return KetGate(name: 'x', qubits: <int>[operands[1]], controls: <int>[operands[0]]);
      case 'cz':
        _requireArity(name, operands, 2);
        return KetGate(name: 'z', qubits: <int>[operands[1]], controls: <int>[operands[0]]);
      case 'ccx':
        _requireArity(name, operands, 3);
        return KetGate(
          name: 'x',
          qubits: <int>[operands[2]],
          controls: <int>[operands[0], operands[1]],
        );
      case 'swap':
        _requireArity(name, operands, 2);
        return KetGate(name: 'swap', qubits: operands, parameters: parameters);
      case 'x':
      case 'y':
      case 'z':
      case 'h':
      case 's':
      case 'sdg':
      case 't':
      case 'tdg':
      case 'rx':
      case 'ry':
      case 'rz':
        _requireArity(name, operands, 1);
        return KetGate(name: name, qubits: operands, parameters: parameters);
      default:
        throw OpenQasm3ParseException('Unsupported gate: $name');
    }
  }

  void _requireArity(String name, List<int> operands, int expected) {
    if (operands.length != expected) {
      throw OpenQasm3ParseException(
        'Gate $name requires $expected qubit(s), got ${operands.length}.',
      );
    }
  }

  List<KetMeasure>? _parseMeasure(
    String statement,
    Map<String, _Register> registers,
  ) {
    final arrow = _measureArrow.firstMatch(statement);
    if (arrow != null) {
      return _mapMeasurements(arrow.group(1)!, arrow.group(2)!, registers);
    }
    final assignment = _measureAssignment.firstMatch(statement);
    if (assignment != null) {
      return _mapMeasurements(assignment.group(2)!, assignment.group(1)!, registers);
    }
    return null;
  }

  List<KetMeasure> _mapMeasurements(
    String quantumSource,
    String classicalSource,
    Map<String, _Register> registers,
  ) {
    final qubits = _expandQubitOperands(quantumSource.trim(), registers);
    final bits = _expandClassicalOperands(classicalSource.trim(), registers);
    if (qubits.length != bits.length) {
      throw const OpenQasm3ParseException(
        'Measurement source and destination widths must match.',
      );
    }
    return <KetMeasure>[
      for (var i = 0; i < qubits.length; i++)
        KetMeasure(qubit: qubits[i], classicalBit: bits[i]),
    ];
  }

  List<int> _parseIndexedQubits(
    String source,
    Map<String, _Register> registers,
  ) {
    return _splitComma(source)
        .map((item) => _resolveIndexed(item.trim(), registers, qubit: true))
        .toList(growable: false);
  }

  List<int> _expandQubitOperands(
    String source,
    Map<String, _Register> registers,
  ) => _expandOperands(source, registers, qubit: true);

  List<int> _expandClassicalOperands(
    String source,
    Map<String, _Register> registers,
  ) => _expandOperands(source, registers, qubit: false);

  List<int> _expandOperands(
    String source,
    Map<String, _Register> registers, {
    required bool qubit,
  }) {
    final result = <int>[];
    for (final token in _splitComma(source)) {
      final item = token.trim();
      final indexed = _indexedOperand.firstMatch(item);
      if (indexed != null) {
        result.add(_resolveIndexed(item, registers, qubit: qubit));
        continue;
      }
      final register = registers[item];
      if (register == null || register.isQubit != qubit) {
        throw OpenQasm3ParseException('Unknown ${qubit ? 'qubit' : 'bit'} operand: $item');
      }
      for (var i = 0; i < register.count; i++) {
        result.add(register.offset + i);
      }
    }
    return result;
  }

  int _resolveIndexed(
    String source,
    Map<String, _Register> registers, {
    required bool qubit,
  }) {
    final match = _indexedOperand.firstMatch(source);
    if (match == null) {
      throw OpenQasm3ParseException('Expected indexed operand: $source');
    }
    final register = registers[match.group(1)!];
    final index = int.parse(match.group(2)!);
    if (register == null || register.isQubit != qubit || index >= register.count) {
      throw OpenQasm3ParseException('Invalid operand: $source');
    }
    return register.offset + index;
  }

  KetParameter _parseParameter(String source) {
    final text = source.trim();
    final number = double.tryParse(text);
    if (number != null) return KetLiteralParameter(number);

    final normalized = text.replaceAll(' ', '').toLowerCase();
    final piMatch = RegExp(r'^(-?)(\d+(?:\.\d+)?)?\*?pi(?:/(\d+(?:\.\d+)?))?$')
        .firstMatch(normalized);
    if (piMatch != null) {
      final sign = piMatch.group(1) == '-' ? -1.0 : 1.0;
      final multiplier = piMatch.group(2) == null ? 1.0 : double.parse(piMatch.group(2)!);
      final divisor = piMatch.group(3) == null ? 1.0 : double.parse(piMatch.group(3)!);
      if (divisor == 0) {
        throw const OpenQasm3ParseException('Angle divisor cannot be zero.');
      }
      return KetLiteralParameter(sign * multiplier * math.pi / divisor);
    }
    if (RegExp(r'^[A-Za-z_]\w*$').hasMatch(text)) {
      return KetSymbolParameter(text);
    }
    throw OpenQasm3ParseException('Unsupported parameter expression: $source');
  }

  @override
  String encode(KetCircuit circuit) {
    final out = StringBuffer('OPENQASM 3.0;\ninclude "stdgates.inc";\n');
    out.writeln('qubit[${circuit.qubitCount}] q;');
    if (circuit.classicalBitCount > 0) {
      out.writeln('bit[${circuit.classicalBitCount}] c;');
    }
    for (final operation in circuit.operations) {
      switch (operation) {
        case KetGate():
          out.writeln('${_encodeGate(operation)};');
        case KetMeasure():
          out.writeln('measure q[${operation.qubit}] -> c[${operation.classicalBit}];');
        case KetBarrier():
          out.writeln(
            'barrier ${operation.qubits.map((q) => 'q[$q]').join(', ')};',
          );
      }
    }
    return out.toString();
  }

  String _encodeGate(KetGate gate) {
    String name = gate.name;
    List<int> operands = gate.qubits;
    if (gate.controls.isNotEmpty) {
      if (gate.name == 'x' && gate.controls.length == 1) name = 'cx';
      if (gate.name == 'x' && gate.controls.length == 2) name = 'ccx';
      if (gate.name == 'z' && gate.controls.length == 1) name = 'cz';
      operands = <int>[...gate.controls, ...gate.qubits];
    }
    final params = gate.parameters.isEmpty
        ? ''
        : '(${gate.parameters.map(_encodeParameter).join(', ')})';
    return '$name$params ${operands.map((q) => 'q[$q]').join(', ')}';
  }

  String _encodeParameter(KetParameter parameter) => switch (parameter) {
        KetLiteralParameter() => parameter.value.toStringAsPrecision(12),
        KetSymbolParameter() => parameter.name,
      };

  String _stripComments(String source) {
    return source
        .split('\n')
        .map((line) {
          final index = line.indexOf('//');
          return index < 0 ? line : line.substring(0, index);
        })
        .join('\n');
  }

  List<String> _splitStatements(String source) {
    final result = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (final rune in source.runes) {
      final ch = String.fromCharCode(rune);
      if (inString) {
        buffer.write(ch);
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
        buffer.write(ch);
      } else if (ch == '(') {
        depth++;
        buffer.write(ch);
      } else if (ch == ')') {
        depth--;
        buffer.write(ch);
      } else if (ch == ';' && depth == 0) {
        final value = buffer.toString().trim();
        if (value.isNotEmpty) result.add(value);
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) result.add(tail);
    return result;
  }

  List<String> _splitComma(String source) {
    final result = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (final rune in source.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) result.add(buffer.toString());
    return result;
  }
}

final class _Register {
  const _Register(this.count, this.offset, this.isQubit);
  final int count;
  final int offset;
  final bool isQubit;
}
