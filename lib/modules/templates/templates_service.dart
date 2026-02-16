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
      id: 'bell_state_inspector',
      title: 'Bell State (Inspector)',
      description: 'Step-by-step analysis of creating entanglement.',
      icon: FluentIcons.reading_mode,
      content: '''import math
import time

print("Analyzing Bell State preparation...")

# Define frames for step-by-step visualization
frames = [
    {"gate": "Init", "description": "Start at |00>", "bloch": [{"theta": 0, "phi": 0}, {"theta": 0, "phi": 0}]},
    {"gate": "H q0", "description": "Qubit 0 into superposition", "bloch": [{"theta": math.pi/2, "phi": 0}, {"theta": 0, "phi": 0}]},
    {"gate": "CNOT q0,q1", "description": "Entanglement created", "bloch": [{"theta": math.pi/2, "phi": 0}, {"theta": math.pi/2, "phi": 0}]}
]

ket_inspector("Bell State Process", frames)
ket_histogram({"00": 512, "11": 512}, title="Final Measurement")
print("Data sent to Inspector and Visualizer.")''',
    ),
    QuantumTemplate(
      id: 'grover_search',
      title: "Grover's Search",
      description: 'Visualization of amplitude amplification iterations.',
      icon: FluentIcons.search_and_apps,
      content: '''import math
import time

print("Running Grover's Algorithm Demo...")

# 1. Show final histogram
for i in range(1, 4):
    prob = 0.3 * i
    results = {"101": int(1024 * prob), "others": int(1024 * (1-prob)/7)}
    ket_histogram(results, title=f"Iteration {i}")
    time.sleep(0.5)

# 2. Show internal state for one step
ket_inspector("Grover State", [
    {"gate": "Oracle", "description": "Target state marked with negative phase", "bloch": [{"theta": math.pi/2, "phi": math.pi}]}
])
''',
    ),
    QuantumTemplate(
      id: 'vqe_optimization',
      title: "VQE Optimizer",
      description: 'Track energy convergence in the Dashboard.',
      icon: FluentIcons.test_beaker,
      content: '''import time

print("VQE Energy Minimization...")

for i in range(10):
    energy = -1.13 + (1.0/(i+1))
    print(f"Step {i}: Energy = {energy:.4f} Ha")
    ket_text(f"Iteration {i}: Energy {energy:.4f}")
    time.sleep(0.3)

ket_text("Optimization Complete: -1.136 Ha")''',
    ),
    QuantumTemplate(
      id: 'qaoa_landscape',
      title: "QAOA Landscape",
      description: 'Heatmap visualization of the cost function.',
      icon: FluentIcons.iot,
      content: '''print("Generating QAOA Cost Landscape...")

matrix = [
    [0.1, 0.2, 0.8, 0.3],
    [0.2, 0.9, 0.1, 0.1],
    [0.8, 0.1, 0.0, 0.7],
    [0.3, 0.1, 0.7, 0.2]
]

ket_heatmap(matrix, title="QAOA Optimization Surface")
print("Landscape data sent.")''',
    ),
    QuantumTemplate(
      id: 'quantum_teleportation',
      title: "Quantum Teleportation",
      description: 'Comprehensive inspector demonstration with 3 qubits.',
      icon: FluentIcons.cell_phone,
      content: '''import math

print("Visualizing Teleportation Circuit...")

frames = [
    {
        "gate": "Alice State", 
        "description": "Prepare state to be teleported", 
        "bloch": [{"theta": 1.2, "phi": 0.5}, {"theta": 0, "phi": 0}, {"theta": 0, "phi": 0}]
    },
    {
        "gate": "Entangle", 
        "description": "Create Bell pair between Alice and Bob", 
        "bloch": [{"theta": 1.2, "phi": 0.5}, {"theta": math.pi/2, "phi": 0}, {"theta": math.pi/2, "phi": 0}]
    },
    {
        "gate": "Teleport", 
        "description": "State transferred to Bob's qubit (q2)", 
        "bloch": [{"theta": 0, "phi": 0}, {"theta": 0, "phi": 0}, {"theta": 1.2, "phi": 0.5}]
    }
]

ket_inspector("Teleportation Protocol", frames)''',
    ),
    QuantumTemplate(
      id: 'noise_simulation',
      title: "Noise Analysis",
      description: 'Dashboard histogram for noisy qubits.',
      icon: FluentIcons.error_badge,
      content: '''import random

print("Simulating T1/T2 Noise...")
results = {"00": 450, "11": 450, "10": 60, "01": 64}
ket_histogram(results, title="Noisy Bell State")
print("Noise profile sent to visualizer.")''',
    ),
  ];

  static void useTemplate(QuantumTemplate template) {
    EditorService().openFile("${template.id}.py", template.content);
  }
}
