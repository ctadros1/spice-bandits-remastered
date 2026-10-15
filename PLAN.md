# Spice Bandits macOS Reconstruction Plan

Current package r103: all ten native suites pass, including344 presentation checks/113 PNGs and the unchanged live performance gate. Aircraft missile layering and the inherited result-screen timer are restored within the documented source-probe limits. Offline fidelity remains incomplete.

Updated October 15, 2026. Status: offline reconstruction is incomplete. The saved simulation campaign reaches Madagascar; all ten current native suites pass including the live performance gate; these checks do not establish original visual or interaction fidelity. The user review identified substantial missing original interface and animation behavior. Multiplayer and expansion remain deferred.

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

## Current implementation progress

R103 preserves the original closed result-screen timer across victory. It advances with unscaled active-room time, stops during pause/loading and lets XP begin after the opening fade during a normal-length battle. Six original constructor/closed/open-update cases and24 full room-caller cases support11,038 source comparisons. The complete service/GUI-heavy Open is omitted by the probe; its opening flag is supplied. R102 also restores visible aircraft missiles before all aircraft bodies in manager/per-owner order, supported by192 original owner cases/464 callbacks and421 source checks. Original missile suppression/lifetime, ground double-after and full owner/preview/global effects remain open.

All ten r103 native suites pass on one frozen package: presentation344/113 PNGs, menus184/55, tutorial88/20, audio50/23 WAVs, projectiles4, turns5, towers1, Desert1 and campaign148. Live1×24.544ms median/26.312ms p95,2×25.353/31.112 and4×31.509/34.438 meet the unchanged33.34ms median gate; world6.676/13.749 passes. All live/input-isolation guards pass with zero stalled frames. Three mesh/direct particle and three old/prepared creep-layer/completed-growth frozen pairs match exact RGBA.351 counted PNGs/23 WAVs retain15 supplemental frozen-comparison PNGs separately. Normal/retained-campaign saves, package resources, strict signature, isolation and process cleanup pass. Historical r101 fixture, r102 runner-count and4× performance failures remain retained; this is not original-device equivalence.

The fresh r103 comparison binds45 paired states/12 inspected sheets to its PCK, executable and helper and freezes90 hashed full-resolution frame copies.180 additional unwarped original frames retain actual presentation timestamps around the tutorial result. Six result pairs use approximate phase alignment with matching8XP/3sp amounts and the inherited room timer; precise first emission/RNG and older-version differences remain open. Other tutorial input, camera, stock and portrait ages still differ. Every original fidelity checklist item remains open. builds/presentation-comparison-r103-review.json records the review; the prior r100 comparison remains separately retained.

The tray/ability inventory and drag previews, mode fan, animated Earth loading, result XP/spice/medal clocks, tutorial callouts and core menu/shop/upgrade/promotion layouts now use preserved art, NIB declarations and bounded recovered-code comparisons. They remain reconstruction work until equivalent-state visual and interaction review closes the required presentation checklist. The fixed4:3 canvas preserves asset proportions. [Fidelity](docs/FIDELITY.md) and [mechanics notes](docs/mechanics/BASELINE.md) retain the specific differences.

R97 separated aircraft bodies from the ground list in original manager order. R98 restored the selected range fill/three outlines after ground bodies and before aircraft. R99 adds creep height alongside the restored tower/base depth. Original mutable ground registration/ties, complete preview/owner/missile/bubble/global-effect interleaving, global jitter/RNG, exact UIKit raster and full animator/panel lifetimes remain open. [Render routing](docs/mechanics/MAP_RENDER_ORDER.md) and [creep depth](docs/mechanics/CREEP_PRESENTATION.md) give the bounded original functions and explicit stubs.

The retained earned campaign records67 distinct wins across1,970 actual battles, including every54 Normal mission and Madagascar, with an unchanged reload. It used the earlier documented local progression policy. The main recording establishes level2's31/55 XP footer and the first observed rank/reward; later service thresholds/ranks/rewards remain unavailable. Neither the IPA nor the first emulator startup attempt supplied those hosted values. Existing earned saves are preserved. [Progression recovery](research/PROGRESSION_RECOVERY.md) distinguishes observations, recovered client rules and fallback data.

