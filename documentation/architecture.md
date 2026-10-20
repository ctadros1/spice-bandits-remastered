# Reconstruction architecture

[Documentation](README.md) · [Setup](getting-started.md) · [Simulation ownership](../simulation/README.md) · [Native helper](../native/README.md)

The original game used a custom C++/Objective-C++ iOS engine. The reconstruction uses a new Godot runtime, with imported original content and selected C++ operations. The boundary matters: original machine code is used as research evidence; it is not the executable shipped as the macOS game.

## The main parts

| Part | Responsibility | Source |
| --- | --- | --- |
| Content import | Decode preserved media and authored definitions into Godot-compatible assets, JSON, and audit records. | [`import_original.py`](../tools/importers/import_original.py) |
| Content access | Load generated definitions for the runtime. | [`content.gd`](../game/scripts/content.gd) |
| Simulation | Own battle state, rules, movement, combat, effects, and outcomes independently of input and rendering. | [`simulation.gd`](../game/scripts/simulation.gd) |
| Presentation and input | Compose scenes, render state, and translate desktop actions into game operations. | [`main.gd`](../game/scripts/main.gd), [`game/scripts/`](../game/scripts/) |
| Profile persistence | Manage local progress and transactional save behavior; isolate QA accounts. | [`profile.gd`](../game/scripts/profile.gd) |
| Native helper | Accelerate selected targeting, movement, particle, and geometry operations while retaining comparison paths. | [`hotpaths.cpp`](../native/hotpaths.cpp) |
| Reference tooling | Execute selected original ARM routines and capture state, calls, and draw submissions. | [`tools/`](../tools/) and [`tests/fixtures/`](../tests/fixtures/) |

## Data and execution boundaries

The importer reads from `original/` and writes derived content into `game/assets/` and `game/data/`. Those directories are excluded from Git. Original archives remain preservation inputs, separate from repairs and conversions.

The simulation is a Godot `RefCounted` object that can be instantiated by a headless check. Rendering, audio, input, and profile writes sit outside that simulation boundary. Scene-specific view and lifecycle helpers retain the recovered ordering and state needed by presentation.

Replay fixtures use a **30 ms step**; ordinary offline play uses the recovered live elapsed-time path. A fixture cadence is not evidence that every original game update ran at one universal fixed tick. See [update timing](../docs/mechanics/UPDATE_TIMING.md).

The project uses a **1024 × 768** logical canvas with uniform scaling and borders as needed. The aim is to preserve original asset proportions even when a supplied recording appears stretched. The configured desktop window starts at 1280 × 960.

## Native optimization and numerical behavior

The native helper is a GDExtension, built against pinned godot-cpp bindings as a Universal2 library. Its build disables floating-point contraction and fast-math reassociation because recovered float32 operation order can affect behavior. Script reference paths and original-function fixtures provide comparisons for selected routines.

Rendering optimizations must preserve overlap and submission order. For example, batching consecutive compatible particle quads is different from sorting all particles by texture: global sorting could alter the picture. Exact geometry or draw-submission equality still requires a separate check of the rendered pixels.

## Repository map

```text
game/             Godot scenes, scripts, native integration, and export settings
native/           C++ helper source and build configuration
tools/            Importers, ARM probes, build tools, and QA runners
tests/            Frozen fixtures and reference records
research/         Original-source catalog and investigation notes
documentation/    Reader guides and reverse-engineering process
docs/             Detailed mechanics, validation receipts, and history
simulation/       Explanation of simulation ownership
original/         Local preserved inputs (ignored by Git)
work/             Local toolchains and scratch research (ignored by Git)
builds/           Generated apps and QA evidence (ignored by Git)
```
