# KET Studio v0.3 — Runtime + Workbench Vertical Slice

## Goal

This milestone replaces the legacy application boot path with the v0.3 workbench and closes the first end-to-end desktop runtime slice. The design assumes KET Studio is a long-lived engineering product, not a demo IDE.

## Product boundary

The desktop process owns presentation and orchestration only. Terminal processes run behind `ket_host`; Python code runs behind the persistent kernel runtime. Both communicate through versioned framed protocols and can be replaced independently.

```text
KET Workbench (Flutter)
  ├─ WorkbenchController
  ├─ RuntimeSupervisor
  │   ├─ NativeHostClient ── framed IPC ── ket_host
  │   │                                  ├─ ConPTY (Windows)
  │   │                                  └─ POSIX PTY (Linux/macOS)
  │   └─ PythonKernelHost ─ framed IPC ── ket_kernel.py
  └─ xterm3 terminal emulator
```

## Major changes in this milestone

### 1. Workbench boot

`lib/main.dart` boots the v0.3 application directly. Legacy plugin setup, layout and settings services are no longer part of the startup dependency graph.

The new shell contains:

- activity bar and explorer surfaces;
- document tabs and editor workspace;
- bottom terminal/problems/output/debug surfaces;
- quantum inspector;
- runtime status bar;
- desktop title/drag region.

This is a structural workbench foundation. The current source surface is intentionally lightweight; Monaco-style editing, LSP and DAP bind to this shell in the next milestone without changing the application topology.

### 2. Real terminal rendering

The UI no longer renders PTY output as text logs. `xterm3` is the terminal emulator and receives raw terminal data from `TerminalSession`. User input and resize events travel back to the native host.

### 3. Runtime supervisor

`RuntimeSupervisor` is the sole owner of terminal and kernel runtime lifecycles from the application layer. It provides:

- runtime discovery;
- native host startup;
- terminal session creation;
- persistent kernel creation/replacement;
- deterministic shutdown;
- runtime health snapshots for UI surfaces.

### 4. Native host protocol hardening

The previous ad-hoc JSON string scanning is removed. The native host now contains a real recursive JSON parser with:

- objects and arrays;
- escaped strings and Unicode escapes;
- booleans, null and numbers;
- duplicate-key rejection;
- structural validation.

Terminal arguments and environment maps are now preserved across IPC.

### 5. Windows ConPTY backend

Windows gets a native ConPTY implementation rather than redirected stdio. The backend owns:

- pseudo console creation and resize;
- bidirectional pipe transport;
- Unicode command lines and working directories;
- inherited environment with KET overrides;
- process suspension/attachment before execution;
- job-object process-tree ownership;
- deterministic force termination;
- Ctrl+C terminal interruption.

POSIX keeps the PTY backend and now applies environment overrides before `execvp`.

## Runtime discovery

Development overrides:

- `KET_NATIVE_HOST`
- `KET_KERNEL_SCRIPT`
- `KET_PYTHON`

Release packaging must place `ket_host(.exe)` beside the application executable or under its `bin` directory. The Python kernel script is bundled as a Flutter asset and may also be overridden in development.

## Quality policy

GitHub Actions is intentionally disabled for this repository at the owner's request. Quality gates still exist conceptually and must be run locally/release-side:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
cmake -S native/ket_host -B native/ket_host/build
cmake --build native/ket_host/build --config Release
```

## Exit criteria

This milestone is considered complete when Windows, macOS and Linux can launch the v0.3 workbench, establish a real interactive PTY session, resize it, send input/interrupts, propagate process exit, and initialize a persistent Python kernel using the same application runtime supervisor.

## Next large milestone

The next change should be another vertical slice rather than small patches:

**Editor Intelligence + Quantum Execution**

- production editor surface;
- LSP client + Pyright adapter;
- DAP client + Python debugger adapter;
- KET IR/OpenQASM 3 codec;
- local simulator backend;
- circuit/code synchronization;
- experiment persistence;
- first quantum debugger snapshot pipeline.
