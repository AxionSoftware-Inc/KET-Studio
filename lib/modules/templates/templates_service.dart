import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/editor_service.dart';

class QuantumTemplate {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String content;

  QuantumTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.content,
  });
}

class TemplateService {
  static final List<QuantumTemplate> templates = [
    QuantumTemplate(
      id: 'bell_state_demo',
      title: 'Bell State (Entanglement)',
      description: 'The fundamental example of quantum entanglement.',
      icon: FluentIcons.reading_mode,
      content: '''# === Dynamic Metrics Demo ===
import math, ket_viz

# 1. Measurement
results = {"00": 512, "11": 512}
ket_viz.histogram(results, title="Bell State Results")

# 2. Dynamic Metrics (Any key works!)
ket_viz.metrics({
    "qubit_count": 2,
    "gate_depth": 3,
    "simulation_backend": "AerSimulator",
    "execution_time_ms": 12.5,
    "fidelity_score": 0.998,
    "random_seed": 42
})
''',
    ),
    QuantumTemplate(
      id: 'vqe_optimizer',
      title: "VQE Optimizer",
      description: 'Track energy minimization in real-time.',
      icon: FluentIcons.test_beaker,
      content: '''# === VQE Optimization ===
import time, ket_viz

energies = []
for i in range(20):
    e = -1.137 + (1.5 / (i + 1))
    energies.append(e)
    ket_viz.chart([(x + 2)/4 for x in energies])
    time.sleep(0.1)

# Report final optimization metrics
ket_viz.metrics({
    "optimizer": "COBYLA",
    "final_energy": energies[-1],
    "iterations": 20,
    "convergence": "Stable",
    "hardware_target": "FakeGuadalupe"
})
''',
    ),
    QuantumTemplate(
      id: 'grover_search',
      title: "Grover's Algorithm",
      description: 'Quantum search algorithm simulation.',
      icon: FluentIcons.search_and_apps,
      content: '''# === Grover's Search ===
import ket_viz

# Metrics can be sent at any time!
ket_viz.metrics({
    "search_space": 8,
    "target_bitstring": "101",
    "required_steps": 2
})

results = {"101": 950, "others": 74}
ket_viz.histogram(results, title="Grover Output")
''',
    ),
    QuantumTemplate(
      id: 'qaoa_landscape',
      title: "QAOA Cost Landscape",
      description: '2D Heatmap of the optimization surface.',
      icon: FluentIcons.iot,
      content: '''# === QAOA Landscape ===
import ket_viz

ket_viz.heatmap([
    [0.1, 0.5, 0.2],
    [0.4, 0.9, 0.3],
    [0.3, 0.2, 0.1]
], title="QAOA Surface")

ket_viz.metrics({
    "problem_type": "Max-Cut",
    "nodes": 6,
    "parameters": "beta, gamma",
    "status": "Plot Generated"
})
''',
    ),
    QuantumTemplate(
      id: 'teleportation_protocol',
      title: "Quantum Teleportation",
      description: 'Send qubit state using entanglement.',
      icon: FluentIcons.cell_phone,
      content: '''# === Teleportation ===
import ket_viz

ket_viz.metrics({
    "protocol": "Standard teleport",
    "communication": "Classical + Quantum",
    "secure": True
})

ket_viz.text("Teleportation protocol completed successfully.")
''',
    ),
    QuantumTemplate(
      id: 'error_correction',
      title: "Error Correction",
      description: '3-qubit bit-flip code simulation.',
      icon: FluentIcons.error_badge,
      content: '''# === Error Correction ===
import ket_viz

ket_viz.histogram({"000": 900, "100": 100}, title="Before Correction")

ket_viz.metrics({
    "coding_scheme": "3-qubit-bitflip",
    "error_type": "Bit Flip",
    "correction_status": "Successful"
})
''',
    ),
    QuantumTemplate(
      id: 'qft_transform',
      title: "Quantum Fourier Transform",
      description: 'Rotation phases of the QFT.',
      icon: FluentIcons.music_note,
      content: '''# === QFT ===
import ket_viz

ket_viz.metrics({
    "algorithm": "QFT",
    "complexity": "log(N)",
    "application": "Shor's / Phase Estimation"
})

ket_viz.text("QFT logic loaded.")
''',
    ),
    QuantumTemplate(
      id: 'quantum_benchmarker',
      title: "Quantum Benchmarker",
      description: 'Test resource estimation and massive qubit visualization.',
      icon: FluentIcons.speed_high,
      content: '''# === Quantum Benchmarker ===
import ket_viz, math

# 1. Resource Estimation
ket_viz.estimator({
    "qubits": 20,
    "depth": 145,
    "total_gates": 1240,
    "gate_counts": {
        "CNOT": 450,
        "H": 300,
        "RX": 200,
        "RZ": 290
    }
})

# 2. Massive Qubit State Visualization
# We'll send 20 qubits with different rotation phases
bloch_data = []
for i in range(20):
    bloch_data.append({
        "theta": (math.pi / 20) * i,
        "phi": (math.pi / 10) * i
    })

ket_viz.bloch(bloch_data)

ket_viz.metrics({
    "benchmark": "Complexity Test",
    "qubit_density": "High",
    "viz_mode": "Adaptive Grid"
})
''',
    ),
  ];

  static void useTemplate(QuantumTemplate template) {
    EditorService().openFile("${template.id}.py", template.content);
  }
}
