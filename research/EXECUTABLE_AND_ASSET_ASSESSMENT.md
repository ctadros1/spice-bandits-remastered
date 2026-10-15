# Executable and Asset Recovery Assessment

Verified October 13, 2026. This assessment combines preserved static evidence with the research catalog. No complete original app has been installed or run. Bounded ARM functions now execute in local emulation with explicit stubs; their scope is recorded in the reconstruction verification notes.

## What the decrypted 1.14 package changes

The two supplied 1.14 IPAs contain the same game art and data. The useful difference is the readable executable: the supplied decrypted package has `cryptid=0`, whereas the original archive has `cryptid=1`. Decryption provides access to actual compiled behavior, not additional levels or the original source project.

The earlier file-by-file comparison found 1,282 unchanged entries, two removed DRM files, and changes to the executable and store metadata. The preservation inventory was rechecked against the extracted files in this project.

The main executable is an 8,599,200-byte, 32-bit ARMv7 Mach-O. It retains 91,868 symbol-table entries, including source/object provenance and named functions. The extracted function index contains 2,248 records associated with 102 game/engine compilation units, including library templates. Roughly 1,700 remain after simple template/library filtering. These are analysis leads; only 31 representative functions have received focused disassembly in the current evidence set. Local-variable debug information and authentic gameplay source are absent.

Evidence: [executable summary](../original/analysis/ipa-1.14-executable-summary.json), [function index](../original/analysis/game-functions.json), and [recovered-code notes](../original/source-code/recovered/README.md).

## Engine and platform

Names, compilation units, and imports indicate a custom C++/Objective-C++ game engine, with Objective-C interface/service code and OpenGL ES/OpenAL rendering/audio. This is not a preserved Unity or Godot project. The binary also links legacy Apple game, networking, store, graphics, and media frameworks; some platform integration is linked indirectly or statically.

The ARMv7 iOS binary cannot be treated as a modern macOS application. Decryption does not convert its architecture, framework dependencies, ABI, or touch/service integration. Porting needs reconstructed source or a new implementation. The later 1.27 package adds ARM64, but remains an iOS application and both code slices are encrypted. See the [later-package comparison](FILE_DISCOVERY_SUMMARY.md).

## Original assets and authored data available

| Material in the decrypted IPA | Inventory and use |
| --- | --- |
| Images | 875 PNGs, including 455 Apple CgBI files; 44 `.jpg` files, one containing PNG bytes. Towers, enemies, effects, interface art, maps, and sprite metadata are accessible. |
| XML | 200 files for authored game content, map layers, animation/atlas descriptions, and related definitions. Two prefix defects require documented importer repairs. |
| Sound/music | 92 CAF files: 59 PCM and 33 IMA4; eight MP3s. Preserve originals and derive compatible runtime audio. |
| Video/fonts/UI | Two MOVs, five fonts, and 44 NIB interface files. NIBs provide layout clues but do not directly become Godot scenes. |
| Embedded offline JSON | 18 tower forms with 54 level entries; 29 populated enemy definitions; 20 upgrades; 78 medals; 298 mission listings; 149 offline records, including 148 nonempty schedules containing 2,305 wave entries. |
| Downloaded original files | All 63 referenced level ZIPs and 89 costume images plus 89 previews preserved. 66 distinct numbered map IDs in total; all 54 IDs required by nonempty offline schedules are present. |

Presence is not a complete dependency audit. Downloaded map variants may differ, and `map_100.xml` and `map_1004.xml` fail strict parsing. Counts distinguish tower forms, levels, maps, modes, and configurations rather than equating them with advertised level totals.

## Gameplay that can now be recovered more faithfully

Readable code enables reconstruction of targeting, elliptical range checks, sell refunds across upgrade branches, slowing and ability stacking, path validation, simulation correction, special enemy state changes, and local unlock handling. Several concrete examples are already recorded in [GAMEPLAY_FINDINGS.md](GAMEPLAY_FINDINGS.md).

The remaining important work is tracing complete call chains, object fields, update order, rounding, random choices, threat-aware path costs, progression/reward formulas, and multiplayer semantics. Named functions greatly improve this work, but decompiler output still needs interpretation and comparison with original play. There is no defensible percentage of total gameplay fidelity to claim from symbol counts alone.

## Options and recommendation

| Approach | Assessment |
| --- | --- |
| Reimplement original rules using original assets in Godot | Recommended. Good desktop input, 2D tooling, and macOS packaging; custom simulation preserves the original behavior. |
| Reconstruct the C++ engine and replace its iOS platform layer | Potentially closer at the code level, but recovering enough compilable source/object structure is substantially harder. Useful selective routines can still inform the recommended approach. |
| SpriteKit/AppKit implementation | Viable for a Mac-only project, with more custom importer, editor, and content tooling work. |
| Run the original through an emulator or compatibility layer | Investigate briefly for reference capture. Compatibility is unverified, and it does not deliver the requested maintainable macOS reconstruction. [touchHLE compatibility context](https://touchhle.org/faq.html) |

The result is a feasible but substantial reconstruction project. The decrypted executable moves us from guessing rules from footage to recovering them from code. Complete map recovery reduces asset-hunting work. Neither discovery eliminates implementation, validation, or the missing multiplayer backend.

Planning range for one experienced developer with Codex: first playable slice in about 1–3 weeks, strong offline recreation in about 8–12 weeks, and closer edge-case/presentation parity in about 3–5 months. These are estimates, with overlapping phases, not a guaranteed calendar. Original multiplayer restoration needs separate protocol/server work and can add months. Re-estimate after Tutorial and Desert Freighter pass the first behavioral comparison.

The [main plan](../PLAN.md) contains phases, acceptance gates, unresolved mechanics, and the expansion boundary.
