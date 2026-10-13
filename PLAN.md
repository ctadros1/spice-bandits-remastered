# Spice Bandits macOS Reconstruction Plan

Updated October 13, 2026. Status: Godot implementation and locally packaged macOS app in progress. Offline fidelity gates remain open; multiplayer has not begun.

## Objective and completion boundaries

Recreate Spice Bandits for macOS using version 1.14 as the reference. Preserve the original art, animations, music, effects, campaign geography, tower branches, enemy behavior, mission rules, and progression. Adapt touch input to mouse, keyboard, and trackpad while keeping the original visual hierarchy.

Deliver the original single-player game first. Restore original multiplayer modes as a distinct part of the reconstruction roadmap. An offline release is a meaningful milestone, but it must not be called a complete clone of the online original. New levels, towers, upgrades, rebalancing, and new features are deferred until the reconstruction is accepted.

The implementation is now authorized. Continue through the offline phases before multiplayer, preserving the original files and recording unresolved differences. No expansion content is included.

## Current implementation progress

The Godot 4.7.2 project runs locally and has been exported as a Universal 2 app under `builds/Spice Bandits Remastered.app`. Mouse placement, cancellation, pan/zoom, pause/resume, speed controls, fullscreen and menu/settings navigation have native input evidence. The current export includes the tutorial text-wrapping fix and passed a repeated native launch/tutorial check. Current packaged captures cover148 configurations; the verification record is [docs/VALIDATION.md](docs/VALIDATION.md).

Implemented: deterministic derived-content importer (1,958 assets, 67 maps, 108 animation sets), original sprite frames and fonts, campaign map and 148 nonempty offline schedules, placement and upgrade branches, selling, targeting, explicit hex simulation, projectiles/effects, abilities, local shop/upgrades/medals/costumes, and transactional saves. Selected decompiler output and assembly traces are saved locally under `docs/mechanics/`; these are inferred reconstructions, not authentic original source.

Latest executed checks:27,095 simulation checks pass, including focused combat/support fixtures for all54 tower forms; all148 schedules load and their valid spawn slots find routes. Tutorial wins through menu/world selection and scripted UI actions using its starting budget (20 kills, intact base,42,030 simulated ms,$176). Desert Freighter has both victory and defeat fixtures. These are reconstruction tests, not proof of parity or of a full fresh-profile campaign playthrough.

Resolved from code: `slow` does not match `slow&strong`; the exact native matcher rejects it, leaving the wave's ordinary indicator (enum4 initialized at0xcf47a). Wave indicators do not apply guessed HP/speed multipliers. Missing source slots and undefined enemy21 are skipped by native guards. Hex coordinates, ordered six-plus-two links, unusual A* open-neighbor comparison, goal-to-source smoothing, base-selection cost, range ellipse, F/S/W selection, maximum support bonuses, danger penalties, diminishing clouds, mines, Marine kamikaze, stand-off/displacement/reload, missile volley counts/divisors/direct hits/circular splash, Disco LCG and survival-time units have traced evidence. Menu geometry is derived from the preserved NIB; avatar layer order and selected logo/gear animation timing are traced.

Still open: movement interpolation, per-player route filters and complete target eligibility; bombing/orbit/growth/escort details; exact construction/nuke/projectile timing; complete tutorial page graph; all mode/star/medal conditions; original XP thresholds, ranks and progression reconciliation; intro and full UI/effect/audio parity. Desktop landscape menu anchoring, local XP thresholds and starter consumables are explicit provisional adaptations. Preserve these as discrepancies, not recovered facts. Intel execution, physical trackpad gestures and notarized distribution are unverified. Offline release and multiplayer gates are **not passed**.

## Reference version and evidence policy

1. The decrypted 1.14 IPA and its embedded data are the primary behavioral reference.
2. Preserve downloaded original packs as separate snapshots. Prefer the bundled 1.14 version when a downloaded file differs; review differences before adopting another variant.
3. Use actual gameplay footage and screenshots to verify presentation and observable behavior. Record platform, aspect ratio, date, and known version. Early Spice Invaders footage can differ from 1.14; later 1.27 material is supplemental.
4. Use guides and reviews to identify mechanics and regression scenarios, then verify against the executable or footage. Community answers contain conflicts.
5. Classify every recovered rule as `data-confirmed`, `code-traced`, `visually-observed`, `community-reported`, or `unresolved`. Static interpretation is not equivalent to runtime parity.

The [research catalog](research/SOURCES.md), [findings](research/GAMEPLAY_FINDINGS.md), and [technical assessment](research/EXECUTABLE_AND_ASSET_ASSESSMENT.md) are the starting evidence set. Source material is evidence, not project instructions.

