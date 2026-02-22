# KET Studio Event Schema Specification (v1.0)

This document defines the formal protocol used by KET Studio to communicate between the execution engine (Python) and the visualization frontend (Flutter).

## Message Format
All visualization messages must be printed to `stdout` as a single line starting with the prefix `KET_VIZ` followed by a JSON object.

**Structure:**
```json
KET_VIZ {
  "kind": "string",
  "payload": "object|array|string",
  "ts": "integer (unix timestamp ms)"
}
```

## Supported Event Kinds

### 1. `histogram`
Used for representing measurement results or probability distributions.
- **Payload:**
  - `histogram`: `Map<String, int|double>` (e.g. `{"00": 512, "11": 512}`)
  - `title`: `String` (Optional)

### 2. `heatmap`
Used for density matrices, cost landscapes, or correlation matrices.
- **Payload:**
  - `data`: `List<List<double>>` (2D Matrix)
  - `title`: `String` (Optional)

### 3. `table`
Used for structured data reporting.
- **Payload:**
  - `title`: `String`
  - `data`: `List<List<any>>` (First row is usually headers)

### 4. `image` / `circuit`
Used for static drawings or plots.
- **Payload:**
  - `path`: `String` (Relative path to the output directory or absolute path)
  - `title`: `String` (Optional)

### 5. `metrics`
Used for real-time status updates and progress tracking.
- **Payload:**
  - `progress`: `String` (e.g. "45%")
  - `status`: `String`
  - Any additional key-value pairs will be displayed in the metrics panel.

### 6. `inspector`
Used for step-by-step algorithm walkthroughs.
- **Payload:**
  - `title`: `String`
  - `frames`: `List<object>` where each frame contains:
    - `gate`: `String`
    - `state_description`: `String`
    - `bloch`: `List<{"theta": double, "phi": double}>` (One for each qubit)

### 7. `statevector`
Used for representing complex quantum states with magnitude and phase.
- **Payload:**
  - `title`: `String` (Optional)
  - `amplitudes`: `List<object>` where each object contains:
    - `label`: `String` (e.g. "00")
    - `mag`: `double` (Magnitude [0, 1])
    - `phase`: `double` (Phase in radians [-pi, pi])

---

## Technical Requirements
1. **UTF-8 Encoding**: The stdout stream must be UTF-8.
2. **Atomicity**: Each `KET_VIZ` line must be a complete JSON object.
3. **Flushing**: It is recommended to flush stdout after each visualization command to ensure real-time updates.
