class DemoContent {
  static const String welcomeTitle = "Welcome to KET Studio";
  static const String welcomeSubtitle = "Professional Quantum Programming IDE";

  static const String demoScript = """# === KET Studio Professional Showcase ===
# This script demonstrates the full integration of KET Studio Visualizers.
# Standard: Estimation -> Inspection -> Execution -> Metrics

import ket_viz, math, time, random

print("🚀 Initializing KET Quantum Engine...")

# 1. RESOURCE ESTIMATION
# Report expected resources to the ESTIMATOR panel
ket_viz.estimator({
    "qubits": 5,
    "depth": 18,
    "total_gates": 45,
    "gate_counts": {
        "H": 5,
        "CNOT": 12,
        "RZ": 20,
        "X": 8
    }
})
time.sleep(0.8)

# 2. CIRCUIT INSPECTION
# Step-by-step walkthrough in the INSPECTOR panel
print("> Preparing circuit inspection...")
steps = []
for i in range(5):
    steps.append({
        "gate": f"Step {i+1}",
        "state_description": f"Phase rotation applied to qubit {i}",
        "bloch": [{"theta": math.pi/(i+1), "phi": math.pi*i/4} for _ in range(5)]
    })
ket_viz.inspector("Quantum Phase Estimation", steps)
time.sleep(1)

# 3. LIVE METRICS & PROGRESS
# Real-time status in the METRICS panel
for i in range(1, 11):
    ket_viz.metrics({
        "status": "Running Simulation",
        "progress": f"{i*10}%",
        "shots_completed": i * 100,
        "avg_gate_fidelity": 0.998 - (i * 0.0001)
    })
    
    # 4. DYNAMIC VISUALIZATION
    # Update histogram/chart live
    results = {"00000": 800 + i*10, "11111": 150 - i*5, "others": 50}
    ket_viz.histogram(results, title="Live Measurement Distribution")
    
    # Update a chart for convergence
    ket_viz.chart([math.sin(x/5) + random.uniform(-0.1, 0.1) for x in range(i+5)])
    
    time.sleep(0.3)

# 5. FINAL ANALYTICS
print("> Finalizing results...")
ket_viz.metrics({
    "status": "COMPLETED",
    "execution_time": "3.42s",
    "final_fidelity": 0.9975,
    "backend": "KET-QVM-v2",
    "optimization_level": 3
})

# 6. COMPLEX DATA (Heatmap)
# Show cost landscape or correlation matrix
matrix = [[random.random() for _ in range(8)] for _ in range(8)]
ket_viz.heatmap(matrix, title="Qubit Correlation Matrix")

print("✅ Showcase finished. Explore the sidebar panels!")
""";
}
