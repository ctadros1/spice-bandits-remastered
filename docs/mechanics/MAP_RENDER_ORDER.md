# Map render routing

The preserved decrypted1.14 executable is the behavioral reference, SHA-256`e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`. These are original compiled function executions with supplied records and explicit stubs, not execution of an original iOS game or proof of original pixels.

## Original routing recovered in r96

`tools/native_air_pass_reference.py` executes full CCreepManager::RenderAllAirCreeps0xfbe8c. Eight vectors produce37 virtual callbacks. Resource type2 alone receives air-before and body calls; the manager then calls after for every vector entry, including ground entries. Bodies retain manager insertion order without a Y/depth/ID sort. The constructor registers only resource type1 in CMap; native resource identity is independent of temporary levitation.

`tools/native_render_pass_reference.py` executes full CRoom::Render0xd4f04, CMap::Render0x104088, RenderObjects0x1042c0, RenderAfter0x103ce8 and the air manager. Nine cases cover empty/ground/air/mixed, room-not-ready, disabled/no-map, previews and optional effects. Original sort/vector-copy loops execute. Drawing, GL/projection, GUI, preview updates and virtual callbacks are recording stubs; ready/timer fields are supplied. Timers, services, concurrency, constructors and complete lifetimes are outside this scope.

The recovered room order is:

1. Update tower/mine/portal placement previews.
2. Map segments, optional water/animated objects/tutorial marks.
3. Decals/footsteps, all registered ground-before calls, then all sorted ground-body calls.
4. Selected/inactive range ovals, preview hexes, grid, tower preview body.
5. Air-before callbacks, then each manager entry's air body when type2 and after callback unconditionally.
6. Global animation update/render, global particles and environment.
7. Map RenderAfter invokes registered ground-after callbacks again.
8. Tower panel after, tower info, floating indicators, bubbles, backgrounds, GUI and shop fade.

Thus ground-creep after callbacks occur twice in the observed original route. Actual callback pixels remain stubbed; do not deduplicate based on an assumed single-pass engine design. CCreep::Render0x7f5c8 contains its own shadow/body/HP bar, while CBase::RenderAfter0x76c48 owns base HP bars.

Fixtures: tests/fixtures/native-air-pass-reference.json and native-render-pass-reference.json. Probe logs: builds/native-air-pass-probe-r96.log and native-render-pass-probe-r96.log. The initial missing DisableAlphaTest wrapper failure is retained separately; adding its explicit GL stub allows full routing to return. Original bytes stay unchanged.

## Minimal r97 integration

Main now excludes native aircraft from battle_objects(), calls the unchanged extracted draw_creep_body() for ground bodies, then draws battle_air_objects() in manager vector order. The `native_air` spawn field controls resource identity, with a declared-class fallback for older synthetic fixtures. Changing `air` for targeting/levitation cannot change the body pass.110 source comparisons cover the eight original air cases and every populated resource. An initial test reused synthetic enemies across setup; a fresh Simulation removes that test residue, and the original failure is retained.

Three packaged poses overlap original plane/bomber art with tower/base art, reverse aircraft vector input and levitate a ground creep. They were inspected; the reversed overlap changes battle pixels, and manifests record IDs/class/positions for both body lists. These synthetic scenes test drawing order, not legal placement, original pixels or the full original owner route.

At the r97 checkpoint, the change leaves selected range, tower/magic previews, full owner effects, missile/bubble/beam/global interleaving and mutable ground-vector lifetime open. Ground/air shadows and native creep depth still need their full original caller/offset behavior. No assets are stretched or recolored by the body-pass change.

## Verification

PCK `30107427246b9a19624ea4cba6bfa03e527d94f6efc5b86781c7e8b1692b7044`, executable `41ec54d22ac8753562613707a3f30169111c49e7df793cc156ed308ac067ca38`, native helper `248ede79f36c81b13a8cfe034dcea1d3cac3bba2f7de6f3c6ec4c19ea9cbd726`.

R97 restores a separate native-air body pass after sorted ground bodies, retaining the creep manager vector order. Resource class stays independent of temporary levitation/targeting. Eight original air-routing cases/37 callbacks and nine full original room/map routing cases establish the order with supplied records and explicit drawing/framework stubs;110 source checks cover all29 populated enemies. Three packaged overlap/reversed/lifted poses pass and were inspected. Full mutable map registration, creep depth, preview/selection and owner/effect interleaving remain open.

