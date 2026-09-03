import 'dart:convert';

enum KetEventKind {
  lifecycle,
  stdout,
  stderr,
  display,
  result,
  diagnostic,
  progress,
  inputRequest,
  artifact,
  quantumCircuit,
  statevector,
  densityMatrix,
  histogram,
  metrics,
  error,
}

final class KetProtocolException implements Exception {
  const KetProtocolException(this.message);
  final String message;

  @override
  String toString() => 'KetProtocolException: $message';
}

final class KetEvent {
  const KetEvent({
    required this.protocolVersion,
    required this.sessionId,
    required this.sequence,
    required this.timestamp,
    required this.kind,
    required this.payload,
  });

  static const int currentProtocolVersion = 1;
  static const int maxEncodedBytes = 8 * 1024 * 1024;

  final int protocolVersion;
  final String sessionId;
  final int sequence;
  final DateTime timestamp;
  final KetEventKind kind;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
        'protocolVersion': protocolVersion,
        'sessionId': sessionId,
        'sequence': sequence,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'kind': kind.name,
        'payload': payload,
      };

  String encode() {
    final value = jsonEncode(toJson());
    if (utf8.encode(value).length > maxEncodedBytes) {
      throw const KetProtocolException('Event exceeds maximum encoded size.');
    }
    return value;
  }

  static KetEvent decode(String encoded) {
    if (utf8.encode(encoded).length > maxEncodedBytes) {
      throw const KetProtocolException('Event exceeds maximum encoded size.');
    }

    final Object? raw;
    try {
      raw = jsonDecode(encoded);
    } on FormatException catch (error) {
      throw KetProtocolException('Invalid JSON: ${error.message}');
    }

    if (raw is! Map<String, Object?>) {
      throw const KetProtocolException('Event root must be an object.');
    }

    final protocolVersion = raw['protocolVersion'];
    final sessionId = raw['sessionId'];
    final sequence = raw['sequence'];
    final timestamp = raw['timestamp'];
    final kindName = raw['kind'];
    final payload = raw['payload'];

    if (protocolVersion is! int || protocolVersion != currentProtocolVersion) {
      throw KetProtocolException('Unsupported protocol version: $protocolVersion');
    }
    if (sessionId is! String || sessionId.trim().isEmpty) {
      throw const KetProtocolException('sessionId must be a non-empty string.');
    }
    if (sequence is! int || sequence < 0) {
      throw const KetProtocolException('sequence must be a non-negative integer.');
    }
    if (timestamp is! String) {
      throw const KetProtocolException('timestamp must be an ISO-8601 string.');
    }
    if (kindName is! String) {
      throw const KetProtocolException('kind must be a string.');
    }
    if (payload is! Map<String, Object?>) {
      throw const KetProtocolException('payload must be an object.');
    }

    final kind = KetEventKind.values
        .where((candidate) => candidate.name == kindName)
        .firstOrNull;
    if (kind == null) {
      throw KetProtocolException('Unknown event kind: $kindName');
    }

    final parsedTimestamp = DateTime.tryParse(timestamp);
    if (parsedTimestamp == null) {
      throw const KetProtocolException('Invalid event timestamp.');
    }

    return KetEvent(
      protocolVersion: protocolVersion,
      sessionId: sessionId,
      sequence: sequence,
      timestamp: parsedTimestamp,
      kind: kind,
      payload: payload,
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
