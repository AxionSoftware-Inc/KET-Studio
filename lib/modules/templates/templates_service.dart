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
      id: 'bell_state_dynamic',
      title: 'Bell State (Dynamic)',
      description:
          'Standard entanglement with dynamic metrics and inspector steps.',
      icon: FluentIcons.reading_mode,
      content: '''# === KET Studio Standard: Entanglement ===
import ket_viz, math, time

# 1. Resource Estimation
ket_viz.estimator({
    "qubits": 2,
    "depth": 3,
    "total_gates": 2,
    "gate_counts": {"H": 1, "CNOT": 1}
})

# 2. Step-by-Step Inspection
ket_viz.inspector("Entanglement Protocol", [
    {"gate": "Initial", "state_description": "System starts in |00>", "bloch": [{"theta":0,"phi":0}, {"theta":0,"phi":0}]},
    {"gate": "H(0)", "state_description": "Qubit 0 in superposition", "bloch": [{"theta":math.pi/2,"phi":0}, {"theta":0,"phi":0}]},
    {"gate": "CNOT(0,1)", "state_description": "Bell State |Φ+> = (|00>+|11>)/√2", "bloch": [{"theta":math.pi/2,"phi":0}, {"theta":math.pi/2,"phi":0}]}
])

# 3. Final Execution Metrics
ket_viz.metrics({
    "fidelity": 0.9997,
    "coherence_time_us": 150,
    "gate_error_rate": 0.0001,
    "backend": "KET Virtual QPU"
})

ket_viz.histogram({"00": 510, "11": 514}, title="Bell State Measurement")
''',
    ),
    QuantumTemplate(
      id: 'grover_professional',
      title: "Grover's Search (Pro)",
      description: 'Professional search algorithm with adaptive metrics.',
      icon: FluentIcons.search_and_apps,
      content: '''# === KET Studio Standard: Grover's Search ===
import ket_viz, math, time

def run_grover(target="101", n_qubits=3):
    print(f"Initializing Grover Search for target: {target}")
    
    # Estimation based on n_qubits
    num_states = 2**n_qubits
    iterations = math.floor(math.pi/4 * math.sqrt(num_states))
    
    ket_viz.estimator({
        "qubits": n_qubits,
        "depth": iterations * 10,
        "total_gates": iterations * 25,
        "gate_counts": {"H": n_qubits + 2, "X": 4, "MCZ": iterations}
    })

    # Progress tracking in Metrics
    for i in range(iterations):
        progress = (i + 1) / iterations * 100
        ket_viz.metrics({
            "phase": "Searching",
            "iteration": f"{i+1}/{iterations}",
            "completion": f"{progress:.1f}%",
            "current_amplification": f"{math.sin((2*i+1)*math.asin(1/math.sqrt(num_states))):.3f}"
        })
        time.sleep(0.5)

    # Final Result
    results = {target: 942, "others": 71}
    ket_viz.histogram(results, title=f"Grover Result (k={iterations})")
    
    ket_viz.metrics({
        "status": "SUCCESS",
        "search_efficiency": "O(√N)",
        "optimal_iterations": iterations
    })

run_grover("101", 3)
''',
    ),
    QuantumTemplate(
      id: 'vqe_realtime',
      title: "VQE Real-time Optimizer",
      description: 'Dynamic VQE simulation with energy tracking.',
      icon: FluentIcons.test_beaker,
      content: '''# === KET Studio Standard: VQE Optimization ===
import ket_viz, math, random, time

def simulate_vqe():
    target_energy = -1.1372 # H2 Molecule ground state
    current_energy = 0.5
    
    ket_viz.estimator({
        "qubits": 4,
        "depth": 45,
        "total_gates": 120,
        "gate_counts": {"RY": 16, "CZ": 8, "R": 96}
    })

    energies = []
    for step in range(30):
        # Simulated optimization step
        diff = (current_energy - target_energy) * 0.2
        current_energy -= diff + random.uniform(-0.01, 0.01)
        energies.append(current_energy)
        
        # Update Chart & Metrics live
        ket_viz.chart(energies)
        ket_viz.metrics({
            "step": step,
            "optimizer": "SLSQP",
            "energy_ha": f"{current_energy:.5f}",
            "convergence": f"{abs(diff):.6f}"
        })
        time.sleep(0.1)

    ket_viz.metrics({
        "final_energy": f"{energies[-1]:.5f}",
        "chemical_accuracy": "Achieved" if abs(energies[-1]-target_energy) < 0.0016 else "Pending",
        "total_iterations": 30
    })

simulate_vqe()
''',
    ),
    QuantumTemplate(
      id: 'qaoa_surface_pro',
      title: "QAOA Optimization Surface",
      description: 'Professional Max-Cut QAOA with landscape visualization.',
      icon: FluentIcons.iot,
      content: '''# === KET Studio Standard: QAOA Surface ===
import ket_viz, math

def generate_landscape(size=10):
    # Generating a 2D cost landscape for beta/gamma parameters
    landscape = []
    for i in range(size):
        row = []
        for j in range(size):
            # Simulated Max-Cut cost function
            val = math.sin(i/3) * math.cos(j/3) + random.uniform(0, 0.1)
            row.append(abs(val))
        landscape.append(row)
    return landscape

import random
data = generate_landscape(15)

ket_viz.heatmap(data, title="Max-Cut Cost Landscape (p=1)")

ket_viz.metrics({
    "problem": "Max-Cut",
    "nodes": 12,
    "edges": 24,
    "optimal_beta": 0.452,
    "optimal_gamma": 1.120,
    "approximation_ratio": 0.876
})

ket_viz.estimator({
    "qubits": 12,
    "depth": 24,
    "total_gates": 156,
    "gate_counts": {"ZZ": 24, "RX": 12, "H": 12}
})
''',
    ),
    QuantumTemplate(
      id: 'quantum_volume_benchmark',
      title: "Quantum Volume Benchmark",
      description: 'Benchmark system stability and gate fidelity.',
      icon: FluentIcons.test_beaker,
      content: '''# === KET Studio Professional Benchmark ===
import ket_viz, time, random

def run_benchmark(n_qubits=5):
    print(f"Starting Quantum Volume benchmark for {n_qubits} qubits...")
    
    ket_viz.metrics({"status": "Initializing", "qubits": n_qubits})
    
    # 1. Resource Estimation
    ket_viz.estimator({
        "qubits": n_qubits,
        "depth": n_qubits**2,
        "total_gates": n_qubits**3,
        "gate_counts": {"SU(4)": n_qubits**2, "Random": n_qubits}
    })

    # 2. Heavy Output Simulation
    results = {}
    for i in range(2**n_qubits):
        bit = bin(i)[2:].zfill(n_qubits)
        results[f"|{bit}>"] = random.randint(0, 100) if random.random() > 0.8 else 5
    
    ket_viz.histogram(results, title=f"QV {2**n_qubits} Output Distribution")

    # 3. Final Calibration Report
    ket_viz.metrics({
        "quantum_volume": 2**n_qubits,
        "success_rate": "76.4%",
        "avg_cnot_error": 0.008,
        "readout_error": 0.02,
        "benchmarked_at": time.strftime("%H:%M:%S")
    })

run_benchmark(5)
''',
    ),
  ];

  static void useTemplate(QuantumTemplate template) {
    EditorService().openFile("${template.id}.py", template.content);
  }
}
