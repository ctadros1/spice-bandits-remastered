# Spice Bandits macOS Reconstruction Plan

R169 recovery is complete and verified in [private draft415633968](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/untagged-a87f6d5e106b41ac26d1): six assets totaling1,570,724,569bytes. The actual downloaded1,567,151,882-byte archive (SHA6634565d4c08cec4529c1275b4e24472746376cd6777e403a22e517c70427dfc) verifies2,311members and restores648candidate plus648current-source files with exact bytes/executable modes and pinned signatures. Strict restored app signature, native isolated launch from an external empty working directory, all4protected saves and every remote asset digest/size pass. Audit: docs/backups/2026-10-17-r169-health-anchor-failure.json. All build/native/functional/backup sessions completed; no game remains. The performance failure and first obsolete-QA-check failure remain preserved. Full offline goal remains active/incomplete.

R169 corrected native batch completed/reaped:549presentation/216captures and exact15RGBA/12geometry comparisons pass; performance still fails the unchanged33.34ms median limit at35.063/40.250/45.593ms (p9538.896/46.676/49.920), world6.028/14.227, zero stalls. All4save/package/signature/isolation/cleanup guards pass. Exact corrected app/galleries/full648source freeze/empty-clone bytes/modes/pinned signature verified under builds/creep-health-offset-r169-candidate.210/216PNG exactR165; two corrected health bars and four randomized transitions reviewed full resolution; all six health images exact the first correct-runtime R169 package. AcceptedR137guide stays frozen. All eight separate functional suites pass and completed cleanly; all four saves/package/signature/isolation/cleanup guards pass. Authoritative builds/creep-health-offset-r169-functional-followup.json/log. No game remains. R169 private app/evidence recovery preparation is next; do not rerun unchanged performance. Source480694f7f03ad1df79bf4bd08a354f010b600623 is signed, locally verified and confirmed on private main. Full offline objective remains active/incomplete; no expansion/multiplayer or asset stretching.

Current R169 corrects health-bar anchoring: the original full Creep.Render reads raw animator position, independently of body offsets. The new 128-case original fixture independently repeats SHA-256 `4ffdadfe0596c24c76b79f881c0e93a73b288d0bad1bf7d0e39cb684589ce3db`. Actual Main comparison now passes 1,089 checks after preserving 128 pre-port failed assertions. All 3,104 existing health checks (576 original cases) and 82 runtime script checks pass. Only two prior reconstruction-bridge expectations changed to the newly recovered raw anchor; no original fixture or tolerance changed. Full R169 source/build passes (4,035 originals unchanged; all required gates and 82 runtime scripts). Corrected packaged presentation/rendering and all eight separate functional suites pass; unchanged performance fails as recorded above. See builds/creep-health-offset-r169-corrected-native-suites.json and the separate functional-followup.json. R165 remains separately frozen and restore-verified.

R165 source/build, 549 presentation checks/216 captures, 15 exact RGBA pairs, 12 geometry comparisons and all eight separate functional suites pass. Performance fails the unchanged 33.34 ms median limit at 35.828/39.129/45.210 ms (p95 39.170/44.015/49.961), zero stalls/errors. All four save/package/signature/isolation/cleanup guards pass. All 4,035 originals are unchanged. R137 remains the last published all-ten historical app and accepted guide; the full offline reconstruction is incomplete.

R165 private recovery is verified from the actual downloaded archive: [draft 415627522](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/untagged-9b2b038775c30000ba61), six assets/988,107,952 bytes, 1,381 verified members, 638 candidate and 639 signed current-source files restored with exact bytes/executable modes/signatures, strict restored app signature and isolated native launch from an external empty working directory. All four external saves remain unchanged. Audit: docs/backups/2026-10-17-r165-creep-state-failure.json. Source 7f5c825d7b6535e9e69a2b123431e03940dcdadc is signed, pushed and confirmed on private main. Later R168/R169 research, publication records and correction are currently dirty; preserve them. Normal signing works now; future signing errors must not halt development.