The five-video corpus retains4,440 captures/81 sheets. Complete contact timelines and selected dense/full-resolution states were reviewed; not every frame was inspected. Physical tutorial/input evidence remains bound to its older packages; current suites use isolated engine actions. Shared-Mac pointer interference is not a reason to ask repeatedly for focus/unlocking. Trackpad gestures, speaker listening, Intel execution and notarized distribution still need verification. The r100 comparison now passes its package prerequisites and freezes its own full-resolution images; older sheets retain their own bindings.

All4,035 original-file hashes remain unchanged. A read-only atlas/map inspector is available separately. The full reconstruction chat goal is active, and signed source checkpoints through r98 are pushed to the authorized private GitHub repository. The 1Password signer failed twice during r99; its20 staged files remain intact and a verified private recovery patch restores every changed byte over r98. R100 signing/history is pending that credential service, with further checkpoint coverage tracked in the backup notes. Checksummed private release snapshots preserve large original/toolchain/package/evidence files; [backup instructions](docs/BACKUP.md) describe their exact coverage. Detailed superseded checkpoint records, source counts, failures and input evidence are retained in [history](docs/RECONSTRUCTION_HISTORY.md). Multiplayer and expansion remain deferred.

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

## First implementation session

1. Read this plan, the research findings, and the original archive notes.
2. Inspect current files and any Git state; preserve subsequent user changes.
3. Establish repository and tool versions, with original material remaining separate.
4. Complete the tutorial/Desert Freighter mechanics specifications and the content dependency audit.
5. Begin Phase 1 importers, followed by the Phase 2 playable slice. Keep the plan updated with verified results and unresolved differences.

## Earlier implementation records (superseded checkpoints)

The following entries retain earlier package hashes, failures and campaign checkpoints. The current progress and offline release notes above supersede their incomplete-status statements.

## Earlier offline fidelity work

TutorialView.nib now supplies the original portrait panel, wrapping dimensions and tablet anchoring. Base/source, HUD and build-dock hints are separate. The full packaged tutorial still passes after the label layout correction. The world map uses38 preserved static marker textures and hides inaccessible missions according to the native guard. Exact dock/popup, camera and UI shading remain open.

Enemy corner positions and physical turn rotations/alpha are ported, with576 turn cases,64 preparations and5 projections from bounded execution of the original ARM math routines. These checks execute isolated functions with documented stubs, not the whole original app. A finite-position guard handles degenerate reverse corners. See [enemy presentation](docs/mechanics/CREEP_PRESENTATION.md). Normal movement overshoot and mid-cell reversal are now traced and tested; full shadow/animator/depth equivalence remains open.

Separate game/lobby sound banks, native music gain/continuity, full sample loop boundaries, resource-specific death/firing cues, AA loop tails and magic expiry sounds are restored. A packaged PCM replay passes31 checks over14 stages. Positional/ambient mixing and complete native sound-object lifetimes remain open; see [audio](docs/mechanics/AUDIO.md).

A turn-gallery audit detected a normal-save hash change during its run. Attribution is unresolved; current primary/backup copies are retained and no user save is replaced. Verification now has a write-level guard against the normal path, runtime isolation records and before-content snapshots. A malformed guard expression was caught before export; it was corrected before export. The rebuilt Universal2 package passes the five-pose turn gallery,60 tutorial checks/19 captures and31 audio checks/14 WAV stages. Runtime isolation and unchanged normal-save hashes pass in all three on PCK`2901c9f1ff11d07e0c136b4274b2f8315a272236469f8b68eb3c63162a575613`. Release gates remain open.

The selected-tower popup now uses the original97×74 sell/upgrade buttons,96×71 branch plates and65×43 branch icons. F/S/W settings follow the projected tower and camera, with the native71-pixel spacing. Confirmation uses the preserved121×74 artwork beside the sell widget and an outside click to cancel. The headless tutorial passes after this change; fresh packaged confirmation/input checks are pending.

