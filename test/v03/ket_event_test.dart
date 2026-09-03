import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/core/protocol/ket_event.dart';

void main() {
  group('KetEvent', () {
    test('round-trips a valid event', () {
      final event = KetEvent(
        protocolVersion: KetEvent.currentProtocolVersion,
        sessionId: 'session-1',
        sequence: 7,
        timestamp: DateTime.utc(2026, 9, 3, 10, 0),
        kind: KetEventKind.histogram,
        payload: const <String, Object?>{
          'counts': <String, int>{'00': 500, '11': 524},
        },
      );

      final decoded = KetEvent.decode(event.encode());

      expect(decoded.sessionId, 'session-1');
      expect(decoded.sequence, 7);
      expect(decoded.kind, KetEventKind.histogram);
      expect(decoded.payload['counts'], isA<Map<String, Object?>>());
    });

    test('rejects unsupported protocol versions', () {
      const encoded = '{'
          '"protocolVersion":999,'
          '"sessionId":"x",'
          '"sequence":0,'
          '"timestamp":"2026-09-03T10:00:00Z",'
          '"kind":"stdout",'
          '"payload":{}'
          '}';

      expect(
        () => KetEvent.decode(encoded),
        throwsA(isA<KetProtocolException>()),
      );
    });

    test('rejects malformed roots', () {
      expect(
        () => KetEvent.decode('[]'),
        throwsA(isA<KetProtocolException>()),
      );
    });
  });
}
