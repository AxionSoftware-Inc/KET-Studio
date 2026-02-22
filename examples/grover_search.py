"""
KET Studio Demo: Grover's Search Algorithm
Standard: Estimation -> Metrics -> Histogram -> Finished
"""
import ket_viz, time, math

print("🚀 Starting Grover's Search Algorithm Demo...")

# 1. ESTIMATION
n_qubits = 3
ket_viz.estimator({
    "qubits": n_qubits,
    "depth": 15,
    "algorithm": "Grover Search",
    "target": "101"
})

# 2. METRICS (Algorithm Setup)
ket_viz.metrics({"status": "Initializing Superposition", "progress": "10%"})
time.sleep(0.5)

# 3. INSPECTION (Grover Steps)
steps = [
    {"gate": "Hadamard", "state_description": "Equal superposition of all 8 states."},
    {"gate": "Oracle", "state_description": "Marking state |101> (phase flip)."},
    {"gate": "Diffusion", "state_description": "Amplitude amplification around the mean."},
]
ket_viz.inspector("Grover Iteration 1", steps)

# 4. LIVE PROGRESS
for i in range(1, 6):
    progress = 20 + (i * 16)
    ket_viz.metrics({
        "status": f"Applying Reflection {i}",
        "progress": f"{progress}%",
        "current_step": i
    })
    
    # Live convergence towards |101>
    prob_target = 0.125 + (i * 0.15)
    prob_others = (1.0 - prob_target) / 7
    counts = {"101": int(prob_target * 1024)}
    for s in ["000", "001", "010", "100", "110", "111", "011"]:
        counts[s] = int(prob_others * 1024)
        
    ket_viz.histogram(counts, title=f"Measurement Probabilities (Step {i})")
    time.sleep(0.4)

# 5. FINAL TABLE
final_results = [
    ["Metric", "Value"],
    ["Optimal Iterations", 2],
    ["Success Probability", "94.5%"],
    ["Target State", "101"]
]
ket_viz.table("Grover Execution Summary", final_results)

print("✅ Grover Search completed successfully!")
