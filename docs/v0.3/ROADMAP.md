# KET Studio v0.3 — Production Roadmap

This roadmap is ordered by architectural risk rather than visual appeal.

## Phase 0 — Foundation — LANDED

- clean v0.3 module boundary
- versioned KET Protocol
- deterministic lifecycle/state machines
- terminal/execution/kernel/provider contracts
- architecture and security rules

## Phase 1 — Native host — FOUNDATION LANDED

- isolated native host
- Windows ConPTY
- Linux/macOS POSIX PTY
- process-tree ownership
- environment normalization
- framed IPC
- terminal emulator binding

Remaining release gate: platform stress/integration validation on packaged Windows/macOS/Linux builds.

## Phase 2 — Workbench shell — FUNCTIONAL SLICE LANDED

- v0.3 application bootstrap
- activity/sidebar/editor/bottom-panel workbench
- real VT terminal
- multi-document editing and dirty state
- filesystem open/save
- Command Palette + default keybindings
- isolate-backed project search
- persisted workspace/session recovery
- selected provider/noise state recovery

Remaining: external file-watch merge UX, settings/keybinding customization and accessibility polish.

## Phase 3 — Python engineering environment — FUNCTIONAL SLICE LANDED

- persistent Python kernel
- structured KET events
- stdin/restart lifecycle
- Pyright LSP transport
- diagnostics/completion/hover/definition contract
- debugpy-compatible DAP transport
- Python Run/Debug workbench integration

Remaining: environment/venv manager, deeper DAP UI and release-platform integration tests.

## Phase 4 — Quantum workbench — CORE PRODUCT LOOP LANDED

- KET IR + validated OpenQASM 3 subset
- exact isolate-backed statevector simulation
- density-matrix/noise foundation
- visual circuit canvas with source round-trip edits
- quantum debugger with Bloch/purity/concurrence
- transpiler pass trace and metrics
- provider registry/health
- optional Qiskit/PennyLane/Cirq Python bridge adapters
- persisted experiments/artifacts
- Experiment Lab distribution comparison
- Workspace Graph lineage
- remote-job recovery substrate

Remaining: authenticated real-hardware/cloud adapters, richer circuit editing, full noise channels and large-workflow UX.

## Phase 5 — Production hardening — NEXT LARGE MILESTONE

- packaged runtime/native-host/provider-bridge discovery
- installer validation on Windows/macOS/Linux
- structured logging and crash/support bundle
- credential/security storage boundary
- plugin signing/trust policy
- protocol fuzzing and malformed-host tests
- terminal/kernel/provider stress suites
- resource/leak profiling
- accessibility and keyboard navigation audit
- external file watching/conflict handling
- release candidate checklist and release-channel policy

Exit criteria: a packaged release candidate meets documented reliability, security, recovery and supportability gates on every supported desktop OS.

## Delivery rule

Development proceeds through large vertical milestones and atomic commits. GitHub Actions remains disabled by repository-owner request; release gates are executed locally/release-side.

## Non-goals for v0.3

- cloning VS Code extension compatibility
- supporting every programming language
- cloud account/collaboration before local workflows are excellent
- making AI a dependency of the core product
- pretending unsupported hardware/noise/provider semantics are implemented