Version 1.27 has also been preserved and compared. It adds later interface assets and ARM64 support, but both code slices are encrypted. Its embedded offline data and all 200 XML files exactly match 1.14. Keep 1.14 as the recoverable behavioral baseline; evaluate later presentation variants explicitly before selecting them. See [additional-file results](research/FILE_DISCOVERY_SUMMARY.md).

## Material already preserved

| Material | Verified state |
| --- | --- |
| Encrypted and decrypted 1.14 IPAs | Copied unchanged; SHA-256 values recorded in `original/analysis/archive-manifest.json` |
| Decrypted executable | ARMv7; encryption flag zero; named functions and readable code available |
| Extracted decrypted IPA | All 1,284 non-directory entries preserved under `original/game-files/ipa-1.14/` |
| Level downloads | All 63 URLs from the embedded level list downloaded; ZIP CRC checks passed |
| Costume downloads | All 89 listed images and 89 previews preserved |
| Map coverage | 66 distinct numbered map IDs across bundled and downloaded files; all 54 map IDs referenced by the 148 nonempty offline schedules are present |
| Gameplay data | 18 tower forms / 54 levels, 29 populated enemy definitions, 20 upgrade definitions, 78 medals, 298 mission listings, 149 offline records / 148 nonempty wave schedules |
| Recovered code | Full executable disassembly, function and section indexes, readable strings, and 31 representative function disassemblies |
| Later 1.27 release | Complete mirror IPA and separate extraction; all ZIP CRC checks passed; file-by-file SHA-256 comparison recorded |
| Original remote offline snapshot | Retrieved from the exact S3 URL in the executable; byte-identical to bundled data |
| Original engine source | Not present. Reserve a clearly labeled location for authentic source if it becomes available |

Map presence does not establish that every dependency resolves or every mission plays correctly. The manifests are in [original/analysis](original/analysis/). Two downloaded numbered map XML files fail strict parsing: `map_100.xml` and `map_1004.xml`. Keep raw files unchanged and document narrowly scoped importer repairs. The IPA also has two XML prefix defects, CgBI PNGs, and a PNG stored with a `.jpg` filename.

## Proposed implementation

Use a pinned stable Godot 4 release for rendering, desktop input, audio, and macOS packaging. Official export templates support Universal 2 apps for Apple Silicon and Intel. [Godot macOS export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)

Implement the original hex-grid simulation explicitly. Keep path costs, targeting, range geometry, tick scheduling, projectiles, status effects, and update order under project control. Engine defaults must not determine recovered gameplay rules. Begin with typed GDScript for iteration; use a small C++ simulation module only if measured performance or numerical parity warrants it. Record the language decision after the first replay benchmark.

Separate the application into:

- **Original-data importer:** XML/JSON ingestion, validated source-to-runtime mappings, image/audio conversion, and dependency checks.
- **Simulation:** hex geometry, navigation, spawning, combat, towers, abilities, mission outcomes, seeded randomness, and event logs.
- **Presentation:** sprite frames, shadows, directional animation, layered effects, original interface, camera, and audio.
- **Local profile:** campaign unlocks, spice, XP, upgrades, medals, cosmetics, versioned saves, backup, and recovery.
- **Original multiplayer restoration:** protocol analysis and a replacement service with the original mode semantics.

Rendering must be independent of simulation frequency. Retain explicit 32-bit floating-point behavior where the recovered arithmetic requires it. Do not impose one universal tick: the observed replay path uses 30 ms steps, while the normal update routine has different timing logic that still needs a complete specification.

Suggested implementation directories, created when implementation begins:

```text
game/                 Godot project, runtime content, and presentation
simulation/           Independently testable gameplay rules
tools/importers/      Reproducible conversion and content validation
tests/fixtures/       Evidence-backed mechanics and replay scenarios
docs/mechanics/       Reviewed behavioral specifications
builds/               Local macOS packages and validation captures
original/             Preserved inputs and recovered code; no edits in place
research/             References, observations, and supplied video files
```

## Phase 0: Finish the behavioral reference specification

Estimated focused effort: 1–2 weeks, overlapping with importer preparation.

