import 'package:flutter_test/flutter_test.dart';
import 'package:ket_studio/v03/core/session/session_state.dart';

void main() {
  group('SessionStateMachine', () {
    test('follows the normal lifecycle', () {
      final machine = SessionStateMachine();

      machine.transitionTo(SessionState.starting);
      machine.transitionTo(SessionState.running);
      machine.transitionTo(SessionState.stopping);
      machine.transitionTo(SessionState.exited);

      expect(machine.state, SessionState.exited);
      expect(machine.isTerminal, isTrue);
    });

    test('rejects invalid transitions', () {
      final machine = SessionStateMachine();

      expect(
        () => machine.transitionTo(SessionState.running),
        throwsA(isA<InvalidSessionTransition>()),
      );
    });

    test('terminal states cannot transition', () {
      final machine = SessionStateMachine()
        ..transitionTo(SessionState.starting)
        ..transitionTo(SessionState.failed);

      expect(
        () => machine.transitionTo(SessionState.starting),
        throwsA(isA<InvalidSessionTransition>()),
      );
    });
  });
}