R166/R167/R168 independently executed original movement/position, Freeze owner ordering and primary RenderFrame. Hover continues during Freeze even when walking/animation stop; retained hover offsets are not multiplied by sprite scale. Actual hover motion, original audio ownership, full status/float/portal/growth joins and the initial working-smoke-field correction remain open in docs/mechanics/CREEP_STATE.md. No hover-motion port after R165. Preserve the immutable R151/R146 gates and unchanged performance limit.

Next: continue the bounded performance work in builds/r170-next-implementation.md, then the remaining original state/hover/render, UI, sound and progression gaps. No expansion or multiplayer. The complete pre-R169 running notes are preserved in [history](docs/history/PLAN_BEFORE_R169.md); the roadmap and required presentation checklist below remain authoritative.

## Objective and completion boundaries

Recreate Spice Bandits for macOS using version 1.14 as the recoverable behavioral reference and the supplied iPad TouchGameplay recording as the main visual and interaction guide. Keep the preserved assets at their original proportions: the recording appears stretched. Use a fixed 1024×768 iPad canvas with borders when necessary; dynamic monitor-filling layout is deferred. Preserve the original art, animations, music, effects, campaign geography, tower branches, enemy behavior, mission rules, and progression. Adapt touch input to mouse, keyboard, and trackpad while keeping the original visual hierarchy.

Deliver the original single-player game first. Restore original multiplayer modes as a distinct part of the reconstruction roadmap. An offline release is a meaningful milestone, but it must not be called a complete clone of the online original. New levels, towers, upgrades, rebalancing, and new features are deferred until the reconstruction is accepted.

The implementation is now authorized. Continue through the offline phases before multiplayer, preserving the original files and recording unresolved differences. No expansion content is included.

## Required presentation reconstruction

These are completion requirements, not optional polish. Compare each against dense captures of all supplied videos, with the iPad recording taking priority for composition and interactions. Preserve asset proportions, source evidence and normal saves.

- [ ] Restore the original tower and ability tray, slots, selection, prices and drag-and-drop placement with a moving preview and valid/invalid drop feedback.
- [ ] Restore the original location/mode window, locks, stars and transitions.
- [ ] Restore the animated Earth loading window and its transition into a map.
- [ ] Restore the original result window, XP bar, spice/medal rewards and reveal animation.
- [ ] Align tutorial text, bubbles, arrows, build markers and camera transitions to the reference.
- [ ] Match electricity and the other authored combat animations, layers and timing against dense sequences.
- [ ] Review every supplied video using full-resolution captures, including menus, promotion, shop, career and fitting.
- [ ] Verify matched screen states and physical drag-and-drop in the newly packaged app; existing functional audits do not close these requirements.

## Implemented offline systems

The current game loads all 148 nonempty offline schedules and uses original maps, art, animation metadata, fonts and sounds. Placement/upgrades/selling, native path and target rules, combat/support forms, abilities, campaign access, local transactional saves, tutorial, menus, results and progression adaptations are implemented with bounded original-code and packaged checks. These do not establish complete fidelity. See docs/FIDELITY.md and the mechanics specifications for each remaining limit.

