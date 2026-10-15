# Enemy corner presentation

Reference: decrypted1.14 ARMv7 executable SHA256`e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`.

`UpdateMovementAndShooting`,0x7bfa8, prepares a future corner from the current logical point to a point beyond the current destination. At three quarters of a segment, the future endpoint is the destination plus the remaining fraction of the next segment. `UpdatePosition`,0x7d108, projects the drawn position onto this line during the final quarter and the following first quarter. The straight logical position at0x188/0x18c remains distinct from animator position0x4c/0x50 and drawn aim point0x190/0x194. Ordinary tower missiles follow logical position plus resource offset; chemical bubbles snapshot the drawn aim point.

Aircraft enable physical turns by default. Ground resources can enable them through`dir_interpolation`, as creep5/6 do. `InterpolatePhysicalRotation`,0x7d470, blends the ordinary and semicorner animations over two125ms-fraction regions, using15/30-degree rotations and complementary alpha. These are fractions of a movement segment, not fixed wall-clock durations. `UpdateRoundedCornerSemiDirection`,0x7e72c, chooses the preserved TurnDownLeft/Right, TurnUpLeft/Right and TurnLeft/Right states. Animator Render0x10f54c confirms alpha at animator+0x34 and premultiplied RGB at+0x38; RenderFrame0x10f1c4 passes angle at+0x30. Treating the alpha fields as size fields would be incorrect.

The port in`game/scripts/creep_view.gd` preserves the recovered direction tables, including the unusual first-quarter upper-left case. It keeps body positions separate from combat positions, resets animation age on state changes, draws the second animation layer, and rotates both layers. Logical movement overshoot, mid-cell rerouting and the complete native animator/shadow state remain separate comparisons.

`tools/native_creep_reference.py` executes selected original ARM instructions in Unicorn2.1.4 without modifying the original file. It records576 turn field cases,64 corner preparations and5 position projections in`tests/fixtures/native-creep-reference.json`. Godot checks all four turn fields against these independently executed values, with a0.00001 tolerance. Animation-name and framework calls are stubbed; the final heading dependent on those stubs is excluded. This is isolated math evidence, not an original iOS installation or whole-game runtime parity.

The original corner preparation can produce a zero-length line for an exact reverse. The reconstruction retains the finite logical position in that case instead of dividing by zero. This is a documented stability guard. It does not change health, damage, money or the route.

The packaged turn gallery uses five synthetic aircraft/tank poses along a long vertical-to-diagonal path. It checks blended layers, drawn positions and animation names. Its captures must pass the fresh-package audit before being reported as rendered evidence.

## Logical movement boundaries

UpdateMovementAndShooting0x7bfa8 increments float32 progress by `(dt/1000)*(speed/1000)*(hex_height/segment_length)`. If progress exceeds1, it clamps to1 and stores the entire increment, capped at0.3, rather than just its excess. The following frame changes the cell/endpoint and interpolates the new segment at that carried progress, without another increment. Exactly1 carries no new increment. This differs from the former continuous-distance loop.225 isolated executions through0x7ca50 cover this math. GetFirstMovementPoint supplies the next endpoint, GetCell returns null (height interpolation excluded), and UpdatePosition is stubbed here because it has separate projection checks. The original executable hash remains unchanged.

Kamikaze state changes after progress exceeds0.5 on the base link (0x7ca50 onward); it does not wait for the center. The updated tutorial wins at75,690ms,16 kills,98% base health and$168. Mid-cell rerouting and attacker displacement transitions still require complete state comparisons.

UpdateShortestPath0x7ace0 now retains a moving segment and searches from its next endpoint. If that endpoint becomes blocked before progress0.7 (0.5 for a horizontal shortcut), it swaps current/next and uses `1−progress` to reverse without teleporting. Past that threshold, or when the current cell is already unwalkable, it plans from the next cell with the start-walkable exception. Focused reconstruction tests cover continuing and reversal; escort-source cache reuse and complete invalidation-frame parity remain open.

CCreepShadow::Render0xfc7b8 uses a black tint with alpha `1−animator.scale_x*0.5`, an animator-sized quad, authored shadow_scale_factor, linear400ms growth and a0.8 height factor for static shadows. Static shadows rotate with native direction angle minus90 degrees plus physical rotation; animated creep10 shadows retain the current animation/frame without that rotation. These rules replace the former unrotated source-texture-size shadows. Packaged five-pose rendering passes; original-device shadow pixels and terrain-layer ordering remain unverified.

