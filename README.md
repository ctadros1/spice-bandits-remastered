# Spice Bandits: Remastered

Reconstruct Spice Bandits 1.14 for macOS, preserving its original appearance, campaign, tower branches, enemy behavior, sound, and progression as closely as the evidence allows.

Start with [PLAN.md](PLAN.md). Supporting material:

- [Research findings](research/GAMEPLAY_FINDINGS.md): observed behavior, evidence conflicts, and fidelity targets.
- [Source catalog](research/SOURCES.md): videos, screenshots, reviews, guides, and wiki references.
- [Video download links](research/VIDEO_LINKS.md): direct links and suggested filenames.
- [Additional game-file discoveries](research/FILE_DISCOVERY_SUMMARY.md): verified 1.27 recovery, content comparison, duplicates, and remaining leads.
- [Executable and asset assessment](research/EXECUTABLE_AND_ASSET_ASSESSMENT.md): recoverable gameplay, platform obstacles, options, and effort estimates.
- [Original material](original/README.md): preserved IPAs, extracted assets, downloaded packs, and recovered disassembly.

As of October14,2026, the offline reconstruction is incomplete. Its saved simulation campaign reaches Madagascar, but the packaged app still differs substantially from the original interface, interactions and animation. The iPad TouchGameplay recording is the main presentation guide, with original asset proportions on a fixed iPad canvas. Multiplayer and expansion remain deferred. See [required differences](docs/FIDELITY.md), [mechanics evidence](docs/mechanics/BASELINE.md), and [verification](docs/VALIDATION.md).

See [offline release notes](docs/OFFLINE_RELEASE.md) for the verified scope and remaining differences.

Open `builds/Spice Bandits Remastered.app`, or open `game/project.godot` in Godot4.7.2. [Build instructions](docs/BUILD.md) explain how to regenerate the derived assets and package from the preserved inputs.

Drag a tower from the bottom tray to a legal hex to place it. Click selects towers; dragging the map pans; scrolling zooms. Keys1–6 select the six original tower families, N launches a wave, Space pauses, Escape/right click cancels, G shows the hex grid, and F11 toggles fullscreen. The canvas keeps its original4:3 proportions when resized. Trackpad pan/pinch handlers are present and await physical gesture verification. The campaign begins with the tutorial; it introduces building, upgrades, selling, Disco Magic, Active Defense and mines.

The user-authorized private repository is [ctadros1/spice-bandits-remastered](https://github.com/ctadros1/spice-bandits-remastered). Source changes belong in Git history; large originals, videos, derived content, toolchains, packages and validation evidence use checksummed private release archives. See [backup and restore](docs/BACKUP.md) for exact upload status and exclusions. Original store-account metadata stays out of the source tree. No new levels, towers, balancing or expansion assets have been created.
