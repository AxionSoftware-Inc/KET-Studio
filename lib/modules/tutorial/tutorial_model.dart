import 'package:fluent_ui/fluent_ui.dart';

enum Difficulty { beginner, intermediate, advanced }

class TutorialSection {
  final String title;
  final String subtitle;
  final String content;
  final String? codeSnippet;

  TutorialSection({
    required this.title,
    required this.subtitle,
    required this.content,
    this.codeSnippet,
  });
}

class Tutorial {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Difficulty difficulty;
  final String duration;
  final List<TutorialSection> sections;

  Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.difficulty,
    required this.duration,
    required this.sections,
  });
}

final List<Tutorial> quantumTutorials = [
  Tutorial(
    id: "qubit_basics",
    title: "The Qubit: Foundation of Quantum",
    description: "Learn about the fundamental unit of quantum information and how it differs from a classical bit.",
    icon: FluentIcons.build_definition,
    difficulty: Difficulty.beginner,
    duration: "5 min",
    sections: [
      TutorialSection(
        title: "Classical vs Quantum",
        subtitle: "From 0/1 to Infinite Possibilities",
        content: "A classical bit is like a light switch: it is either ON (1) or OFF (0). A qubit (Quantum Bit), however, can exist in a combination of both states simultaneously. This is the heart of quantum computing's power.",
      ),
      TutorialSection(
        title: "The Bloch Sphere",
        subtitle: "Visualizing the State",
        content: r"We visualize a qubit's state as a point on a sphere called the **Bloch Sphere**. The North Pole represents $|0\rangle$ and the South Pole represents $|1\rangle$. Any point on the surface is a valid quantum state.",
        codeSnippet: "from qiskit import QuantumCircuit\nqc = QuantumCircuit(1)\n# A qubit starts at |0>\nprint(qc)",
      ),
    ],
  ),
  Tutorial(
    id: "superposition",
    title: "Quantum Superposition",
    description: "Understand the phenomenon where a qubit exists in multiple states at once.",
    icon: FluentIcons.processing,
    difficulty: Difficulty.beginner,
    duration: "8 min",
    sections: [
      TutorialSection(
        title: "The Flailing Coin",
        subtitle: "Neither Heads nor Tails",
        content: "Imagine a spinning coin on a table. While it's spinning, it isn't 'Heads' or 'Tails'—it's a blur of both. Measurement is like stopping the coin: it collapses into one state.",
      ),
      TutorialSection(
        title: r"Hadamard Gate ($H$)",
        subtitle: "Creating Superposition",
        content: r"In Qiskit, the Hadamard gate is the most common way to put a qubit into superposition. It transforms $|0\rangle \rightarrow \frac{1}{\sqrt{2}}(|0\rangle + |1\rangle)$.",
        codeSnippet: "from qiskit import QuantumCircuit\nqc = QuantumCircuit(1)\nqc.h(0) # Apply Hadamard gate to qubit 0\nprint(qc)",
      ),
    ],
  ),
  Tutorial(
    id: "entanglement_lab",
    title: "Quantum Entanglement",
    description: "Explore the 'spooky action at a distance' that links qubits together.",
    icon: FluentIcons.link,
    difficulty: Difficulty.intermediate,
    duration: "12 min",
    sections: [
      TutorialSection(
        title: "Shared Destiny",
        subtitle: "Correlations beyond space",
        content: "When two qubits are entangled, their fates are linked. Measuring one instantly determines the state of the other, no matter how far apart they are. This is used in quantum teleportation and cryptography.",
      ),
      TutorialSection(
        title: "Bell State Generation",
        subtitle: r"The CNOT Gate",
        content: r"To entangle two qubits, we first put one into superposition ($H$) and then apply a Controlled-NOT ($CX$) gate using the first as control and second as target.",
        codeSnippet: "from qiskit import QuantumCircuit\nqc = QuantumCircuit(2)\nqc.h(0)\nqc.cx(0, 1) # Entangle qubit 0 and 1\nqc.measure_all()\nprint(qc)",
      ),
    ],
  ),
  Tutorial(
    id: "qiskit_starter",
    title: "Qiskit: Your First Circuit",
    description: "Write, simulate, and visualize your first quantum circuit using IBM's Qiskit SDK.",
    icon: FluentIcons.code,
    difficulty: Difficulty.beginner,
    duration: "10 min",
    sections: [
      TutorialSection(
        title: "The Quantum Circuit",
        subtitle: "Building the logic",
        content: "A quantum circuit is a sequence of gates applied to qubits. In Qiskit, we define how many qubits and classical bits we need first.",
      ),
      TutorialSection(
        title: "Simulation & Measurement",
        subtitle: "Getting Results",
        content: "Since quantum states aren't directly observable, we must measure them. Simulation allows us to see the probability distribution of results.",
        codeSnippet: "from qiskit import QuantumCircuit, transpile\nfrom qiskit_aer import AerSimulator\n\n# 1. Create Circuit\nqc = QuantumCircuit(2)\nqc.h(0)\nqc.cx(0, 1)\nqc.measure_all()\n\n# 2. Simulate\nsimulator = AerSimulator()\ntranspiled_qc = transpile(qc, simulator)\nresult = simulator.run(transpiled_qc).result()\ncounts = result.get_counts()\nprint(f\"Results: {counts}\")",
      ),
    ],
  ),
  Tutorial(
    id: "grover_search",
    title: "Grover's Algorithm",
    description: "Search unsorted databases quadratically faster than any classical algorithm.",
    icon: FluentIcons.search_and_apps,
    difficulty: Difficulty.advanced,
    duration: "20 min",
    sections: [
      TutorialSection(
        title: "Amplitude Amplification",
        subtitle: "The Magic of Interference",
        content: "Grover's algorithm doesn't 'check' each item. Instead, it uses constructive interference to increase the probability (amplitude) of the correct answer and destructive interference to cancel out wrong answers.",
      ),
      TutorialSection(
        title: "Oracle & Reflector",
        subtitle: "Inverting the State",
        content: "The algorithm consists of two parts: the Oracle (which marks the correct answer) and the Diffusion operator (which flips everything about the average amplitude).",
        codeSnippet: "# Conceptual Grover Step in Ket Studio\ndef grover_iteration(circuit, oracle):\n    circuit.append(oracle, [0, 1, 2])\n    circuit.h([0, 1, 2])\n    circuit.z([0, 1, 2]) # Diffusion logic\n    circuit.h([0, 1, 2])",
      ),
    ],
  ),
];