The preserved earned campaign has 1,970 battles and 67 distinct wins, including all 54 Normal missions and Madagascar. Its four normal/earned profile files remain protected. Later hosted progression thresholds/ranks/rewards remain explicit local adaptations; no working original installation/save was supplied. Physical trackpad gestures, speaker listening, Intel execution and distribution notarization remain unverified.

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
- [x] Annotate145 sampled footage frames with exact times for menus, building, upgrades, selling, abilities, victory and unlocks. Sampled clips contain no verified defeat overlay; version/input-state limits are recorded.
- [x] Complete the bounded reference-runtime investigation. Original ARM function probes provide narrow evidence; no working original iOS installation is claimed.
- [x] Import the binary into a decompiler and save selected functions and outgoing call graphs. Object-field reconstruction remains partial. [Ghidra](https://github.com/NationalSecurityAgency/ghidra) output requires review.
- [x] Write mechanics specifications with function addresses, source-data fields, confidence, and pending parity checks. See `docs/mechanics/`; unresolved field/state comparisons remain listed.
- [x] Resolve `slow` in embedded schedules: it is an unrecognized stale label and leaves ordinary enum4; the recognized spelling is exactly `slow&strong`. No combat stat scaling was found in the traced spawn chain.
- [ ] Resolve mode-number mappings, XP/star rules, reward reconciliation, continent gates, and co-op unlock conditions.
- [ ] Review 1.27 presentation differences and record which layout/assets belong to the selected original reference. Do not infer later behavior from unchanged offline definitions.
- [x] Trace enemy threat penalties and smartness, ordered links, native A* comparison and smoothing. Per-player/escort/isolation filters remain explicit comparison gaps.

**Exit gate:** the tutorial and Desert Freighter have reviewed specifications for geometry, spawn timing, movement, money, targeting, damage, progression, and outcomes. Remaining unknowns are named and bounded.

## Phase 1: Import original content without changing it

Estimated focused effort: 3–7 days.

- [x] Build deterministic importers with source hashes and provenance for each runtime asset.
- [x] Decode CgBI images with correct channel order and alpha; preserve sprite trim offsets, rotated atlas entries, frame sizes, and authored timing. Atlas sampler and complete animator parity remain in the fidelity checklist.
- [x] Convert PCM/IMA4 CAF audio; retain complete loop boundaries and resource-specific one-shot/loop semantics. Native mix/lifetime comparisons remain separately bounded.
- [x] Apply documented XML repairs only to derived content. Preserve original bytes and save the repair rules.
- [x] Parse embedded JSON strings for bases, sources, settings, and waves; retain raw serialized fields beside interpreted data.
- [x] Audit source/base/enemy IDs, tower branches, sprite references, map layers and dependencies. Invalid source/null enemy slots follow native guards; obsolete metadata references are retained as reported gaps.
- [x] Compare duplicate files across packs and the IPA; save three conflicting paths and explicitly prefer the bundled 1.14 candidate.
- [x] Build atlas and map viewers for alignment, depth, shadows, and hex placement diagnostics. The separate read-only local inspector covers108 resources/67 maps, crop/rotation/flip/offsets, extras/shadows, map layers/current depth and authored hex/config markers. Actual browser controls and two exported PNGs were reviewed; it does not establish original GPU/depth parity.

**Exit gate:** Tutorial and Desert Freighter render from original assets with correct layer placement; imports reproduce the same hashes and mappings on a second run. All campaign dependency gaps are reported.

## Phase 2: First playable macOS slice

Estimated focused effort: 1–2 weeks after basic imports are available.

- [x] Implement the tutorial's hex geometry, sources, base health, initial money, and authored wave sequence.
- [x] Implement placement, immediate native activation, upgrade branches, selling, elliptical range and F/S/W targeting;164 isolated original ARM target comparisons pass.
- [x] Implement native ordered paths, threat costs, smoothing, deferred updates and blocked-route rollback; remaining ownership/isolation cases are bounded in the fidelity list.
- [x] Implement movement, damage, kill rewards, pause,1x/2x/4x and victory/defeat.801 isolated original movement comparisons and native input checks pass; remaining state filters are listed.
- [x] Recreate all18 tutorial pages and required actions, including Active Defense.68 packaged checks pass; exact camera/pointer animation remains a presentation difference.
- [ ] Adapt placement, panning, zoom, cancellation, and selection to desktop input; verify trackpad use without accidental placement.
- [x] Win and lose Desert Freighter; save and exactly reload earned profile progress.

**Exit gate:** both levels can be won and lost. An input recording produces repeatable outcomes in the new simulation. Key positions, timing, damage, refunds, UI geometry, and sound events have reference comparisons; a visually plausible build alone does not pass.

## Phase 3: Complete the original combat systems

Estimated focused effort: 2–4 weeks.

- [x] Implement and exercise all18 forms/54 levels, branches, buffs, missiles, radiation, chemical effects, slowing and nukes. Remaining projectile/effect parity limits are listed separately.
- [x] Implement all29 populated definitions, authored ground/air classes, source/base selection, native routes, firing/bombing and directional animation. Unproven escort/isolation/per-player cases remain fidelity limits.
- [x] Implement and check mines, portals, Freeze, Disco and Active Defense, including traced stacking/duration/cooldown/expiry. Offline ownership and static mine/portal cases are exercised.
- [x] Specify live/replay updates, numerical rounding, ordered target/path ties, speed/pause and random choices. Unrecovered global RNG and complete subsystem ordering are explicit limits.
- [ ] Match effects, explosions, shadows, debris, turret rotation, water, and ambient sound.

**Exit gate:** evidence-backed scenarios cover every original tower branch, enemy family, and ability. Mechanics tests come from recovered rules and observed cases, not assumptions copied from the new implementation.

## Phase 4: Campaign, progression, and original interface

Estimated focused effort: 2–3 weeks, overlapping Phase 3.

- [x] Load all 148 nonempty offline schedules; retain the one empty offline placeholder and online-only listings separately.
- [x] Implement Normal1, Sudden Death3 and Air Attack6, native perfect-game stars, survival/freeze timers, authored base restrictions and early waves.
- [x] Implement world/location/story navigation, career, shop/upgrades, medals, fitting, settings and credits with preserved artwork. Local loading replaces downloads; streamed intro and exact transitions remain listed differences.
- [x] Preserve recovered spice/kill XP/points/refunds/unlocks/rewards; explicitly document local replacements for unavailable later level/rank/promotion data.
- [x] Use versioned transactional local saves, verified backups, bounded recent history with complete linked snapshots, and documented service-derived progression replacements.
- [x] Preserve authored costs and unlock chains, record the two access bridges, and keep unavailable payments/ads/identity/friend services from blocking offline play.

**Functional evidence only; offline completion gate remains open:** all148 missions are exercised, all54 Normal missions have saved wins through the endpoint, exact relaunch checks pass, and service-derived progression differences are documented release limitations.

## Phase 5: Fidelity audit and macOS release

Estimated focused effort: 1–3 weeks; deep parity work may extend this.

- [x] Review preserved footage and packaged scene captures, including a seven-scene comparison sheet. Encoded aspect/version/input states are unverified, so this is a bounded presentation audit rather than pixel equivalence.
- [ ] Compare paths, spawn schedules, firing cadence, damage, target selection, ability timing, money, XP, stars, and unlocks against a working original or annotated footage.
- [x] Exercise early/late battles, all148 schedules, air/mine/portal maps, selling/reroutes, concurrent effects, dense native rendering and covered-window/fullscreen restoration.
- [x] Verify1x/2x/4x replay/live behavior, isolated original timer/movement math and measured native frame times. Current native keyboard/window and historical mouse checks are scoped separately.
- [ ] Test representative window sizes, Retina scaling, fullscreen, sound settings, and mouse/trackpad navigation.
- [x] Export and launch a standalone macOS app. Local checks and native Apple Silicon evidence are recorded separately. Intel hardware remains unverified and is not claimed as tested.
- [ ] Prepare signing/notarization for distribution when needed, without storing credentials in the project.

**Offline release gate (not passed):** preserved campaign assets are present, tested paths and native audits have no crashes/errors, saved progress survives relaunch, normal saves remain protected, and adaptations/remaining comparison limits are published. This local milestone does not close the exact-parity checklist or certify Intel/trackpad/notarized distribution.

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

## Original starting procedure (historical)

1. Read this plan, the research findings, and the original archive notes.
2. Inspect current files and any Git state; preserve subsequent user changes.
3. Establish repository and tool versions, with original material remaining separate.
4. Complete the tutorial/Desert Freighter mechanics specifications and the content dependency audit.
5. Begin Phase 1 importers, followed by the Phase 2 playable slice. Keep the plan updated with verified results and unresolved differences.

R169 first packaged run completed/reaped with exactly one obsolete verification expectation: "health bar follows lifted animator". All216captures were retained. Its exact app/gallery/full648-file source and signed-base7f5c825+working patch are empty-clone bytes/modes/signature verified under builds/creep-health-offset-r169-first-native-failure. The check now compares both coordinates to raw visual position+(-16,16), matching the128new original cases. No original expected fixture/tolerance was changed; gameplay code is unchanged from the first R169 build. The targeted corrected rebuild passes original hashes/editor import/all82scripts/original health comparisons/strict signature. A frozen source comparison proves presentation_verify.gd was the only game/native source change after the full passing R169 build. Fresh corrected native batch is running under creep-health-offset-r169-corrected; inspect its native-suites.json/log and do not overlap engines.
