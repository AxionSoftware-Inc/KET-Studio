# KET Studio v0.3 — Editor Intelligence + Quantum Execution

This milestone is intentionally delivered as one vertical slice.

## User-visible loop

- Edit real Python/OpenQASM files in a multi-document workbench.
- Open/save files from the desktop filesystem.
- Python intelligence uses Pyright over stdio JSON-RPC when installed.
- Python Run uses the persistent KET kernel; Debug uses debugpy/DAP when installed.
- OpenQASM 3 lowers to KET IR and runs in the built-in exact statevector simulator.
- Quantum execution produces seeded shot counts, exact probabilities and statevector data.
- Quantum Debugger steps operation-by-operation and exposes Bloch vectors, qubit purity and two-qubit concurrence.
- Reproducible experiment records and hashed result/source artifacts persist under `.ket/experiments`.

## Supported local quantum envelope

The built-in exact simulator defaults to 16 qubits. It deliberately refuses larger exact workloads instead of risking unbounded memory growth. Larger circuits are delegated to provider/simulator adapters in the next milestone.

The OpenQASM subset includes `qubit[n]`, `bit[n]`, barriers, terminal measurement, and gates `x/y/z/h/s/sdg/t/tdg/rx/ry/rz/cx/cz/ccx/swap`. Mid-circuit measurement followed by more gates is rejected until collapse/branch semantics are implemented correctly.

## Failure isolation

Pyright and debugpy are optional. Their absence degrades only language/debug features. Local quantum execution has no Qiskit/Cirq/PennyLane dependency and runs in a worker isolate so exact simulation does not block the Flutter UI isolate.

## Local release gate

GitHub Actions remains disabled by repository-owner request. Run before release candidates on Windows, macOS and Linux:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
cmake -S native/ket_host -B native/ket_host/build
cmake --build native/ket_host/build --config Release
```

Manual acceptance must include interactive PTY usage, Python kernel state persistence, Pyright diagnostics, debugpy startup/termination, Bell-state exact probabilities and shots, quantum debugger concurrence, and experiment recovery after app restart.

## Next milestone

**Provider + Compiler + Visual Circuit**: circuit canvas/code synchronization, transpiler pass graph, density-matrix/noise engine, Qiskit/PennyLane/Cirq adapters, provider registry/remote-job persistence, richer experiment browser, Workspace Graph and plugin-loading security policy.