## R99 ground depth

The preserved decrypted1.14 executable, SHA-256`e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`, is the behavioral reference. These are bounded original compiled functions with supplied records and explicit stubs, not authentic source or a whole original-game execution.

### Constructor and position fields

CCreep constructor0x78374 plays RunDownRight on its main/blending animators before retaining the initial untrimmed frame height at CMapObject+0x14. Suffix0x7878c..0x78804 reads the current animation pointer at+0x74 and its height at+0x48; an integer depth_pos overrides that value. A missing resource branches to0x7887c. Texture crop size, per-instance growth, current facing and drawn scale do not replace the construction height in these instructions.

Full UpdatePosition0x7d108 writes the main/blending drawn positions at+0x4c/+0x50 and+0xc0/+0xc4, including supplied corner/jitter coordinates. It then writes int(float32(drawnY+float32(height*−0.5))) at+0xc, truncating toward zero. CMap comparator0x103650 strictly compares float32(float32(int_top)+height). Attack-copy suffix0x7cc52..0x7cca2 assigns logical positions to the animators before the same depth calculation. Authored aim offsets affect+0x190/+0x194 independently of depth.

The original constructor's native resource class governs map/air registration. Temporary levitation does not move a ground body into the separate aircraft pass. Complete ProcessFly/jitter/birth/update chronology remains open; this change uses the reconstruction's already-exposed drawn position and retains its existing lift/animation/scale behavior.

### Original/source checks

tools/native_creep_depth_reference.py executes35 constructor suffix branches,1,134 full supplied-position updates and126 attack-copy cases. Inputs include absent animation/resource, integer overrides, negative/fractional/large positions, normal/corner routes, supplied jitter and independent aim offsets. Narrow animator name/direction callbacks are recording stubs inherited from the earlier position probe. Constructor lifetime, global RNG, real animation loading, GPU and services are not executed.

The initial prototype omitted noncorner start/target endpoints, so its supplied logical point alone correctly produced the initialized zero endpoint position. That incomplete prototype/log remain retained; the committed fixture supplies explicit endpoints. No game implementation was changed to accommodate those incomplete records.

tools/creep_depth_ui_verify.gd passes3,880 comparisons: source declaration/position/top/key fields, all29 populated resource declarations, actual Main ordering, fractional/moving depth, resource replacement and levitation independence. Every populated resource contains RunDownRight. Main caches only its immutable source height by filename, clears the cache on a new mission and computes the key from the current drawn Y. SpiceNative.creep_depth avoids allocating float32 script arrays per moving enemy; it preserves separate float32 operations and signed truncation within the current maps' valid integer domain. Fused/fast floating arithmetic remains disabled.

The older tower-depth pose intentionally moves its Marine center from30px to11px below the tower center: the retained38px height then contributes19px, preserving that pose's requested30px intermediate depth. Its changed pixels are not an unchanged-renderer regression comparison. New Marine/tank poses use the same Y and different38/100px heights around a Minigun, then reverse enemy input. Both were inspected and the full battle rectangle below the HUD remains exactly equal in decoded RGB. Manifests record positions, depth and body submission IDs.

### Current package and remaining work

PCK `7aebaa83a0e746babe1be8ce6ea0cbe4d39871f9ab577f26f207c2c0f7e329d9`, executable `7a74ca949304474a72ca4117051d2f753d08736f860bd12d3cc71a25d1f24119`, native helper `ba89a47c6edabd27a7c2b5449979fc7dabd2c5079e47c0f2f1c9d2b4f0c8eece`.

R99 restores ground-creep depth from the initial RunDownRight untrimmed height, optional integer depth_pos and original float32 drawn-position truncation/map key.35 original constructor suffix branches,1,134 full supplied-position updates and126 attack-copy cases support3,880 source checks across all29 populated resources. A native helper computes the moving key while Main caches only immutable heights. Two Marine/tank overlap poses were inspected and retain exact battle pixels when enemy input reverses. Artwork positions/scales are unchanged; the older tower-depth fixture intentionally moves its Marine center from+30 to+11px to keep its original between-towers test with the now-retained38px height. This is a fixture change, not an unchanged-pixel comparison.

