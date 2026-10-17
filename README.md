# Spice Bandits: Remastered

Reconstruct Spice Bandits1.14 for macOS in Godot, preserving its original appearance, interactions, animation, sound, campaign and progression. The supplied iPad recording guides presentation while original assets retain their proportions on a fixed4:3 canvas. Original files and normal/earned saves are preserved. No expansion or multiplayer work is included.

The offline recreation is incomplete. Current R169 corrects health bars to the original raw animator anchor, independently of body offsets. Original-case checks, full build, presentation/rendering comparisons and all eight functional suites pass. The unchanged 33.34 ms median performance limit fails at 35.063/40.250/45.593 ms for 1×/2×/4×. Hover motion and original sound ownership remain incomplete. Passing tests does not establish original visual identity.

The [R165 private recovery draft](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/untagged-9b2b038775c30000ba61) is verified from an actual download: exact app, 638 candidate and 639 signed current-source files, preserved failures and evidence. All four protected saves remain unchanged. Source [7f5c825](https://github.com/ctadros1/spice-bandits-remastered/tree/7f5c825d7b6535e9e69a2b123431e03940dcdadc) is signed and confirmed on private main. The [R137 checkpoint](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/backup-2026-10-16-r137) remains the last published all-ten historical app and accepted comparison. Future signing failures will not stop development.

R169 source is signed and confirmed on private GitHub as [480694f](https://github.com/ctadros1/spice-bandits-remastered/tree/480694f7f03ad1df79bf4bd08a354f010b600623). Its exact app/evidence recovery is being prepared; R165 remains the latest completed private archive. See [health evidence](docs/mechanics/CREEP_HEALTH.md).

Current scope and next actions are in [HANDOFF.md](HANDOFF.md) and [PLAN.md](PLAN.md). New [creep state and hover evidence](docs/mechanics/CREEP_STATE.md) records the original state routine and remaining movement, sound and constructor gaps.

[Particle evidence and remaining gaps](docs/mechanics/CREEP_PARTICLE_OWNER.md) distinguish recovered constructor fields/clocks from full original trajectories, callers, rendering, GPU and services. New [map-theme evidence](docs/mechanics/MAP_THEME.md) resolves the constructor's snow-color selector; the live mapping and native owner optimization pass the bounded source checks. Current packaged performance still fails; [R153recovery](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/untagged-01306920cceba2041df0) is actual-download/source/app-restore verified. Its code remains pending signing as a patch on the signed R151base; the latest605-file source supplement also restores exactly from the private download. Later research/publication source may advance Git beyond the frozen R151candidate.

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
