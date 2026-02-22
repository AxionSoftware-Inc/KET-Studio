class TutorialSection {
  final String title;
  final String content;
  final String? codeSnippet;

  TutorialSection({
    required this.title,
    required this.content,
    this.codeSnippet,
  });
}

class Tutorial {
  final String id;
  final String title;
  final String description;
  final List<TutorialSection> sections;

  Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.sections,
  });
}

final List<Tutorial> quantumTutorials = [
  Tutorial(
    id: "superposition",
    title: "Superpozitsiya nima?",
    description: "Qubitning bir vaqtning o'zida ikkita holatda bo'lishi.",
    sections: [
      TutorialSection(
        title: "Intuittiv yondashuv",
        content:
            "Tasavvur qiling, sizda tanga bor. U yerga tushguncha havoda aylanadi — u ham 'gerb', ham 'son' holatida bo'ladi. Kvant dunyosida bu 'Superpozitsiya' deyiladi.",
      ),
      TutorialSection(
        title: "Matematik model",
        content:
            "Qubit holati quyidagicha yoziladi: |ψ⟩ = α|0⟩ + β|1⟩. Bunda α va β - ehtimollik amplitudalaridir.",
        codeSnippet:
            "from qiskit import QuantumCircuit\nimport ket_viz\n\nqc = QuantumCircuit(1)\nqc.h(0) # Hadamard darvozasi superpozitsiya yaratadi\nprint(\"Superpozitsiya holati yaratildi.\")",
      ),
    ],
  ),
  Tutorial(
    id: "entanglement",
    title: "Bell Entanglement nima?",
    description: "Masofadan turib bir-biriga bog'langan qubitlar.",
    sections: [
      TutorialSection(
        title: "Spooky Action",
        content:
            "Ikki qubit 'chigallashganda', ulardan birini o'lchasangiz, ikkinchisi koinotning narigi chekkasida bo'lsa ham, uning holati darhol aniqlanadi.",
      ),
      TutorialSection(
        title: "Bell Holati",
        content:
            "Eng mashhur chigallashgan holat: 1/sqrt(2) * (|00⟩ + |11⟩). Bunda agar birinchi qubit 0 bo'lsa, ikkinchisi ham 100% holatda 0 bo'ladi.",
        codeSnippet:
            "from qiskit import QuantumCircuit\nqc = QuantumCircuit(2)\nqc.h(0)\nqc.cx(0, 1) # CNOT darvozasi chigallikni hosil qiladi\nqc.measure_all()",
      ),
    ],
  ),
  Tutorial(
    id: "interference",
    title: "Interferensiya (Grover)",
    description: "Ehtimolliklarning bir-birini kuchaytirishi yoki so'ndirish.",
    sections: [
      TutorialSection(
        title: "To'lqinlar jangi",
        content:
            "Kvant hisoblashda biz xato javoblarni 'so'ndirishimiz' va to'g'ri javobni 'kuchaytirishimiz' kerak. Bu xuddi shovqinni bekor qiluvchi quloqchinlarga o'xshaydi.",
      ),
      TutorialSection(
        title: "Grover Iteratsiyasi",
        content:
            "Grover algoritmi har bir qadamda qidirilayotgan holatning amplitudasini oshirib boradi. 1-iteratsiyadan keyin to'g'ri javob ehtimolligi sezilarli o'sadi.",
        codeSnippet:
            "# Grover algoritmi intuitiv qadami\nimport ket_viz\n# 1. Oracle (belgilash)\n# 2. Diffusion (kuchaytirish)\nket_viz.metrics({\"step\": \"Grover 1-iteratsiya\", \"target_prob\": \"o'smoqda\"})",
      ),
    ],
  ),
  Tutorial(
    id: "randomness",
    title: "Measurement Randomness",
    description: "Kvant olamining tasodifiyligi va kollaps.",
    sections: [
      TutorialSection(
        title: "Kollaps tushunchasi",
        content:
            "Qubit o'lchanguniga qadar barcha imkoniyatlarni o'zida saqlaydi. O'lchash jarayonida esa u 'kollaps' bo'ladi va faqat bitta aniq natija (0 yoki 1) beradi.",
      ),
      TutorialSection(
        title: "Ehtimollik",
        content:
            "Natija tasodifiy bo'lsa-da, u ma'lum ehtimollikka bo'ysunadi. P(i) = |c_i|^2. Ko'p marta o'lchash (shots) orqali biz bu ehtimollikni ko'ramiz.",
        codeSnippet:
            "from qiskit import QuantumCircuit, transpile\nfrom qiskit_aer import AerSimulator\nimport ket_viz\n\nqc = QuantumCircuit(1)\nqc.h(0)\nqc.measure_all()\n\nsim = AerSimulator()\n# 1024 marta o'lchash tasodifiy taqsimotni ko'rsatadi\ncounts = sim.run(transpile(qc, sim), shots=1024).result().get_counts()\nket_viz.histogram(counts, title=\"Tasodifiy natijalar taqsimoti\")",
      ),
    ],
  ),
];
