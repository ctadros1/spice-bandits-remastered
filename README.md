# Spice Bandits Remastered

Reconstruct Spice Bandits 1.14 for macOS, preserving its original appearance, campaign, tower branches, enemy behavior, sound, and progression as closely as the evidence allows.

Start with [PLAN.md](PLAN.md). Supporting material:

- [Research findings](research/GAMEPLAY_FINDINGS.md): observed behavior, evidence conflicts, and fidelity targets.
- [Source catalog](research/SOURCES.md): videos, screenshots, reviews, guides, and wiki references.
- [Video download links](research/VIDEO_LINKS.md): direct links and suggested filenames.
- [Additional game-file discoveries](research/FILE_DISCOVERY_SUMMARY.md): verified 1.27 recovery, content comparison, duplicates, and remaining leads.
- [Executable and asset assessment](research/EXECUTABLE_AND_ASSET_ASSESSMENT.md): recoverable gameplay, platform obstacles, options, and effort estimates.
- [Original material](original/README.md): preserved IPAs, extracted assets, downloaded packs, and recovered disassembly.

As of October 13, 2026, the Godot game is playable and has a locally exported macOS Universal2 app. Offline reconstruction is in progress; its fidelity gate has not passed. Multiplayer and expansion have not begun. See [current differences](docs/FIDELITY.md), [mechanics evidence](docs/mechanics/BASELINE.md), and [verification](docs/VALIDATION.md).

Open `builds/Spice Bandits Remastered.app`, or open `game/project.godot` in Godot4.7.2. [Build instructions](docs/BUILD.md) explain how to regenerate the derived assets and package from the preserved inputs.

Mouse click selects/places towers; drag pans; scrolling zooms. Keys1–6 select the six original tower families, N launches a wave, Space pauses, Escape/right click cancels, G shows the hex grid, and F11 toggles fullscreen. Trackpad pan/pinch handlers are present and await physical gesture verification. The campaign begins with the tutorial; it introduces building, upgrades, selling, Disco Magic, Active Defense and mines.

A local Git repository has been initialized. Preserved originals, videos, generated content, toolchains and builds remain excluded. Do not publish the original archive or store-account metadata automatically. No new levels, towers, balancing or expansion assets have been created.
