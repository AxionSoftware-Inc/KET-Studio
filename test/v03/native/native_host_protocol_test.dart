import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/core/native/native_host_protocol.dart';

void main() {
  const codec = NativeHostFrameCodec();

  test('round-trips framed native host messages', () {
    const message = NativeHostMessage(
      type: NativeHostMessageType.openTerminal,
      requestId: 'r42',
      payload: <String, Object?>{
        'executable': 'python',
        'arguments': <String>['-i'],
      },
    );

    final frame = codec.encode(message);
    final decoder = NativeHostFrameDecoder(codec);
    final decoded = decoder.add(frame);

    expect(decoded, hasLength(1));
    expect(decoded.single.type, NativeHostMessageType.openTerminal);
    expect(decoded.single.requestId, 'r42');
    expect(decoded.single.payload['executable'], 'python');
  });

  test('supports fragmented and coalesced transport chunks', () {
    const first = NativeHostMessage(
      type: NativeHostMessageType.hello,
      requestId: 'r1',
      payload: <String, Object?>{'protocolVersion': 1},
    );
    const second = NativeHostMessage(
      type: NativeHostMessageType.terminalExit,
      requestId: 'n2',
      sessionId: 'pty-1',
      payload: <String, Object?>{'exitCode': 0},
    );

    final a = codec.encode(first);
    final b = codec.encode(second);
    final bytes = Uint8List(a.length + b.length)
      ..setRange(0, a.length, a)
      ..setRange(a.length, a.length + b.length, b);

    final decoder = NativeHostFrameDecoder(codec);
    expect(decoder.add(Uint8List.sublistView(bytes, 0, 3)), isEmpty);
    final decoded = decoder.add(Uint8List.sublistView(bytes, 3));

    expect(decoded, hasLength(2));
    expect(decoded[0].requestId, 'r1');
    expect(decoded[1].sessionId, 'pty-1');
  });

  test('rejects oversized advertised frames before allocation', () {
    const smallCodec = NativeHostFrameCodec(maxFrameBytes: 32);
    final decoder = NativeHostFrameDecoder(smallCodec);
    final header = Uint8List.fromList(<int>[0, 0, 1, 0]);

    expect(() => decoder.add(header), throwsFormatException);
  });
}
