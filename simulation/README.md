# Simulation ownership

The independently instantiable Godot `RefCounted` simulation is in `game/scripts/simulation.gd` so the exported app includes it without copying a second implementation. Tests instantiate it in a headless Godot process. Rendering, audio, profile writes, and input are outside the simulation.

The reconstruction uses integer elapsed milliseconds and a 30 ms replay step. This is the recovered replay cadence, not a claim that the original normal update used a universal fixed tick. See `docs/mechanics/BASELINE.md` for confidence and pending differences.
