from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator
import matplotlib.pyplot as plt
import ket_viz
import time

# === KET Studio Demo: Bell State ===
print("🚀 Preparing Bell State Experiment...")

# 1. Estimation
ket_viz.estimator({
    "qubits": 2,
    "depth": 2,
    "algorithm": "Bell State (Entanglement)"
})

# 2. Build Circuit
qc = QuantumCircuit(2)
qc.h(0)
qc.cx(0, 1)
qc.measure_all()

# 3. Viz Circuit (Automatic Interception)
print("> Drawing circuit...")
qc.draw(output='mpl')
plt.show() # KET Studio will intercept this and show it in the Visualization panel

# 4. Simulation
print("> Running simulation...")
simulator = AerSimulator()
compiled_circuit = transpile(qc, simulator)
job = simulator.run(compiled_circuit, shots=1024)
result = job.result()
counts = result.get_counts()

# 5. Result Visualization
ket_viz.histogram(counts, title="Measurement Results (Entangled)")

# 6. Success Metrics
ket_viz.metrics({
    "status": "SUCCESS",
    "fidelity": 1.0,
    "shots": 1024
})

print("✅ Bell State experiment finished.")