Nine r97 native suites pass: presentation313/94 PNGs, menus184/55, tutorial88/20, audio50/23 WAVs, projectiles4, turns5, towers1, Desert1 and campaign148. Live performance remains failed:1x28.356ms median/32.886ms p95,2x35.182/84.967 and4x42.189/61.444; only1x meets the unchanged33.34ms median gate. All live/input-isolation guards pass with zero stalled frames, and all three frozen mesh/direct comparisons retain exact RGBA. CPU totals now exclude supplemental frozen redraws. Normal/retained-campaign saves, package resources, strict signature, isolated sole process and cleanup pass.332 counted PNGs include failed performance captures; this is not an all-ten pass or original-device equivalence. Evidence: builds/air-pass-r97-native-suites.json, builds/air-pass-remaining-r97-native-suites.json and builds/air-pass-r97-evidence/.



## R98 selected range integration

R98 restores the selected tower range after all ground bodies and before aircraft, using the original shared translucent fill, three outlines and panel alpha at the logical cell center.40 full original selection-router/panel/inactive-manager cases record48 calls/112 oval submissions with explicit GL/oval recording stubs;393 source comparisons pass. Two packaged settled/fading poses pass and were inspected. Supply-bonus integration, full panel clocks, preview/owner order and original raster remain open.

Nine r98 native suites pass: presentation318/96 PNGs, menus184/55, tutorial88/20, audio50/23 WAVs, projectiles4, turns5, towers1, Desert1 and campaign148. Live4x performance still fails at34.402ms median/37.443ms p95 against33.34;1x26.191/29.194 and2x27.514/32.254 pass. All live/input-isolation guards pass with zero stalled frames; three frozen mesh/direct comparisons retain exact RGBA. Normal/retained-campaign saves, package resources, strict signature, isolation and cleanup pass.334 counted PNGs include failed performance captures. These changing live workloads/shared-host measurements do not establish an inter-build speedup or original-device equivalence. Evidence: builds/selection-r98-native-suites.json, builds/selection-remaining-r98-native-suites.json and builds/selection-r98-evidence/.

tools/native_selection_reference.py now executes the complete original map selector, selected-panel guard, inactive manager and oval arithmetic. Supplied panel/tower/resource records replace construction. Recorded GL/oval submissions establish guard behavior, caller order, logical center and color/alpha/radii; they do not execute GPU tessellation. Main.selected_range_pose() replaces the older plain green ellipse and uses the already traced BuildHexView.oval() helper. The current selected view still supplies zero additive support range; exact ProcessSupply/caller lifetime and full panel clocks remain separately open.

## R99 ground-creep depth

R99 restores ground-creep depth from the initial RunDownRight untrimmed height, optional integer depth_pos and original float32 drawn-position truncation/map key.35 original constructor suffix branches,1,134 full supplied-position updates and126 attack-copy cases support3,880 source checks across all29 populated resources. A native helper computes the moving key while Main caches only immutable heights. Two Marine/tank overlap poses were inspected and retain exact battle pixels when enemy input reverses. Artwork positions/scales are unchanged; the older tower-depth fixture intentionally moves its Marine center from+30 to+11px to keep its original between-towers test with the now-retained38px height. This is a fixture change, not an unchanged-pixel comparison.

Nine r99 native suites pass: presentation323/98 PNGs, menus184/55, tutorial88/20, audio50/23 WAVs, projectiles4, turns5, towers1, Desert1 and campaign148. Live4x performance still fails at42.759ms median/57.748ms p95 against33.34;1x26.969/32.292 and2x30.089/40.297 pass. All live/input-isolation guards pass with zero stalled frames; three frozen mesh/direct comparisons retain exact RGBA. Normal/retained-campaign saves, package resources, strict signature, isolation and cleanup pass.336 counted PNGs include failed performance captures. Changing live workloads/shared-host measurements do not establish an inter-build speedup. Evidence: builds/creep-depth-r99-native-suites.json, builds/creep-depth-remaining-r99-native-suites.json and builds/creep-depth-r99-evidence/.

