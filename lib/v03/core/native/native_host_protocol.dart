import 'dart:convert';
import 'dart:typed_data';

enum NativeHostMessageType {
  hello,
  openTerminal,
  terminalOpened,
  terminalInput,
  terminalOutput,
  terminalResize,
  terminalInterrupt,
  terminalTerminate,
  terminalExit,
  error,
  shutdown,
}

final class NativeHostMessage {
  const NativeHostMessage({
    required this.type,
    required this.requestId,
    this.sessionId,
    this.payload = const <String, Object?>{},
  });

  final NativeHostMessageType type;
  final String requestId;
  final String? sessionId;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type.name,
        'requestId': requestId,
        if (sessionId != null) 'sessionId': sessionId,
        'payload': payload,
      };

  static NativeHostMessage fromJson(Map<String, Object?> json) {
    final typeName = json['type'];
    final requestId = json['requestId'];
    if (typeName is! String || requestId is! String || requestId.isEmpty) {
      throw const FormatException('Invalid native host message header.');
    }

    final type = NativeHostMessageType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    if (type == null) {
      throw FormatException('Unknown native host message type: $typeName');
    }

    final rawPayload = json['payload'];
    if (rawPayload != null && rawPayload is! Map) {
      throw const FormatException('Native host payload must be an object.');
    }

    return NativeHostMessage(
      type: type,
      requestId: requestId,
      sessionId: json['sessionId'] as String?,
      payload: rawPayload == null
          ? const <String, Object?>{}
          : Map<String, Object?>.from(rawPayload as Map),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

/// Binary framing used between Flutter and the native host:
/// [uint32 big-endian payload length][UTF-8 JSON payload].
final class NativeHostFrameCodec {
  const NativeHostFrameCodec({this.maxFrameBytes = 8 * 1024 * 1024});

  final int maxFrameBytes;

  Uint8List encode(NativeHostMessage message) {
    final payload = utf8.encode(jsonEncode(message.toJson()));
    if (payload.length > maxFrameBytes) {
      throw StateError('Native host frame exceeds $maxFrameBytes bytes.');
    }
    final result = Uint8List(4 + payload.length);
    ByteData.sublistView(result).setUint32(0, payload.length, Endian.big);
    result.setRange(4, result.length, payload);
    return result;
  }

  NativeHostMessage decodePayload(Uint8List payload) {
    if (payload.length > maxFrameBytes) {
      throw const FormatException('Native host frame exceeds maximum size.');
    }
    final decoded = jsonDecode(utf8.decode(payload));
    if (decoded is! Map) {
      throw const FormatException('Native host frame must contain a JSON object.');
    }
    return NativeHostMessage.fromJson(Map<String, Object?>.from(decoded));
  }
}

final class NativeHostFrameDecoder {
  NativeHostFrameDecoder(this.codec);

  final NativeHostFrameCodec codec;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  List<NativeHostMessage> add(Uint8List chunk) {
    _buffer.add(chunk);
    final bytes = _buffer.toBytes();
    var offset = 0;
    final messages = <NativeHostMessage>[];

    while (bytes.length - offset >= 4) {
      final length = ByteData.sublistView(bytes, offset, offset + 4)
          .getUint32(0, Endian.big);
      if (length > codec.maxFrameBytes) {
        throw const FormatException('Native host frame exceeds maximum size.');
      }
      if (bytes.length - offset - 4 < length) break;
      final payload = Uint8List.sublistView(bytes, offset + 4, offset + 4 + length);
      messages.add(codec.decodePayload(payload));
      offset += 4 + length;
    }

    _buffer.clear();
    if (offset < bytes.length) {
      _buffer.add(Uint8List.sublistView(bytes, offset));
    }
    return messages;
  }
}
