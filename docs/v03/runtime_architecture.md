# KET Studio v0.3 Runtime Architecture

KET Studio v0.3 uses explicit process and protocol boundaries so UI failures, native runtime failures, language tooling and quantum execution remain isolated.

## Process topology

```text
Flutter Workbench
  |-- TerminalService ------> NativeTerminalHost ------> ket_host ------> ConPTY / POSIX PTY
  |-- KernelService --------> KernelHost -------------> persistent Python runtime
  |-- LanguageServiceHost --> LSP server(s)
  |-- DebugAdapterHost -----> DAP adapter(s)
  |-- QuantumBackend -------> local/remote quantum provider adapter
```

## Invariants

1. Flutter widgets never own OS child-process lifecycle directly.
2. Interactive terminals always use a real PTY implementation.
3. Kernel sessions are persistent and restartable; execution is not modelled as one process per Run click.
4. LSP and DAP are isolated behind KET-owned contracts.
5. SDK/provider-specific quantum objects never cross into KET core.
6. Native-host IPC is versioned and framed.
7. Shutdown must clean up owned process trees deterministically.
8. Local quantum development remains functional without cloud or AI services.

## Failure domains

A crash in `ket_host`, an LSP server, a DAP adapter, Python kernel, or provider adapter must be recoverable without corrupting workspace state or forcing the workbench to terminate.

## Quality policy

GitHub Actions is intentionally not part of the v0.3 branch. Format, static analysis, unit tests, native builds and integration suites remain required as local/release gates and can later be wired to whichever CI system is selected.
