# Spice Bandits: Remastered

Reconstruct Spice Bandits1.14 for macOS in Godot, preserving its original appearance, interactions, animation, sound, campaign and progression. The supplied iPad recording guides presentation while original assets retain their proportions on a fixed4:3 canvas. Original files and normal/earned saves are preserved. No expansion or multiplayer work is included.

The offline game is incomplete. The current R147 package passes547presentation checks/216captures,15pixel comparisons,12geometry comparisons and all eight separate functional suites, including campaign and audio. It still fails the unchanged33.34ms median performance limit at2×33.470ms and4×40.322ms;1×32.912ms passes. Passing these checks does not establish original visual identity or complete reconstruction. All failed candidates and unresolved evidence gaps remain recorded in [PLAN.md](PLAN.md) and [HANDOFF.md](HANDOFF.md).

Current development source [0f77289](https://github.com/ctadros1/spice-bandits-remastered/tree/0f77289f9255ea9e551c59070b2ab94336e8cec4) is signed and pushed. Its actual downloaded private source bundle restores all591source files and executable modes exactly. The [R147 recovery draft](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/untagged-c2ce2d043f8713a1d612) preserves the current failed app, evidence, prior source patches and new research. The older [R137 historical checkpoint](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/backup-2026-10-16-r137) is published and restore-verified with its exact signed547-file source; it remains the last all-ten verified app. [Backup details](docs/BACKUP.md) distinguish these scopes and signature results.

Original constructor and joined particle birth/status/tail references now reproduce independently. They prove bounded empty-root creation, ownership, clocks, emission phases and retained counts under explicit supplied inputs and callbacks. Their [evidence and remaining gaps](docs/mechanics/CREEP_PARTICLE_OWNER.md) now guide a live constructor and timing port under verification. No new packaged acceptance is claimed until its full checks and visual review finish. Full original resource loading, other status callers, registry/RNG, owner/global rendering, GPU and progression services remain open.

Start with [PLAN.md](PLAN.md). Supporting material:

- [Research findings](research/GAMEPLAY_FINDINGS.md): observed behavior, evidence conflicts, and fidelity targets.
- [Source catalog](research/SOURCES.md): videos, screenshots, reviews, guides, and wiki references.
- [Video download links](research/VIDEO_LINKS.md): direct links and suggested filenames.
- [Additional game-file discoveries](research/FILE_DISCOVERY_SUMMARY.md): verified 1.27 recovery, content comparison, duplicates, and remaining leads.
- [Executable and asset assessment](research/EXECUTABLE_AND_ASSET_ASSESSMENT.md): recoverable gameplay, platform obstacles, options, and effort estimates.
- [Original material](original/README.md): preserved IPAs, extracted assets, downloaded packs, and recovered disassembly.

As of October16,2026, the offline reconstruction is incomplete. Its saved simulation campaign reaches Madagascar, but the packaged app still differs substantially from the original interface, interactions and animation. The iPad TouchGameplay recording is the main presentation guide, with original asset proportions on a fixed iPad canvas. Multiplayer and expansion remain deferred. See [required differences](docs/FIDELITY.md), [mechanics evidence](docs/mechanics/BASELINE.md), and [verification](docs/VALIDATION.md).

See [offline release notes](docs/OFFLINE_RELEASE.md) for the verified scope and remaining differences.

Open `builds/Spice Bandits Remastered.app`, or open `game/project.godot` in Godot4.7.2. [Build instructions](docs/BUILD.md) explain how to regenerate the derived assets and package from the preserved inputs.

Drag a tower from the bottom tray to a legal hex to place it. Click selects towers; dragging the map pans; scrolling zooms. Keys1–6 select the six original tower families, N launches a wave, Space pauses, Escape/right click cancels, G shows the hex grid, and F11 toggles fullscreen. The canvas keeps its original4:3 proportions when resized. Trackpad pan/pinch handlers are present and await physical gesture verification. The campaign begins with the tutorial; it introduces building, upgrades, selling, Disco Magic, Active Defense and mines.

The user-authorized private repository is [ctadros1/spice-bandits-remastered](https://github.com/ctadros1/spice-bandits-remastered). Source changes belong in Git history; large originals, videos, derived content, toolchains, packages and validation evidence use checksummed private release archives. See [backup and restore](docs/BACKUP.md) for exact upload status and exclusions. Original store-account metadata stays out of the source tree. No new levels, towers, balancing or expansion assets have been created.