Nine r99 native suites pass: presentation323/98 PNGs, menus184/55, tutorial88/20, audio50/23 WAVs, projectiles4, turns5, towers1, Desert1 and campaign148. Live4x performance still fails at42.759ms median/57.748ms p95 against33.34;1x26.969/32.292 and2x30.089/40.297 pass. All live/input-isolation guards pass with zero stalled frames; three frozen mesh/direct comparisons retain exact RGBA. Normal/retained-campaign saves, package resources, strict signature, isolation and cleanup pass.336 counted PNGs include failed performance captures. Changing live workloads/shared-host measurements do not establish an inter-build speedup. Evidence: builds/creep-depth-r99-native-suites.json, builds/creep-depth-remaining-r99-native-suites.json and builds/creep-depth-r99-evidence/.

Mutable ground registration/ties, complete initial birth/render chronology, global jitter/RNG, full animator/shadow/owner behavior, old GPU sampling and original-device pixels remain open. This does not establish complete gameplay, animation, sound or offline fidelity.

## R100 prepared drawing data

R100 reuses prepared creep layers and returns the exact completed growth plateau after400ms. It removes repeated pure fallback/animation and polynomial calculations without changing frame age, position, scale, alpha or RNG.435 source comparisons cover all29 populated resources; a fixed A/B/B/A microbenchmark measures selector3.171–3.237µs versus0.328–0.337 and completed growth1.241–1.312 versus0.455 per call. Those are bounded CPU measurements, not live inter-build speedup claims.

All ten r100 native suites pass on one frozen package: presentation323/98 PNGs, menus184/55, tutorial88/20, audio50/23 WAVs, projectiles4, turns5, towers1, Desert1 and campaign148. Live1x24.133ms median/26.334ms p95,2x25.230/29.419 and4x31.759/34.917 meet the unchanged33.34ms median gate; world6.257/14.290 passes. All live/input-isolation guards pass with zero stalled frames. Three full-frame mesh/direct particle pairs and three eager/prepared creep-layer/completed-growth pairs match exact RGBA; the latter record200/161/99 actual draws per path.336 counted PNGs and23 WAVs retain15 supplemental frozen-comparison PNGs separately. Normal/retained-campaign saves, package resources, strict signature, isolation and process cleanup pass. These checks do not establish original-device pixels or complete offline fidelity. Evidence: builds/creep-layers-r100-native-suites.json and builds/creep-layers-benchmark-r100.json.

The old draw helper computed creep_animation, a discarded frame index and a fallback array even when CreepView had already prepared both layers. The new path returns those existing layers directly. The no-layer fallback retains its previous selection. Completed grow_ms>=400 returns exactly scale1/alpha1; the original polynomial remains the reference and handles unfinished growth. Internal QA flags enable both prior calculations for frozen native readback. These changes do not alter simulation clocks, frame ages, movement, damage or random state.

## R107 normal body brightness

Full CCreep.Render0x7f5c8 sets primary RGB to+0x34 for resource type1 and white for type2. UpdateMovementAndShooting0x7bfa8 samples current/next cell+0x1c and interpolates by movement progress even at speed0. Full CHexCell constructor initializes1;2,350 map cells carry authored values and25,699 omit them. SpiceNative.creep_light retains separate float32 subtraction/product/sum/clamp steps. Temporary levitation does not change native resource class.28,633 source checks and four packaged poses pass; all ten frozen native r107 suites pass. Existing freeze blue tint/status overlays, full animator/global owner/lifetime/GPU remain open.

## R108 textured health-bar work

Full original Render, Thumb instructions0x7f846..0x7f938, draws health only below maximum outside states2/3. Main animator+0x4c/+0x50 plus(-16,+16) anchors both textures. RedLifeBar/GreenLifeBar resolve to preserved32×16 images. Original GL blend isONE/ONE_MINUS_SRC_ALPHA and all four glColor channels equal+0x2e0; the reconstruction uses equivalent opacity on decoded straight-alpha images. Width and right UV use max(0,float32(HP/intMaxHP)), independently float32. The green texture is cropped, with its original height and no horizontal rescale.

tools/native_creep_health_reference.py executes the full original Render576 supplied health/state/opacity/point/UV cases,180 with bars, preserving GL/quad/animator recording stubs. tools/creep_health_ui_verify.gd passes3,104 checks. Original GPU/loader and complete portal/state lifetime do not execute. Main bridges existing source-derived linear growth alpha and current drawn resource offset/lift; this does not close portal behavior. All ten native r108 suites pass:381 presentation checks/123 PNGs, six new health poses inspected,73 audio checks/23 WAVs and unchanged live performance gate. Normal/retained campaign files and original4,035 hashes are unchanged.
