# KET Studio v0.3 — Vendor Adapters + Experiment Lab + Production Persistence

This vertical milestone connects KET Studio to optional external quantum SDKs while keeping the KET domain model vendor-neutral, and turns previously transient workbench state into restart-safe engineering state.

## Product loop

1. KET boots and restores open/dirty documents, selected backend/target, active workbench section, panel visibility and noise preset from `.ket/session`.
2. Built-in statevector and density-matrix providers register immediately.
3. If the bundled Python provider bridge is discoverable, Qiskit, PennyLane and Cirq adapters register as optional providers.
4. Provider health probes the selected Python environment. Missing SDKs degrade only their own adapter.
5. OpenQASM is parsed into KET IR. The selected backend receives a normalized execution request; vendor SDK objects never cross the bridge.
6. Results persist as experiment records/artifacts and appear in Experiment Lab.
7. Two experiments can be compared using source/backend identity, total-variation distance, maximum probability delta, shot delta and artifact changes.
8. Project Search scans source files in an isolate and excludes generated/vendor directories.
9. Command Palette and keyboard shortcuts expose file/run/search/experiment/provider operations without coupling commands to widget internals.

## Python provider bridge

`runtime/python/ket_provider_bridge.py` uses the same length-prefixed framing philosophy as the persistent kernel:

```text
uint32 big-endian JSON length
UTF-8 JSON object
```

Protocol version: `1`.

Supported vendors in this milestone:

- **Qiskit** — circuit construction plus `qiskit.quantum_info.Statevector` execution;
- **PennyLane** — `default.qubit` state execution;
- **Cirq** — `cirq.Simulator` state execution.

The bridge receives KET IR rather than raw vendor objects. The normalized response contains counts, probabilities, complex statevector pairs and plain metadata.

The adapters intentionally advertise simulator targets only. Real IBM/AWS/Azure hardware credentials and provider-specific remote APIs require dedicated authenticated adapters; KET does not fake hardware support.

## Provider isolation

The bridge is optional. KET local engines remain usable when Python, Qiskit, PennyLane or Cirq are unavailable. Each vendor backend is independently health-checked by `QuantumProviderRegistry`.

A provider failure must not terminate:

- the workbench;
- terminal sessions;
- the Python execution kernel;
- local quantum backends;
- other vendor adapters.

## Experiment Lab

`ExperimentLab` loads persisted `quantum-result` artifacts and compares normalized distributions.

Comparison metrics:

- source revision equality;
- backend/target equality;
- total-variation distance;
- maximum per-outcome probability delta;
- shot-count delta;
- artifact hash changes.

The comparison operates on exact probabilities when available and falls back to normalized counts.

## Noise Lab

Built-in presets:

- `ideal`;
- `nisq-light`;
- `nisq-heavy`.

Presets use only noise channels currently implemented by the local density-matrix engine: depolarizing and readout errors. T1/T2 relaxation remains explicitly unsupported rather than silently approximated.

## Workspace recovery

Recovery state is stored separately from source files under `.ket/session/workspace-session.json`.

It preserves:

- open document IDs/titles/languages/paths;
- current text and last-saved text independently;
- dirty state across restart;
- active document;
- active workbench section;
- bottom panel and inspector visibility;
- selected quantum backend/target;
- selected noise preset.

Writes are atomic (`.tmp` + rename) and debounced. Corrupt recovery state is isolated and does not block startup.

## Remote jobs

`RemoteJobCoordinator` periodically reloads non-terminal `RemoteJobRecord` values and asks the registered backend for current state. Successful or failed recovery attempts are persisted with recovery metadata.

The current vendor bridge adapters are local simulator adapters and therefore do not advertise `supportsRemoteJobs`. The coordinator is the durable substrate for later authenticated cloud/hardware providers.

## Command/Search ergonomics

Default shortcuts in the milestone:

- `Ctrl/Cmd+Shift+P` — Command Palette;
- `Ctrl/Cmd+Shift+F` — Project Search;
- `Ctrl/Cmd+O` — Open;
- `Ctrl/Cmd+S` — Save;
- `Ctrl/Cmd+R` — Run;
- `F5` — Python debug.

Project search runs outside the UI isolate, caps file size/result count and skips `.git`, `.ket`, `.dart_tool`, `build`, `dist`, `node_modules`, `.idea` and `.vscode`.

## Local release gate

GitHub Actions remains disabled by repository-owner request. Before a release candidate, run on Windows, macOS and Linux:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
python3 -m py_compile runtime/python/ket_kernel.py runtime/python/ket_provider_bridge.py
cmake -S native/ket_host -B native/ket_host/build
cmake --build native/ket_host/build --config Release
```

Manual acceptance must additionally cover:

- restart with dirty untitled and saved files;
- provider bridge probe with zero, one and multiple vendor SDKs installed;
- Bell-state agreement across local/Qiskit/PennyLane/Cirq backends within numerical tolerance;
- unavailable provider isolation;
- noise preset execution on density-matrix backend;
- experiment comparison after restart;
- remote-job recovery with a reconnectable fake/test provider;
- command palette and keyboard shortcuts;
- project search on a large source tree.

## Next vertical milestone

**Production Hardening + Release Engineering**

- package/runtime bundling for Windows/macOS/Linux;
- native host and Python bridge executable discovery from packaged assets;
- structured logs, crash reports and support bundle export;
- settings/security/credential storage boundary;
- plugin signing/trust policy and sandbox limits;
- file watching/external-change merge handling;
- terminal and kernel stress/integration suites;
- accessibility, command/keybinding customization and UI performance profiling;
- release candidate checklist and installer validation.
