# KET Studio v0.3 — Compiler + Visual Circuit + Provider Foundation

This milestone turns the quantum workbench from an execution/result surface into an engineering workflow with compiler introspection, visual circuit editing, provider discovery and noisy local simulation.

## User-visible loop

1. Open or edit OpenQASM 3 source.
2. Run through the built-in exact statevector backend.
3. Switch to the Visual Circuit surface.
4. Inspect deterministic circuit depth and gate placement.
5. Select a visual operation and delete/replace it; KET rewrites canonical OpenQASM and invalidates stale results.
6. Inspect pass-by-pass compiler metrics.
7. Inspect registered provider health and Workspace Graph lineage.

## Compiler

`BasicTranspilerInspector` is intentionally conservative. v0.3 passes are semantics-preserving and auditable:

- strip barriers;
- cancel adjacent identical self-inverse gates;
- remove literal zero rotations.

Every pass stores before/after circuits, depth, gate count, two-qubit count and notes. Provider-specific routing/placement is deliberately deferred to provider adapters rather than faked locally.

## Visual circuit

OpenQASM remains the canonical source of truth. The canvas is generated from KET IR using deterministic qubit-occupancy scheduling. Visual edits are represented as typed `CircuitEdit` values and round-trip through the OpenQASM codec.

## Providers and jobs

`QuantumProviderRegistry` owns backend registration, capability discovery, target discovery and health snapshots. Built-in providers in this milestone:

- KET Local Statevector — exact, isolate-backed, default max 16 qubits;
- KET Local Density Matrix — noisy mixed-state foundation, default max 8 qubits.

`RemoteJobStore` + `FileRemoteJobStore` provide restart-safe persistence for future IBM/AWS/Azure/vendor adapters without placing vendor objects in KET core.

## Noise envelope

The density-matrix backend supports:

- post-circuit single-qubit depolarizing channels;
- readout bit-flip errors during shot sampling;
- exact density-matrix output and normalized diagonal probabilities.

T1/T2 relaxation is explicitly rejected until a correct channel implementation lands. This is preferable to silently approximating unsupported physics.

## Workspace Graph

Each completed run can produce lineage:

`source -> circuit -> transpilation -> backend -> measurement -> result -> experiment -> artifacts`

Nodes retain hashes and execution metadata so the graph can become a reproducibility/exploration surface rather than a decorative diagram.

## Local quality gate

GitHub Actions remains disabled by repository-owner request. Before release candidates:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
cmake -S native/ket_host -B native/ket_host/build
cmake --build native/ket_host/build --config Release
```

Manual acceptance must cover code/canvas round-trip, compiler stage metrics, provider degradation, density-matrix trace normalization, noisy Bell-state probabilities, remote-job recovery and stale-result invalidation after a visual edit.

## Next large milestone

**Vendor Adapters + Experiment Lab + Production Persistence**

- Python provider bridge with versioned framed IPC;
- Qiskit, PennyLane and Cirq adapters without SDK objects crossing KET boundaries;
- remote-job polling/recovery;
- experiment browser and comparison views;
- noise-lab controls and presets;
- persisted workspace/session recovery;
- command palette/keybindings and project-wide search hardening.