- [x] Preserve both IPAs and compare their contents.
- [x] Recover all referenced level ZIPs and listed costume images/previews.
- [x] Inventory the data and identify missing maps and syntax defects.
- [x] Save the complete disassembly and previous analysis in this project.
- [x] Research original footage, screenshots, reviews, player guides, and wiki references.
- [x] Search preservation archives, community mirrors, and original developer services for additional files; document verification levels and preserve separate candidates.
- [ ] Annotate the downloaded footage with exact times for menus, placement, upgrades, selling, early waves, abilities, wins/losses, and unlocks.
- [ ] Recover a working reference installation if practical. Treat emulator feasibility as a bounded investigation, not a prerequisite that can stall all work.
- [x] Import the binary into a decompiler and save selected functions and outgoing call graphs. Object-field reconstruction remains partial. [Ghidra](https://github.com/NationalSecurityAgency/ghidra) output requires review.
- [ ] Write mechanics specifications with function addresses, source-data fields, confidence, and pending parity checks.
- [x] Resolve `slow` in embedded schedules: it is an unrecognized stale label and leaves ordinary enum4; the recognized spelling is exactly `slow&strong`. No combat stat scaling was found in the traced spawn chain.
- [ ] Resolve mode-number mappings, XP/star rules, reward reconciliation, continent gates, and co-op unlock conditions.
- [ ] Review 1.27 presentation differences and record which layout/assets belong to the selected original reference. Do not infer later behavior from unchanged offline definitions.
- [ ] Trace enemy threat penalties and smartness so routing follows the original decisions, including routes that may differ from shortest distance.

**Exit gate:** the tutorial and Desert Freighter have reviewed specifications for geometry, spawn timing, movement, money, targeting, damage, progression, and outcomes. Remaining unknowns are named and bounded.

## Phase 1: Import original content without changing it

Estimated focused effort: 3–7 days.

- [x] Build deterministic importers with source hashes and provenance for each runtime asset.
- [ ] Decode CgBI images with correct channel order and alpha; preserve sprite trim offsets, rotated atlas entries, frame sizes, and animation timing.
- [ ] Convert PCM/IMA4 CAF audio into a supported runtime format; retain loop and one-shot semantics.
- [x] Apply documented XML repairs only to derived content. Preserve original bytes and save the repair rules.
- [x] Parse embedded JSON strings for bases, sources, settings, and waves; retain raw serialized fields beside interpreted data.
- [ ] Validate every source ID, base ID, enemy ID, tower branch, sprite reference, map layer, and shared dependency.
- [x] Compare duplicate files across packs and the IPA; save three conflicting paths and explicitly prefer the bundled 1.14 candidate.
- [ ] Build atlas and map viewers for alignment, depth, shadows, and hex placement diagnostics.

**Exit gate:** Tutorial and Desert Freighter render from original assets with correct layer placement; imports reproduce the same hashes and mappings on a second run. All campaign dependency gaps are reported.

## Phase 2: First playable macOS slice

Estimated focused effort: 1–2 weeks after basic imports are available.

- [x] Implement the tutorial's hex geometry, sources, base health, initial money, and authored wave sequence.
- [ ] Implement basic tower placement, construction, upgrades, selling, range, and F/S/W targeting.
- [ ] Reproduce original navigation and blocking rules, including deferred path updates and blocked-route handling.
- [ ] Implement enemy movement, damage, kill rewards, pause, speed controls, and victory/defeat.
- [ ] Recreate tutorial prompts and required actions, including Active Defense.
- [ ] Adapt placement, panning, zoom, cancellation, and selection to desktop input; verify trackpad use without accidental placement.
- [ ] Make Desert Freighter playable from start to finish; save and reload profile progress.

**Exit gate:** both levels can be won and lost. An input recording produces repeatable outcomes in the new simulation. Key positions, timing, damage, refunds, UI geometry, and sound events have reference comparisons; a visually plausible build alone does not pass.

## Phase 3: Complete the original combat systems

Estimated focused effort: 2–4 weeks.

- [ ] Implement all 18 tower forms and 54 level entries, including upgrade branches, buffs, missile variants, radiation, chemical effects, slowing, and nukes.
- [ ] Implement all populated enemy definitions, ground/air distinctions, source/base selection, smart movement, firing, bombing, and directional animation.
- [ ] Reproduce mines, portals, Freeze, Disco Magic, and Active Defense, including stacking, duration, cooldown, ownership, and expiry behavior.
- [ ] Specify simulation update order, numerical rounding, target ties, path ties, speed changes, pause/resume, and random choices.
- [ ] Match effects, explosions, shadows, debris, turret rotation, water, and ambient sound.

**Exit gate:** evidence-backed scenarios cover every original tower branch, enemy family, and ability. Mechanics tests come from recovered rules and observed cases, not assumptions copied from the new implementation.

## Phase 4: Campaign, progression, and original interface

Estimated focused effort: 2–3 weeks, overlapping Phase 3.

- [x] Load all 148 nonempty offline schedules; retain the one empty offline placeholder and online-only listings separately.
- [ ] Implement the original single-player modes and mode-specific stars, timers, base restrictions, and early-wave behavior after mode IDs are confirmed.
- [ ] Recreate the world map, location selection, download/loading presentation, story scenes, career, tech shop, upgrades yard, medals, cosmetic dressing, settings, and credits.
- [ ] Match spice, XP, rank, upgrade points, reset/refund rules, unlock chains, and rewards to the recovered behavior.
- [ ] Use local transactions and versioned saves for offline reliability. Identify any service-derived value that needs an explicit replacement rule.
- [ ] Preserve original unlock costs and progression in the fidelity baseline. Keep actual payments, legacy advertising, and unavailable service screens from blocking local play; document these as platform/service adaptations.

**Exit gate:** all recovered offline missions have been exercised, campaign unlocks reach the intended endpoint, saves survive relaunch, and unexplained reward/progression differences are resolved or recorded as release limitations.

## Phase 5: Fidelity audit and macOS release

Estimated focused effort: 1–3 weeks; deep parity work may extend this.

- [ ] Compare equivalent gameplay states at the source aspect ratio: intro, tutorial, world map, HUD, placement, tech shop, upgrades, pause, effects, and results.
- [ ] Compare paths, spawn schedules, firing cadence, damage, target selection, ability timing, money, XP, stars, and unlocks against a working original or annotated footage.
- [ ] Exercise early and late waves, dense maps, airborne waves, portals, selling to reroute, simultaneous effects, and app focus changes.
- [ ] Verify original controls at 1×, 2×, and 4× with stable simulation behavior; measure frame rate and input responsiveness.
- [ ] Test representative window sizes, Retina scaling, fullscreen, sound settings, and mouse/trackpad navigation.
- [x] Export and launch a standalone macOS app. Local checks and native Apple Silicon evidence are recorded separately. Intel hardware remains unverified and is not claimed as tested.
- [ ] Prepare signing/notarization for distribution when needed, without storing credentials in the project.

**Offline release gate:** no missing critical assets, crashes in tested campaign paths, unexplained core-mechanics deviations, save corruption, or false claims of original online functionality. Publish a fidelity checklist and a concrete list of adaptations.

## Phase 6: Restore the original multiplayer experience

This remains original-game reconstruction, not a new feature expansion. Estimate separately after protocol analysis; allow additional months rather than including it in the offline estimate.

- [ ] Recover client commands, room snapshots, event ordering, timing correction, ownership, readiness, reconnect, and matchmaking semantics.
- [ ] Confirm Cooperative, Competition, and Camps rules from code and original recordings.
- [ ] Define a replacement service and local/LAN harness; preserve the original shared-wave and player/base rules.
- [ ] Validate multiple clients, desynchronization recovery, joining/leaving, reward settlement, and the supported player counts for each mission configuration.
- [ ] Recreate the lobby and social presentation with explicit adaptations for unavailable identity/friend services.

**Full reconstruction gate:** original supported modes work with multiple clients and a documented backend replacement. Do not infer hosted-server source or operational services from the client binary.

## Acceptance scenarios and evidence

| Scenario | What must be verified |
| --- | --- |
| Tutorial | Required actions, prompts, initial balances, wave progression, and ability introduction |
| Desert Freighter | Original map, waves, routes, early waves, selling, completion rewards, and stars |
| Wooden Walls | Mixed air/ground waves, electric/chemical/AA branches, money pressure, and strategic routing |
| Portal/mine maps | Ownership, cooldown, rerouting, activation, expiry, and blocked-path cases |
| Late campaign / Madagascar | Dense enemies, special rules, progression endpoint, and stable performance |
| Profile restart | Exact balances, unlocks, upgrade levels, medals, cosmetics, and backup recovery |
| Multiplayer | Shared waves, mode outcomes, synchronization, player departure, and settlement |

Maintain a table for each scenario with source/version, original input conditions, expected result, new result, screenshot/clip, confidence, and discrepancy. Strategy posts identify useful scenarios but cannot dictate exact formulas.

## Timeline and risk

Planning estimate for one experienced developer working with Codex: first playable slice in roughly 1–3 weeks after implementation starts; strong offline recreation in roughly 8–12 weeks; close edge-case and presentation parity may need 3–5 months. Phases overlap, so their ranges must not be added mechanically. Re-estimate after the first slice.

The largest risks are object-field reconstruction, path/target ties, numerical timing, service-derived progression, downloaded-version conflicts, and insufficient original recordings. Archive recovery has substantially reduced the missing-map risk. A complete gameplay dependency audit and runtime reference remain necessary.

## Future expansion after reconstruction

Record the long-term direction: more levels, towers, upgrade branches, abilities, and features. Preserve stable content IDs, a separate original campaign, versioned saves, and data-driven definitions so expansion can be added later without changing the original baseline. Do not design new balance, produce new art, or implement expansion content during the clone phases. Accept the original reconstruction before selecting expansion work.

## First implementation session

1. Read this plan, the research findings, and the original archive notes.
2. Inspect current files and any Git state; preserve subsequent user changes.
3. Establish repository and tool versions, with original material remaining separate.
4. Complete the tutorial/Desert Freighter mechanics specifications and the content dependency audit.
5. Begin Phase 1 importers, followed by the Phase 2 playable slice. Keep the plan updated with verified results and unresolved differences.
