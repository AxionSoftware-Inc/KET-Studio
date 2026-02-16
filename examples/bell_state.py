from qiskit import QuantumCircuit
from qiskit_aer import Aer
from qiskit.visualization import plot_histogram
import matplotlib.pyplot as plt

# 1. Create a Quantum Circuit acting on a quantum register of two qubits
circ = QuantumCircuit(2)

# 2. Add a H gate on qubit 0, putting this qubit in superposition.
circ.h(0)

# 3. Add a CX (CNOT) gate on control qubit 0 and target qubit 1, putting
# the qubits in a Bell state.
circ.cx(0, 1)

# 4. Measure the qubits
circ.measure_all()

# 5. Use Aer's qasm_simulator
simulator = Aer.get_backend('qasm_simulator')

# 6. Execute the circuit on the qasm simulator
job = simulator.run(circ, shots=1000)

# 7. Grab results from the job
result = job.result()

# 8. Returns counts
counts = result.get_counts(circ)
print("\nTotal count for 00 and 11 are:", counts)

# 9. Draw the circuit
print("\nCircuit Diagram:")
print(circ.draw())

# 10. (Optional) Save the plot if needed
# circ.draw(output='mpl', filename='circuit.png')
# plt.show()
