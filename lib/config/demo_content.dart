class DemoContent {
  static const String welcomeTitle = "Welcome to KET Studio";
  static const String welcomeSubtitle = "Professional Quantum Programming IDE";

  static const String demoScript = """
# KET Studio Comprehensive Demo
# This script showcases all visualization panels

import math
import time

print("Launching KET Studio Quantum Demo...")
time.sleep(1)

# 1. Dashboard Visualization
print("> Sending Dashboard data...")
ket_viz("dashboard", {
    "histogram": {
        "|00>": 450,
        "|01>": 52,
        "|10>": 48,
        "|11>": 450
    },
    "matrix": {
        "0,0": 0.707, "0,1": 0.0, "0,2": 0.0, "0,3": 0.707,
        "1,0": 0.0, "1,1": 0.1, "1,2": 0.0, "1,3": 0.0,
        "2,0": 0.0, "2,1": 0.0, "2,2": 0.0, "2,3": 0.0,
        "3,0": 0.707, "3,1": 0.0, "3,2": 0.0, "3,3": -0.707
    }
})
time.sleep(1)

# 2. Bloch Sphere
print("> Showing Bloch Sphere...")
ket_viz("bloch", {"theta": math.pi/4, "phi": math.pi/2})
time.sleep(1)

# 3. Circuit Inspector (Step-by-Step)
print("> Updating Circuit Inspector...")
inspector_data = {
    "title": "Quantum Teleportation Steps",
    "frames": [
        {"gate": "Init", "state_description": "Initial state |0>", "bloch": [{"theta": 0, "phi": 0}]},
        {"gate": "H", "state_description": "Superposition state", "bloch": [{"theta": math.pi/2, "phi": 0}]},
        {"gate": "Z", "state_description": "Phase flip applied", "bloch": [{"theta": math.pi/2, "phi": math.pi}]}
    ]
}
ket_viz("inspector", inspector_data)
time.sleep(1)

# 4. Table and Heatmap
print("> Generating Analytics...")
ket_viz("table", {
    "title": "State Comparison",
    "rows": [
        ["State", "Prob"],
        ["|00>", "50%"],
        ["|11>", "50%"]
    ]
})

ket_viz("heatmap", {
    "title": "Cost Landscape",
    "data": [[0.1, 0.8], [0.9, 0.2]]
})

print("Demo finished. Check the right panels!")
""";
}
