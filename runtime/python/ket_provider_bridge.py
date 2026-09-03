#!/usr/bin/env python3
from __future__ import annotations

import importlib
import importlib.metadata
import json
import math
import os
import random
import struct
import sys
import threading
import traceback
from typing import Any

PROTOCOL_VERSION = 1
MAX_FRAME = 16 * 1024 * 1024
WRITE_LOCK = threading.Lock()


def _read_exact(count: int) -> bytes:
    data = bytearray()
    while len(data) < count:
        chunk = sys.stdin.buffer.read(count - len(data))
        if not chunk:
            raise EOFError
        data.extend(chunk)
    return bytes(data)


def read_frame() -> dict[str, Any]:
    header = _read_exact(4)
    (length,) = struct.unpack(">I", header)
    if length <= 0 or length > MAX_FRAME:
        raise ValueError("invalid frame length")
    payload = _read_exact(length)
    value = json.loads(payload.decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError("frame root must be an object")
    return value


def write_frame(value: dict[str, Any]) -> None:
    payload = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(payload) > MAX_FRAME:
        raise ValueError("output frame too large")
    with WRITE_LOCK:
        sys.stdout.buffer.write(struct.pack(">I", len(payload)))
        sys.stdout.buffer.write(payload)
        sys.stdout.buffer.flush()


def package_version(name: str) -> str | None:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return None


def vendor_probe(vendor: str) -> dict[str, Any]:
    package = {"qiskit": "qiskit", "pennylane": "pennylane", "cirq": "cirq"}[vendor]
    version = package_version(package)
    return {
        "vendor": vendor,
        "available": version is not None,
        "version": version,
        "targets": _targets(vendor) if version is not None else [],
    }


def _targets(vendor: str) -> list[dict[str, Any]]:
    if vendor == "qiskit":
        return [{
            "id": "qiskit.statevector",
            "name": "Qiskit Statevector",
            "qubitCount": 24,
            "isSimulator": True,
            "metadata": {"engine": "qiskit.quantum_info.Statevector"},
        }]
    if vendor == "pennylane":
        return [{
            "id": "pennylane.default-qubit",
            "name": "PennyLane default.qubit",
            "qubitCount": 20,
            "isSimulator": True,
            "metadata": {"engine": "default.qubit"},
        }]
    return [{
        "id": "cirq.simulator",
        "name": "Cirq Simulator",
        "qubitCount": 24,
        "isSimulator": True,
        "metadata": {"engine": "cirq.Simulator"},
    }]


def _resolve_parameter(value: Any, parameters: dict[str, float]) -> float:
    if not isinstance(value, dict):
        raise ValueError("invalid KET parameter")
    kind = value.get("kind")
    if kind == "literal":
        return float(value["value"])
    if kind == "symbol":
        name = str(value["name"])
        if name not in parameters:
            raise ValueError(f"missing parameter {name}")
        return float(parameters[name])
    raise ValueError(f"unsupported parameter kind {kind}")


def _validate_ir(ir: dict[str, Any]) -> tuple[int, int, list[dict[str, Any]]]:
    if ir.get("version") != 1:
        raise ValueError("unsupported KET IR version")
    qubits = int(ir["qubitCount"])
    bits = int(ir.get("classicalBitCount", 0))
    operations = ir.get("operations")
    if qubits <= 0 or bits < 0 or not isinstance(operations, list):
        raise ValueError("invalid KET IR")
    return qubits, bits, operations


def _measurement_map(operations: list[dict[str, Any]], classical_bits: int) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    for operation in operations:
        if operation.get("kind") == "measure":
            result.append((int(operation["qubit"]), int(operation["classicalBit"])))
    if result and classical_bits <= 0:
        raise ValueError("measurements require classical bits")
    return result


def _sample_counts(
    probabilities: list[float],
    qubit_count: int,
    classical_bits: int,
    measurements: list[tuple[int, int]],
    shots: int,
    seed: int | None,
) -> dict[str, int]:
    rng = random.Random(seed)
    total = sum(probabilities)
    if abs(total - 1.0) > 1e-7:
        raise ValueError(f"statevector is not normalized: {total}")
    cumulative: list[float] = []
    cursor = 0.0
    for probability in probabilities:
        cursor += probability
        cumulative.append(cursor)

    counts: dict[str, int] = {}
    for _ in range(shots):
        value = rng.random() * cursor
        selected = len(cumulative) - 1
        lo, hi = 0, len(cumulative) - 1
        while lo <= hi:
            mid = (lo + hi) // 2
            if value < cumulative[mid]:
                selected = mid
                hi = mid - 1
            else:
                lo = mid + 1
        if measurements:
            bits = [0] * classical_bits
            for qubit, classical in measurements:
                bits[classical] = (selected >> qubit) & 1
            key = "".join(str(bits[i]) for i in range(len(bits) - 1, -1, -1))
        else:
            key = format(selected, f"0{qubit_count}b")
        counts[key] = counts.get(key, 0) + 1
    return counts


def _normalize_statevector(values: Any) -> list[complex]:
    result: list[complex] = []
    for value in values:
        result.append(complex(value))
    norm = sum((v.real * v.real + v.imag * v.imag) for v in result)
    if norm <= 0:
        raise ValueError("empty statevector")
    if abs(norm - 1.0) > 1e-7:
        scale = 1 / math.sqrt(norm)
        result = [v * scale for v in result]
    return result


def _apply_qiskit(ir: dict[str, Any], parameters: dict[str, float]) -> list[complex]:
    qiskit = importlib.import_module("qiskit")
    qi = importlib.import_module("qiskit.quantum_info")
    qubit_count, _, operations = _validate_ir(ir)
    circuit = qiskit.QuantumCircuit(qubit_count)
    for operation in operations:
        kind = operation.get("kind")
        if kind in ("measure", "barrier"):
            continue
        if kind != "gate":
            raise ValueError(f"unsupported operation {kind}")
        name = str(operation["name"])
        targets = [int(v) for v in operation.get("qubits", [])]
        controls = [int(v) for v in operation.get("controls", [])]
        params = [_resolve_parameter(v, parameters) for v in operation.get("parameters", [])]
        if name == "swap":
            circuit.swap(targets[0], targets[1])
        elif controls:
            if name == "x" and len(controls) == 1:
                circuit.cx(controls[0], targets[0])
            elif name == "x" and len(controls) == 2:
                circuit.ccx(controls[0], controls[1], targets[0])
            elif name == "z" and len(controls) == 1:
                circuit.cz(controls[0], targets[0])
            else:
                raise ValueError(f"unsupported controlled gate {name}/{len(controls)}")
        else:
            method = getattr(circuit, name, None)
            if method is None:
                raise ValueError(f"unsupported qiskit gate {name}")
            method(*params, *targets)
    state = qi.Statevector.from_instruction(circuit)
    return _normalize_statevector(state.data)


def _apply_pennylane(ir: dict[str, Any], parameters: dict[str, float]) -> list[complex]:
    qml = importlib.import_module("pennylane")
    qubit_count, _, operations = _validate_ir(ir)
    wire_order = list(range(qubit_count - 1, -1, -1))
    device = qml.device("default.qubit", wires=wire_order)

    @qml.qnode(device)
    def circuit() -> Any:
        for operation in operations:
            kind = operation.get("kind")
            if kind in ("measure", "barrier"):
                continue
            if kind != "gate":
                raise ValueError(f"unsupported operation {kind}")
            name = str(operation["name"])
            targets = [int(v) for v in operation.get("qubits", [])]
            controls = [int(v) for v in operation.get("controls", [])]
            params = [_resolve_parameter(v, parameters) for v in operation.get("parameters", [])]
            if name == "swap":
                qml.SWAP(wires=targets)
            elif controls:
                if name == "x" and len(controls) == 1:
                    qml.CNOT(wires=[controls[0], targets[0]])
                elif name == "x" and len(controls) == 2:
                    qml.Toffoli(wires=[controls[0], controls[1], targets[0]])
                elif name == "z" and len(controls) == 1:
                    qml.CZ(wires=[controls[0], targets[0]])
                else:
                    raise ValueError(f"unsupported controlled gate {name}/{len(controls)}")
            else:
                gate = {
                    "x": qml.PauliX,
                    "y": qml.PauliY,
                    "z": qml.PauliZ,
                    "h": qml.Hadamard,
                    "s": qml.S,
                    "t": qml.T,
                    "rx": qml.RX,
                    "ry": qml.RY,
                    "rz": qml.RZ,
                }.get(name)
                if name == "sdg":
                    qml.adjoint(qml.S)(wires=targets[0])
                elif name == "tdg":
                    qml.adjoint(qml.T)(wires=targets[0])
                elif gate is None:
                    raise ValueError(f"unsupported pennylane gate {name}")
                elif params:
                    gate(*params, wires=targets[0])
                else:
                    gate(wires=targets[0])
        return qml.state()

    return _normalize_statevector(circuit())


def _apply_cirq(ir: dict[str, Any], parameters: dict[str, float]) -> list[complex]:
    cirq = importlib.import_module("cirq")
    qubit_count, _, operations = _validate_ir(ir)
    qubits = [cirq.LineQubit(i) for i in range(qubit_count)]
    circuit = cirq.Circuit()
    for operation in operations:
        kind = operation.get("kind")
        if kind in ("measure", "barrier"):
            continue
        if kind != "gate":
            raise ValueError(f"unsupported operation {kind}")
        name = str(operation["name"])
        targets = [int(v) for v in operation.get("qubits", [])]
        controls = [int(v) for v in operation.get("controls", [])]
        params = [_resolve_parameter(v, parameters) for v in operation.get("parameters", [])]
        if name == "swap":
            op = cirq.SWAP(qubits[targets[0]], qubits[targets[1]])
        elif controls:
            if name == "x" and len(controls) == 1:
                op = cirq.CNOT(qubits[controls[0]], qubits[targets[0]])
            elif name == "x" and len(controls) == 2:
                op = cirq.TOFFOLI(qubits[controls[0]], qubits[controls[1]], qubits[targets[0]])
            elif name == "z" and len(controls) == 1:
                op = cirq.CZ(qubits[controls[0]], qubits[targets[0]])
            else:
                raise ValueError(f"unsupported controlled gate {name}/{len(controls)}")
        else:
            target = qubits[targets[0]]
            op = {
                "x": cirq.X(target),
                "y": cirq.Y(target),
                "z": cirq.Z(target),
                "h": cirq.H(target),
                "s": cirq.S(target),
                "sdg": (cirq.S ** -1)(target),
                "t": cirq.T(target),
                "tdg": (cirq.T ** -1)(target),
            }.get(name)
            if name == "rx":
                op = cirq.rx(params[0])(target)
            elif name == "ry":
                op = cirq.ry(params[0])(target)
            elif name == "rz":
                op = cirq.rz(params[0])(target)
            if op is None:
                raise ValueError(f"unsupported cirq gate {name}")
        circuit.append(op)
    simulator = cirq.Simulator()
    result = simulator.simulate(circuit, qubit_order=list(reversed(qubits)))
    return _normalize_statevector(result.final_state_vector)


def execute(vendor: str, message: dict[str, Any]) -> dict[str, Any]:
    ir = message.get("program")
    if not isinstance(ir, dict):
        raise ValueError("program must be KET IR object")
    parameters_raw = message.get("parameters") or {}
    if not isinstance(parameters_raw, dict):
        raise ValueError("parameters must be an object")
    parameters = {str(k): float(v) for k, v in parameters_raw.items()}
    shots = int(message.get("shots", 1024))
    if shots <= 0 or shots > 10_000_000:
        raise ValueError("shots out of range")
    seed_raw = message.get("seed")
    seed = None if seed_raw is None else int(seed_raw)

    qubit_count, classical_bits, operations = _validate_ir(ir)
    if vendor == "qiskit":
        state = _apply_qiskit(ir, parameters)
    elif vendor == "pennylane":
        state = _apply_pennylane(ir, parameters)
    elif vendor == "cirq":
        state = _apply_cirq(ir, parameters)
    else:
        raise ValueError(f"unknown vendor {vendor}")

    probabilities = [v.real * v.real + v.imag * v.imag for v in state]
    measurements = _measurement_map(operations, classical_bits)
    counts = _sample_counts(probabilities, qubit_count, classical_bits, measurements, shots, seed)
    probability_map = {
        format(i, f"0{qubit_count}b"): probability
        for i, probability in enumerate(probabilities)
        if probability > 1e-14
    }
    return {
        "vendor": vendor,
        "targetId": str(message.get("targetId", "")),
        "counts": counts,
        "probabilities": probability_map,
        "statevector": [[v.real, v.imag] for v in state],
        "metadata": {
            "bridgeProtocol": PROTOCOL_VERSION,
            "vendorVersion": package_version({
                "qiskit": "qiskit",
                "pennylane": "pennylane",
                "cirq": "cirq",
            }[vendor]),
            "pid": os.getpid(),
        },
    }


def main() -> int:
    write_frame({
        "type": "hello",
        "protocolVersion": PROTOCOL_VERSION,
        "pid": os.getpid(),
        "python": sys.version,
    })
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
            if kind == "probe":
                requested = message.get("vendor")
                vendors = [str(requested)] if requested else ["qiskit", "pennylane", "cirq"]
                write_frame({
                    "type": "probeResult",
                    "requestId": request_id,
                    "providers": [vendor_probe(v) for v in vendors],
                })
            elif kind == "execute":
                vendor = str(message["vendor"])
                if package_version({"qiskit": "qiskit", "pennylane": "pennylane", "cirq": "cirq"}[vendor]) is None:
                    raise RuntimeError(f"{vendor} is not installed in the selected Python environment")
                write_frame({
                    "type": "executionResult",
                    "requestId": request_id,
                    "result": execute(vendor, message),
                })
            elif kind == "ping":
                write_frame({"type": "pong", "requestId": request_id})
            elif kind == "shutdown":
                write_frame({"type": "ack", "requestId": request_id})
                return 0
            else:
                raise ValueError(f"unsupported command {kind}")
        except Exception as exc:
            write_frame({
                "type": "error",
                "requestId": request_id,
                "message": str(exc),
                "traceback": traceback.format_exc(),
            })


if __name__ == "__main__":
    raise SystemExit(main())