Normal path movement now follows the native frame-boundary transition and carries the full progress increment capped at0.3. Kamikaze hits occur after the midpoint of the final base link.225 isolated ARM comparisons cover speed, segment lengths, carries and boundary frames. The updated tutorial wins with16 kills,98% base health and$168 at75,690ms. Mid-cell reversal thresholds are now ported; full attacker/escort state parity remains open.

Native medal identities, match tier selection, nine special challenges, repeat award counts/XP and top-upgrade/kill-chain counters are implemented with23 focused checks and transaction rollback. See [medal rules](docs/mechanics/MEDALS.md). The server-derived level/rank curve and promotion rewards remain explicit gaps.

The six original environment loops now play at native gain0.2 (urban0.15), with battle/menu lifetime and sound-setting control. Important effects ease ordinary effects to0.85 over500ms; crowded playback uses the native per-update gain changes. The latest packaged mixer replay passes36 checks/16 WAV stages on PCK`10b06f5265e5f986311f1a7353c0dadd3e699eb59d490bb74797ff9194309521`, including unchanged normal saves and runtime QA isolation. Positional sound, radiation cue ownership and complete shooting-loop lifetimes remain open.

Mid-cell path changes now retain segment progress and implement the native reversal thresholds. The updated legal-budget wide-placement probes win Containers (25% base health,12 towers) and Madagascar survival (31.1% aggregate base health,30 towers), with all technology/upgrades and five combat magic items pre-owned. This is not fresh-profile progression. The broader sweep completed:74 victories,73 defeats, zero still-playing outcomes across147 non-tutorial schedules; technology/upgrades/magic were pre-owned.

PCK`74de9386b8ff26a17e15286e6c9f4eed4c44eeb691a61329b0bcab964aa7d6f4` passes the five-pose turn gallery and60 tutorial checks/19 captures after native movement, mid-cell routing, original popup sizing and shadow changes. Native macOS inputs on the preceding`ded6e541...` package verified placement, level2 upgrade, branch choice, weakest targeting, outside sale cancellation and a$30 refund; they exposed the button minimum-size issue corrected in this package.


## Continuing offline implementation

The Career, Tech Shop, Upgrades Yard, medals, fitting room, credits, pause and result screens now use the preserved NIB/atlas artwork.18 packaged menu captures exercise purchases, failed-save rollback, reload, point refunds, temporary costume previews, Africa access and battle navigation. The original Africa offers are42 spice or a free pass at level16; empty config322 remains an access descriptor. See [interface reconstruction](docs/mechanics/INTERFACE.md). Exact native transition/paging/reward-reveal details remain open.

Fresh stock and purchase behavior are resolved: zero magic outside training; five of each item only in training. In-battle empty-stock purchases require a later activation, and technology unlocks require a separate battle-money upgrade. Saves preserve nativef32 XP across decimal serialization/reload. Level2 uses the observed earlier-release5-spice/3-point reward; later curve/rewards/ranks remain explicit local replacements. See [progression](docs/mechanics/PROGRESSION.md).

The saved fresh campaign probe has won tutorial, Desert Freighter, Pillar Garden, Line, The Cave, the required Silver Mine Sudden Death and its Normal mission. A bounded strategy stalled on Buenos Aires; its results are retained. A revised probe is earning actual repeat rewards to buy permanent sniper/missile technology before retrying. No endpoint claim is made while this run is incomplete.

The importer now retains90 authored particle definitions and23 bindings. Native particle integration/opacity has48 bounded ARM cases; original debris, child smoke, low-health/base smoke and enemy status effects render with simulation-clock lifetimes. Remaining effect callbacks, emission/random/depth parity and electrical/water effects are documented in [particle reconstruction](docs/mechanics/PARTICLES.md). Original preservation remains4,035 checks with zero changes.


## Targeting and standalone audit update

