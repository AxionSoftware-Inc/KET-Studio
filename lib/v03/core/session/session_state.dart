enum SessionState {
  created,
  starting,
  running,
  stopping,
  exited,
  failed,
}

final class InvalidSessionTransition implements Exception {
  const InvalidSessionTransition(this.from, this.to);

  final SessionState from;
  final SessionState to;

  @override
  String toString() => 'InvalidSessionTransition: ${from.name} -> ${to.name}';
}

final class SessionStateMachine {
  SessionStateMachine([this._state = SessionState.created]);

  SessionState _state;
  SessionState get state => _state;

  bool get isTerminal =>
      _state == SessionState.exited || _state == SessionState.failed;

  void transitionTo(SessionState next) {
    if (!_allowed(_state, next)) {
      throw InvalidSessionTransition(_state, next);
    }
    _state = next;
  }

  static bool _allowed(SessionState from, SessionState to) {
    return switch (from) {
      SessionState.created =>
        to == SessionState.starting || to == SessionState.failed,
      SessionState.starting =>
        to == SessionState.running ||
            to == SessionState.stopping ||
            to == SessionState.failed,
      SessionState.running =>
        to == SessionState.stopping ||
            to == SessionState.exited ||
            to == SessionState.failed,
      SessionState.stopping =>
        to == SessionState.exited || to == SessionState.failed,
      SessionState.exited => false,
      SessionState.failed => false,
    };
  }
}