The native ground key now includes the original constructor height and drawn Y; mutable registration/list lifetime and whole owner passes remain separate work. [Creep evidence](CREEP_PRESENTATION.md) records those bounds.

## R102 aircraft missiles

The full original `CCreep::RenderBefore`0x7f518 and `RenderAfter`0x7f55c execute against192 supplied resource/state/missile/shooter/sprite/laser records, recording464 callbacks. Resource type2 missiles with+0xa0 bit0 clear are before-air; type1 missiles are after-owner. The+0xa0 flag excludes a missile from these before/after callbacks; it is not an expired flag. A later full-Render review found the set-bit missiles drawn in the owner body callback, so the earlier inference of global suppression was incorrect. Full body routing still needs a bounded probe. Drawing callees are stubs, so neither missile rendering nor lifetime runs in this probe.421 source checks cover the recorded visible sets, manager/per-owner ordering and all29 populated resource classes.

`CreepOwnerView.missile_passes()` now places visible aircraft missiles after ground/selection and before every aircraft body, grouped by manager owner order while preserving per-owner missile order. The unchanged missile drawing helper retains assets, positions, angle and scale. Ground missiles remain in their existing later pass. Current orphan missiles remain visible until original destruction/lifetime is traced. The original body/before-after routing flag, two ground-owner after invocations, owner effects and whole routing remain open.

Four packaged overlap poses confirm310 opaque aircraft pixels cover a missile while the outside missile remains visible. The first pose used the logical ground point and overlapped only a shadow; its failed assertion and captures are retained. The corrected fixture adds the authored aircraft offset without weakening the occlusion assertion. A subsequent runner failure retained the stale98 expected-capture count; correcting the exact count to102 retained all freshness/identity/protection checks.

R102 has nine nonperformance suites passing; presentation329/102, menus184/55, tutorial88/20, audio50/23 WAV, projectiles4, turns5, towers1, Desert1, campaign148. Live4×33.975ms median/45.513ms p95 fails33.34ms;1×24.060/26.307,2×24.996/29.391, world6.411/13.959. All live guards pass, zero stalled frames, three mesh/direct and three old/prepared-creep frozen RGBA pairs match. Normal and retained campaign saves, resources, strict signature, process isolation and cleanup pass.340 counted PNGs include failed performance. Evidence is retained under `builds/creep-owner-r102-evidence/`; the r102 app has a separate APFS clone. These shared-host runs do not establish an inter-build speed difference or original pixels.

## R109 owner-body missile routing in progress

Full CCreepMissile constructor0x80bc0 initializes+a0=1, copies the supplied origin into start/current/previous and advances start/current10px toward the base. It uses reciprocal-normalize/multiply float32 operations. Original Update0x8120c clears the flag only after distance from that advanced start is strictly greater than30px (also on impact). Full CCreep.Render0x7f5c8 draws set-flag missiles after that owner's body and before its health bar; Before/After draw clear flags. It does not hide missiles until30px.

A new full-constructor/nonimpact-Update probe covers40 sequences/1,000 frames plus nine stationary distance-boundary cases, with explicit null texture/particle lookup and forced-false collision. Real float32 normalize/distance/steering execute. The new native movement helper matches8,000 recorded position/previous/velocity/integral values exactly. The older shared script differs in minor rounding and the original zero-dt=>one-second branch; its initial comparison is retained. Tower projectiles keep their separate existing implementation. Complete collision/explosion/owner death/GPU are outside this probe.

The live-owner reconstruction now routes set flags after the correct body, and clear flags through the prior class-specific passes. Original caller supplies animator position plus animator offset; the bridge uses the current reconstructed drawn aim point. Full animator update/jitter chronology remains open. Original creep manager removes state2 on its next update; DoOnDying waits on its own particles/sprites before state2, then destructor deletes owned missiles. The reconstruction still removes dead actors immediately and retains orphan missiles; that existing lifetime is explicitly not changed in this bounded routing port. The two original ground After calls/global effects remain open. All ten native r109 suites pass, with386 presentation checks/125 PNGs,73 audio checks/23 WAVs and the unchanged live median gate. Two new flag/cleared overlap poses were inspected;315 pixels change at the owner overlap, then the cleared-flag battle region exactly restores the earlier before-air capture. Protected profiles/package/signature/isolation/cleanup pass.
