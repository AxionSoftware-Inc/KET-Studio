# KET Studio v0.3 — Production Roadmap

This roadmap is intentionally ordered by architectural risk, not visual appeal.

## Phase 0 — Foundation (current)

- clean v0.3 module boundary
- versioned KET Protocol
- deterministic lifecycle/state machines
- terminal and execution contracts
- test/analysis quality gate
- architecture and security rules

Exit criteria: core code is testable headlessly and no v0.3 domain module imports Flutter.

## Phase 1 — Native host

- native host process/library
- Windows ConPTY adapter
- Linux/macOS POSIX PTY adapter
- process-tree ownership and termination
- shell discovery
- environment normalization
- framed IPC with backpressure
- crash isolation and restart policy

Exit criteria: interactive shells pass resize, Unicode, interrupt, exit-code and process-tree integration tests on supported OSes.

## Phase 2 — Workbench shell

- clean application bootstrap
- command registry
- workspace/project model
- dockable/resizable panes
- explorer
- editor tabs and dirty-state handling
- real terminal view bound to PTY
- settings and keybindings
- crash recovery/autosave

Exit criteria: KET Studio can be used as a stable project workbench without quantum-specific features.

## Phase 3 — Python engineering environment

- interpreter discovery
- uv/venv environment management
- persistent Python kernel
- structured stdout/stderr/display transport
- stdin requests
- cancellation and restart
- Python LSP integration
- diagnostics/completion/navigation
- debugger adapter integration

Exit criteria: Python workflow is competitive with a focused engineering IDE for KET Studio use cases.

## Phase 4 — Quantum workbench

- normalized circuit model
- circuit renderer/editor
- histogram/statevector/density-matrix views
- Bloch sphere and state inspection
- simulation jobs
- Qiskit adapter
- Cirq adapter
- PennyLane adapter
- experiment parameters/history/artifacts

Exit criteria: circuit -> execute -> inspect -> compare experiments works end-to-end.

## Phase 5 — Production hardening

- large-project performance profiling
- protocol fuzzing
- resource leak testing
- packaging/signing
- updater
- structured logs and diagnostics bundle
- accessibility and keyboard navigation audit
- integration/smoke suites on Windows/macOS/Linux
- release-channel policy

Exit criteria: release candidate meets documented reliability and supportability gates.

## Non-goals for early v0.3

- cloning VS Code extension compatibility
- supporting every programming language
- cloud account system before local workflows are excellent
- adding AI features before execution/editor/terminal foundations are reliable