Original GetNearestCreep0xfb9b0 now has164 bounded ARM cases. The port preserves its record-low grid-distance candidate list, strict tie handling, effective-speed selection, truncating Strongest HP threshold, original ground/air resource class, state filters and source owner/target-owner fields. This corrects the earlier assumption that F/S/W examines every in-range enemy. See [targeting evidence](docs/mechanics/TARGETING.md).

The current PCK`244391dc04842b535b1cf37ecd6906b978fbd8d027becbe49b32f6ea08cbc927` passes68 tutorial checks/20 captures,54 menu checks/18 captures,36 audio checks/16 WAV stages, four projectile stages, five enemy turn poses, all54 tower forms, Desert Freighter and148 fresh campaign renders. Normal primary/backup saves stayed unchanged in all runs; codesign and runtime isolation passed. These rendered fixtures are separate from OS mouse-input evidence and winning campaign progression.

Promotion notices now reconstruct from saved reward transactions and acknowledge their level transactionally. They survive relaunch, pause combat while open, retain their dialog if acknowledgement cannot be saved, and never grant their reward twice. The fitting room now uses the original two-row horizontal arrangement. Electric/gravity effects use the preserved beam art; gun/AA muzzle flashes use tower_fire. Enemy deaths and ordinary missile hits no longer borrow the mine explosion. Native ribbon blending/randomness, transitions and detailed callback parity remain open.

The earned saved campaign has additionally won Buenos Aires Normal and Buenos Aires Airport Sudden Death. The Airport win came from replaying legal actions found with the same earned upgrades; automatic wave records are excluded from user actions. The current campaign has not reached Madagascar. Africa strategies, including affordable original consumables, are being investigated without changing combat rules or adding funds. Historical failed attempts remain preserved.


## Live timing and measured performance work

The original one-player Update0xd2768 multiplies elapsed time by1/2/4 and dispatches one UpdateGame0xd338c per frame; fixed30ms steps belong to SimulateGame0xd8f48. Ordinary offline play now follows that distinction, with22 bounded original ARM dispatcher/timer cases and576 additional variable-frame movement cases (801 movement cases total). Replay/tutorial corpus checks retain fixed steps. See [update timing](docs/mechanics/UPDATE_TIMING.md).

A small Universal2 C++ helper now handles elliptical range/ordered targeting, movement and particle integration/emitter updates. It preserves explicit32-bit rounding, passes164 original target cases and all authored particle definition comparisons, and keeps child-emission order/RNG/expiry checks. The measured language choice follows the original plan; no combat values or content were changed. The dense native fixture now passes with22.348/24.784/29.816ms median frame times at1x/2x/4x. Its4x95th percentile is64.675ms, so this is a bounded median-rate pass, not a claim of uniformly smooth frames. Failed timing evidence is retained.

The saved earned campaign now has29 distinct wins, through Normal mission17. Its actual level53 account owns Nuke3, Sniper3, Gatling3 and AA3; original15-spice/10-point exchanges funded economic upgrades. No starting grants, wins or altered prices were used. Earned-profile diagnostic strategies remain separate from saved victories. Madagascar remains uncompleted.


Long-play save verification exposed a growing transaction journal. The active save now compacts after1024 ordinary events, retaining256 recent records and all promotions; checksum-verified full snapshots link the complete prior history. Balances, XP, stocks and completion tokens do not change. The first QA archive implementation created snapshots too frequently; those files remain preserved and its index migrates into the new chain. Current source/menu checks cover compaction, archive contents/links, head reuse, relaunch and pending notices. Earlier native mouse/keyboard checks verified pause/clock hold,2x/4x controls, pan, zoom and quit with unchanged normal-save hashes; their hashes remain historical, and current physical input waits for the Mac to be unlocked.


## Offline endpoint and final presentation audit

The actual saved fresh-profile probe reached Madagascar with77.78% aggregate base health,45 towers and5,108 raw score after1,237,050 simulated ms. Freeze pauses the15-minute survival timer; extending the verification harness to30 minutes corrected its earlier18-minute ceiling without changing gameplay. All54 Normal configurations are saved as victories. Budget shortages trigger real repeat victories before buying original supplies; blocked strategy searches return a saved checkpoint instead of indefinitely farming unrelated levels. Saved history preserves the full earlier run and its interruptions.

