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
