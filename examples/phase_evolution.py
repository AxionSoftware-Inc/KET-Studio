import ket_viz, time, math

def run_phase_evolution():
    print("🚀 KET Studio: Phase Color Evolution Demo")
    print("Visualizing complex phases using the standardized color wheel.")
    
    steps = 40
    for i in range(steps + 1):
        # Calculate a rotating phase
        # Phase goes from 0 to 4*pi (two full rotations)
        phase = (i / steps) * 4 * math.pi
        
        # State: 1/sqrt(2) * (|00> + e^(i*phi)|11>)
        # Magnitude is 0.5 for 00 and 11 (0.707^2 if showing probability, but here we show magnitude)
        amplitudes = [
            {"label": "00", "mag": 0.707, "phase": 0.0},
            {"label": "01", "mag": 0.0, "phase": 0.0},
            {"label": "10", "mag": 0.0, "phase": 0.0},
            {"label": "11", "mag": 0.707, "phase": phase}
        ]
        
        # Update visualization
        ket_viz.statevector(amplitudes, title=f"Quantum State Evolution (Phase: {i*360/steps:.0f}°)")
        
        # Send some metrics
        ket_viz.metrics({
            "step": i,
            "phase_deg": f"{(i*360/steps) % 360:.1f}°",
            "fidelity": 1.0,
            "status": "Evolving phase..."
        })
        
        time.sleep(0.05)

    print("✅ Demo finished. Observe the color changes in the Statevector panel.")

if __name__ == "__main__":
    run_phase_evolution()
