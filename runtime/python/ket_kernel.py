#!/usr/bin/env python3
from __future__ import annotations

import builtins
import contextlib
import io
import json
import os
import signal
import struct
import sys
import threading
import time
import traceback
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

PROTOCOL_VERSION = 1
MAX_FRAME = 8 * 1024 * 1024


def _read_exact(stream, count: int) -> bytes:
    data = bytearray()
    while len(data) < count:
        chunk = stream.read(count - len(data))
        if not chunk:
            raise EOFError
        data.extend(chunk)
    return bytes(data)


def read_frame() -> dict[str, Any]:
    header = _read_exact(sys.stdin.buffer, 4)
    (length,) = struct.unpack(">I", header)
    if length <= 0 or length > MAX_FRAME:
        raise ValueError("invalid frame length")
    payload = _read_exact(sys.stdin.buffer, length)
    value = json.loads(payload.decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError("frame root must be an object")
    return value


_write_lock = threading.Lock()


def write_frame(value: dict[str, Any]) -> None:
    payload = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(payload) > MAX_FRAME:
        raise ValueError("output frame too large")
    with _write_lock:
        sys.stdout.buffer.write(struct.pack(">I", len(payload)))
        sys.stdout.buffer.write(payload)
        sys.stdout.buffer.flush()


@dataclass
class Kernel:
    session_id: str
    sequence: int = 0

    def __post_init__(self) -> None:
        self.globals: dict[str, Any] = {
            "__name__": "__main__",
            "__builtins__": builtins,
        }
        self.busy = False
        self._input_condition = threading.Condition()
        self._input_value: str | None = None
        self._execution_thread: threading.Thread | None = None

    def event(self, kind: str, payload: dict[str, Any]) -> None:
        self.sequence += 1
        write_frame({
            "type": "event",
            "event": {
                "protocolVersion": PROTOCOL_VERSION,
                "sessionId": self.session_id,
                "sequence": self.sequence,
                "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                "kind": kind,
                "payload": payload,
            },
        })

    def execute(self, execution_id: str, code: str, file_name: str | None) -> None:
        if self.busy:
            raise RuntimeError("kernel is busy")
        self.busy = True

        def run() -> None:
            self.event("lifecycle", {"state": "busy", "executionId": execution_id})
            stdout = io.StringIO()
            stderr = io.StringIO()
            original_input = builtins.input

            def kernel_input(prompt: str = "") -> str:
                self.event("inputRequest", {"executionId": execution_id, "prompt": prompt})
                with self._input_condition:
                    self._input_value = None
                    while self._input_value is None:
                        self._input_condition.wait()
                    return self._input_value

            builtins.input = kernel_input
            try:
                compiled = compile(code, file_name or "<ket-cell>", "exec")
                with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                    exec(compiled, self.globals, self.globals)
                out = stdout.getvalue()
                err = stderr.getvalue()
                if out:
                    self.event("stdout", {"executionId": execution_id, "text": out})
                if err:
                    self.event("stderr", {"executionId": execution_id, "text": err})
                self.event("result", {"executionId": execution_id, "success": True})
            except BaseException as exc:
                out = stdout.getvalue()
                err = stderr.getvalue()
                if out:
                    self.event("stdout", {"executionId": execution_id, "text": out})
                if err:
                    self.event("stderr", {"executionId": execution_id, "text": err})
                self.event("error", {
                    "executionId": execution_id,
                    "type": type(exc).__name__,
                    "message": str(exc),
                    "traceback": traceback.format_exc(),
                })
            finally:
                builtins.input = original_input
                self.busy = False
                self.event("lifecycle", {"state": "idle", "executionId": execution_id})

        self._execution_thread = threading.Thread(target=run, name=f"ket-exec-{execution_id}", daemon=True)
        self._execution_thread.start()

    def provide_input(self, value: str) -> None:
        with self._input_condition:
            self._input_value = value
            self._input_condition.notify_all()

    def reset(self) -> None:
        if self.busy:
            raise RuntimeError("cannot reset a busy kernel")
        self.globals = {"__name__": "__main__", "__builtins__": builtins}
        self.event("lifecycle", {"state": "idle", "reason": "restart"})


def main() -> int:
    session_id = f"py-{uuid.uuid4().hex}"
    kernel = Kernel(session_id=session_id)
    write_frame({
        "type": "hello",
        "protocolVersion": PROTOCOL_VERSION,
        "sessionId": session_id,
        "pid": os.getpid(),
        "python": sys.version,
    })
    kernel.event("lifecycle", {"state": "idle"})

    while True:
        try:
            message = read_frame()
        except EOFError:
            return 0
        except Exception as exc:
            write_frame({"type": "fatal", "message": str(exc)})
            return 2

        request_id = str(message.get("requestId", ""))
        kind = message.get("type")
        try:
            if kind == "execute":
                kernel.execute(
                    str(message["executionId"]),
                    str(message["code"]),
                    message.get("fileName"),
                )
                write_frame({"type": "ack", "requestId": request_id})
            elif kind == "input":
                kernel.provide_input(str(message.get("value", "")))
                write_frame({"type": "ack", "requestId": request_id})
            elif kind == "restart":
                kernel.reset()
                write_frame({"type": "ack", "requestId": request_id})
            elif kind == "interrupt":
                # Safe Python thread interruption is deliberately not attempted here.
                # Host-level process signalling/restart owns hard interruption.
                write_frame({
                    "type": "error",
                    "requestId": request_id,
                    "message": "hard interrupt requires host process signalling",
                })
            elif kind == "shutdown":
                write_frame({"type": "ack", "requestId": request_id})
                return 0
            elif kind == "ping":
                write_frame({"type": "pong", "requestId": request_id, "time": time.time()})
            else:
                write_frame({"type": "error", "requestId": request_id, "message": "unsupported command"})
        except Exception as exc:
            write_frame({"type": "error", "requestId": request_id, "message": str(exc)})


if __name__ == "__main__":
    raise SystemExit(main())
