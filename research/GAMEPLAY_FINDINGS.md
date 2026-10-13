# Gameplay Reconstruction Findings

Research date: October 13, 2026. Baseline: decrypted Spice Bandits 1.14. This is an evidence guide for the clone, not a new game design.

Implementation is now in progress. The original research observations below remain reference evidence; the current traced rules, executed checks and remaining differences are maintained in [the mechanics baseline](../docs/mechanics/BASELINE.md), [verification record](../docs/VALIDATION.md) and [plan](../PLAN.md).

## Original presentation observed

The sampled [iPad gameplay video](https://www.youtube.com/watch?v=dAXRTlTxedE) shows an animated space introduction, a hex training map with contextual instruction bubbles, a tower dock and ability controls, desert combat, and a world map. The 3:45 tutorial frame explicitly introduces Active Defense; the 7:30 frame shows the desert ship/container environment; 11:15 shows world navigation. These frames were visually inspected in the browser. Full action timing and audio remain to be annotated.

The [phone combat screenshot](https://i.appsafari.com/wp-content/uploads/2012/02/spicebandits.jpg) places speed/resources/XP above the battlefield and tower/ability controls below it. The [phone map screenshot](https://i.appsafari.com/wp-content/uploads/2012/02/spicebandits_2.jpg) shows six named modes: Normal, Sudden Death, Air Attack, Camps, Cooperative, and Competition. It also shows locks and profile information. These observations establish presentation and labels, not numerical mode-ID mappings.

The [tech-shop image](https://app-s.ru/_nw/13/01265209.jpg) shows weapon branches, labels, spice prices, and a profile bar. The [upgrades image](https://app-s.ru/_nw/13/97450659.jpg) shows a tiled upgrade grid, levels, and a Wizard description. Reuse these compositions and original art rather than inventing a new visual language.

## Recovered rules from the executable

The previous inspection disassembled 31 representative functions. They are preserved under `original/source-code/recovered/disassembly/`. Full executable-section disassembly is also available. The following are static interpretations; runtime comparisons remain necessary.

| Rule | Evidence | Implementation consequence |
| --- | --- | --- |
| F/S/W targeting | `CCreepManager::GetNearestCreep` matches `fastest`, `strongest`, `weakest` and compares speed/current health | Preserve selection, tie behavior, filtering, and intermediate rounding. |
| Range geometry | Target eligibility invokes `IsPointInEllipse` | Match the original coordinate geometry and ellipse axes. |
| Selling | `TDPlayer getSellPriceForTowerType:level:player:` recursively traverses prior levels and parent branches | Calculate refunds from upgrade history with original rounding. |
| Freeze/Wizard stacking | `CPlayer::GetFreezeDuration` multiplies two percentage factors | With the bundled 10-second base and one 5% level of each, the arithmetic yields 11.025 seconds. Confirm runtime application. |
| Slowdown combination | `CCreep::DoSlowDown` multiplies an existing positive factor by the new one | Specify reset timing and stacking eligibility before implementation. |
| Dynamic path checks | `CRoom::CheckPathsUpdate` uses a 250 ms threshold, updates source paths, and can remove a recently built blocking tower | Preserve deferred validation and rollback behavior. |
| Simulation correction | `CRoom::SimulateGame` advances using 30 ms steps; `UpdateGame` has a separate normal path | Recover both timing paths and subsystem ordering; do not generalize the replay constant to all play. |
| Disco expiry | `CCreep::ProcessLsd` restores state and calls path update | Reproduce the state transition and rerouting. |
| Offline unlocks | `TDServer modLevelWon:` updates local unlock data | Distinguish local recovery from hosted authoritative services. |

The full binary retains roughly 1,700 project-specific function records after obvious library-template filtering across 102 engine/gameplay compilation units. This does not mean every function has been understood. Original engine source and local-variable debug symbols are absent.

## Research conflicts that affect implementation

1. **Targeting:** [Arqade answers](https://gaming.stackexchange.com/questions/52657/what-do-the-tower-settings-mean) disagree about F and S. The code takes precedence for the 1.14 baseline.
2. **Co-op unlocks:** [Player accounts](https://gaming.stackexchange.com/questions/51131/level-required-for-co-op-mode-in-spice-bandits) disagree about the prerequisite. Trace `needsunlock` / `grantsunlock` and client checks.
3. **XP versus stars:** [The XP discussion](https://gaming.stackexchange.com/questions/53218/how-can-i-maximize-xp-gain-in-spice-bandits) reports early-wave and proximity-dependent strategies. These identify tests, not a recovered formula. Include the single-tower Desert Freighter achievement as a candidate scenario.
4. **Enemy route costs:** [The Japanese review](https://iphoneac-blog.com/archives/6712851.html), available through search extraction, reports that towers' threat can affect routing. Trace penalties and smartness in the binary; ordinary shortest-distance navigation is insufficient as an assumption.
5. **Content counts:** [The preserved app description](https://toucharcade.com/games/spice-bandits) advertises 55 levels and eight players, while [an early review](https://app-s.ru/news/obzor_spice_invaders_takoj_td_kotoryj_ja_vsegda_khotel/2012-02-12-1382) discusses different map/player counts. Separate maps, locations, bonus content, modes, and versions.
6. **Wave types, resolved:** Embedded `slow` fails the native exact matcher and leaves ordinary enum4. The recognized spelling is exactly `slow&strong`. Traced spawning does not apply guessed HP/speed multipliers. See the current mechanics baseline.
7. **Progression and services:** [TouchArcade's early review](https://toucharcade.com/2012/02/06/spice-invaders-review/) documents a continent gate, while the app listing describes offline reward restrictions. Preserve recovered balance but explicitly document local-service adaptations.

## Archived content and remaining gaps

All 63 referenced level ZIPs and 178 listed costume/preview images have been downloaded and checked. The combined archive has 66 distinct numbered map IDs. All 54 map IDs used by the 148 nonempty offline wave schedules are present; the 149th offline record has an empty special configuration. This is coverage, not proof of playability.

The content audit found strict XML errors in downloaded `map_100.xml` and `map_1004.xml`. The original IPA has two additional prefix defects. The current importer repairs only derived content and records duplicate precedence. Independent conversion checks cover1,458 runtime media files; full presentation comparisons remain open.

Additional file searches are documented in the archive, mirror, and official-service discovery reports. Any additional version must remain separate from the 1.14 reference and receive its own integrity/architecture/encryption/content comparison.

The recovered 1.27 package has now passed that static comparison: ARMv7 and ARM64 code are encrypted; all 200 XML files and embedded offline data exactly match 1.14. Newer menu/background and packaging assets are useful presentation references, but no new campaign definitions were found. See [the verified comparison](FILE_DISCOVERY_SUMMARY.md).

## Fidelity checks to establish before expansion

- Record original input sequences, frame aspect ratio, upgrade state, and mission mode.
- Compare routes and target choices after tower placement/selling, damage and money events, waves, and ability expiry.
- Compare world map, HUD, tutorial, shop, upgrades, effects, results, and audio against equivalent states.
- Maintain discrepancies with confidence and resolution evidence. Treat server replacements and desktop input as explicit adaptations.
- Preserve an original campaign and original rules profile before adding new content.

The [main plan](../PLAN.md) orders this work. A complete source catalog and direct video links accompany it. Reconstruction is underway; no expansion levels or gameplay have been added.