Original1.14 strings restore the four build captions (`build here`, `& here please`, `here too`, `place tower`), final tutorial guidance, `Yay! You did it!` / `You failed!`, and original battle/XP statistic labels. Five main navigation tabs restore Map/Career/Tech shop/Upgrades yard/Spice. Footage comparisons remain version-qualified; exact UIKit transitions and row geometry are not asserted.

Final October14 package: PCK`b5f4701d473dd406b45d8d313d04f5c55c587da932f860efdcfe5a9e37a568ae`, all nine native audits passed;75 tutorial/71 menu/36 audio checks,148 campaign captures, source41,536/UI55/menu51. Dense medians24.555/25.581/26.656ms at1x/2x/4x meet the predefined gate, with workload/frame-time limits retained. Original4,035 hashes and normal-save protection pass. Functional offline release is complete; exact-parity and untested-platform items remain explicitly open.


Portrait art/text now share an independent500ms opening/removal clock, retain their control identity across HUD rebuilds, disable dismissal during animation and release closing controls on completion.60 original UIKit request/block cases plus actual lifecycle checks pass313 comparisons; default compositor/easing and advanced afterClose/touch behavior remain separate limits. Native quarter-second opening/removal captures were inspected. Menu/presentation galleries pose the independent portrait clock for readable states; the actual tutorial waits through it and wins at86070ms,270ms later than r31, with unchanged16 kills,$168 and98% health.


October14 r33 save-audit interruption: the first PCK5307b51c presentation run passed115 fixture assertions/49 captures but failed the protected normal-save check. Before/after primary and backup bytes are preserved in builds/qa-isolation-investigation-r33; no normal save was restored or overwritten. The normal account already had additional gameplay progress before that run and gained Desert Freighter victory/purchases during it. Runtime QA isolation was reported, but attribution is unresolved. A repeat on the same PCK passed115/49 with unchanged current primary/backup hashes and only the QA process observed. The harness now records app process identities, refuses an already-running game/engine instance, retains before/after save bytes and hashes, and rejects concurrent game instances. This repeat does not erase or explain the failed audit.

Native r39/PCKa3c2793d completed the tutorial through CUA mouse/keyboard input: four tray drags, three upgrades, confirmed sale, Disco, Active Defense, mine at7,6, Space pause/resume, victory, To the map, guidance dismissal and the unlocked Desert Normal fan. During pause the actual saved state retains page17 pending/display16/wave2/spawn hold; resuming launches wave3 once. Victory has20 kills,$181,81 score and100% base health; the separate checksum-valid save retains8.100001335144043 XP,3 spice,tut and completed1 with no normal tutorial career-stat increment. Native screenshots and runtime observations agree. Command-Q exits0, signature/isolated paths/only-QA process and all normal/campaign/package protected hashes pass. builds/tutorial-native-input-r39/input-observations.json records the exact scope; loading is skipped under this QA flag, and trackpad/Intel/audio listening/original pixels remain unverified.


Native r45/PCK `e4f3c055` now completes the earned tutorial through CUA mouse/keyboard input, including rejected water/occupied drops, four legal tray drags, three upgrades, confirmed sale, Disco, Active Defense, mine placement and paused boss-transition resume. The actual victory records19 kills,$180,80 score,99.5% base health and8.000000953674316 saved XP; the checksum-valid unique account receives3 spice andtut, with no normal tutorial career-stat increment or grants. The unlocked Desert fan opens Normal; entering/pausing/leaving Desert also verifies native animated porthole arrival and successive Earth/Moon/rocket departure frames. World wheel zoom/pan work. Command-Q exits0; all normal/campaign/package protected hashes, signature, isolated paths and sole-process checks pass. Exact evidence is builds/tutorial-loading-native-input-r45/input-observations.json. Native input exposed health percentage truncation, an overlapping abandon prompt and unbounded world camera margins; those fixes remain pending. Trackpad, speaker listening, Intel/notarization and original framebuffer parity remain unverified.
