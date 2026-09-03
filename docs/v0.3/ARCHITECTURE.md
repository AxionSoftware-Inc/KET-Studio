# KET Studio v0.3 — Production Architecture

Status: **active rewrite baseline**

## Product definition

KET Studio v0.3 is a desktop-first quantum engineering workbench, not a generic text editor. The product is organized around reproducible execution, quantum-aware visualization, project state, terminals, language tooling, and future hardware/simulator backends.

## Architectural rules

1. Flutter is the presentation/workbench layer only.
2. OS-sensitive capabilities (PTY, process tree control, signals, file watching where needed) live behind native adapters.
3. Execution is session-based and event-driven; UI never parses ad-hoc terminal text to infer structured results.
4. Core domain code must not import Flutter.
5. Every long-lived subsystem has an explicit lifecycle and deterministic disposal.
6. Structured messages are versioned and validated.
7. No subsystem communicates through global mutable state.
8. Crashes and malformed backend messages must be isolated from the workbench.
9. The repository must remain testable without launching a desktop window.
10. Product features are added through stable contracts, not direct cross-module imports.

## High-level layers

```text
┌─────────────────────────────────────────────────────────────┐
│ Flutter Workbench                                           │
│ editor | explorer | terminal | inspector | experiments     │
├─────────────────────────────────────────────────────────────┤
│ Application Services                                        │
│ workspace | commands | execution | diagnostics | settings  │
├─────────────────────────────────────────────────────────────┤
│ Domain/Core                                                 │
│ protocol | sessions | events | models | contracts           │
├─────────────────────────────────────────────────────────────┤
│ Infrastructure                                              │
│ PTY | processes | filesystem | LSP | DAP | persistence      │
├─────────────────────────────────────────────────────────────┤
│ Native Host / External Runtimes                             │
│ ConPTY | POSIX PTY | Python | uv/venv | Qiskit | Cirq ...  │
└─────────────────────────────────────────────────────────────┘
```

## Terminal architecture

A production terminal is a real PTY session, never a redirected `Process.start()` console.

- Windows: ConPTY
- Linux/macOS: POSIX PTY
- bidirectional byte stream
- terminal resize
- Ctrl+C / interrupt semantics
- process-tree termination
- exit status
- UTF-8 + binary-safe transport boundaries
- shell auto-detection

Flutter renders terminal state. It does not own process semantics.

## Execution architecture

Each execution is represented by an `ExecutionSession` with a stable id and lifecycle:

`created -> starting -> running -> stopping -> exited | failed`

Structured kernel events use KET Protocol and are transported separately from normal stdout/stderr whenever possible.

Core event families:

- lifecycle
- stdout / stderr
- display
- execution result
- diagnostics
- progress
- input request
- artifact
- quantum circuit
- statevector
- density matrix
- histogram
- metrics
- error

## Language tooling

Language intelligence is adapter-based:

- LSP for completion/diagnostics/navigation
- DAP for debugger integration
- formatters/linters as tools

Python is first-class in v0.3. Other languages are future adapters.

## Quantum subsystem

The quantum layer must not hard-code one SDK. Backends are capabilities:

- simulator discovery
- circuit execution
- shots/statevector modes
- backend metadata
- job cancellation
- result normalization

Initial adapters may target Qiskit, Cirq and PennyLane while exposing one KET-facing result model.

## Persistence

Workspace state, layout, sessions, and experiment metadata are persisted through repositories behind interfaces. UI widgets never write files directly.

## Security baseline

- never execute shell input without explicit user action
- never interpolate user paths into shell command strings when argv APIs are available
- sanitize environment inheritance
- cap structured message sizes
- reject protocol versions/types not understood
- redact secrets from logs where identifiable
- no telemetry by default without explicit product policy

## Testing gates

- protocol codec tests
- state-machine tests
- terminal contract tests with fake host
- execution service tests
- workspace persistence tests
- parser fuzz/property tests where practical
- platform integration tests for PTY/process tree
- smoke test for packaged app

## Rewrite policy

Legacy files are reference material only. v0.3 modules should not depend on v0.2 implementation details unless intentionally migrated behind a new contract.
