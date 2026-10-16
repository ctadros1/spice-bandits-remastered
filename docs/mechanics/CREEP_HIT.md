# Creep hit flash: recovered fields and pending integration

R120 is a source/prototype checkpoint. The current all-ten verified game remains R119; hit fields and ordered-canvas helpers are not connected to Main or Simulation. No new gameplay/presentation completion claim follows from this work.

The preserved decrypted1.14 executable has SHA-256 `e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`. Full DoDamage0x7a62c, Update0x7e8d0 and Render0x7f5c8 execute in bounded ARM probes with supplied records. GL/final-frame calls, unrelated update subsystems, SetDie and player lookup are explicit stubs; reward credit is disabled. This does not execute complete combat callers, death ownership, services, GPU or the original game.

## Recovered behavior

DoDamage rejects states2/3. Otherwise it subtracts damage in float32, clears the separate recent-damage timer and sets its flag. On surviving damage, it activates hit+0x334/running+0x335 only if running is false. It does not restart+0x330 when another hit arrives. The supplied damage-kind argument is stored at+0x34c, except that consecutive kind3 calls skip reactivation when the preceding kind is also3. That suppression survives flash expiry. A different kind re-enables the next kind3 hit. Lethal damage clears both flash flags after the supplied SetDie/player callbacks; the flash elapsed field is not reset by that branch. The constructor clears+0x34c at0x788f6, +0x334/+0x335 and elapsed+0x330 near0x7960e..0x7961a.

Full Update adds supplied delta to elapsed only while running, with separate float32 addition. It clears elapsed and both flags **strictly after60ms**; the flag remains active at exactly60ms. The constant is read from original0x7eacc. Pause/room delta production and the placement of all actual damage callers still need a Main/Simulation bridge comparison.

Full Render draws normal primary/visible secondary first. When hit+0x334 is set outside states2/3, it submits ONE/ONE and rawRGBA0.2 for the current primary frame, even if normal primary opacity is0. It also submits the current secondary when its source pointer exists and corner alpha is nonzero. That constant ignores light, growth opacity and corner alpha. Freeze/pending-slow Screen follows the additive pass, then other owner/health processing. It must remain inside this owner's place in the draw list, so later towers/scenery can occlude it.

Incoming call references and read-only decompiles identify mine damage0, direct missile damage2, missile splash0, poison damage3, active defense0, ordinary direct0, a laser/plasma branch1 and continuous tower damage0. These are static callsite arguments; full caller execution and precise type/branch/owner mapping remain open. Ghidra omits some fifth arguments in inferred pseudocode; the retained stack assignments/instructions must guide integration.

## Evidence and implementation

`tools/native_creep_hit_reference.py` writes `tests/fixtures/native-creep-hit-reference.json`:800 complete DoDamage supplied cases,96 complete Update supplied cases,12 interleaved damage/update rows and576 complete Render/noninterpolating Animator.Render cases. Original bytes remain unchanged. Read-only decompiles, incoming references and initial tool setup failure are retained under `builds/creep-hit-r120-*`.

`game/scripts/creep_hit_view.gd` is a field-only helper and direct-frame draw plan. `tools/creep_hit_ui_verify.gd` passes5,360 comparisons, including exact elapsed bits, repeated-kind3 suppression, lethal/state guards, rawRGBA bits, primary/secondary routing and normal→hit→status order. HP/rewards/death and runtime integration remain outside this helper.

`game/scripts/ordered_canvas_view.gd` pools contiguous normal/additive draw spans. Each callback runs inside its own CanvasItem draw, preserving submission order without a root shader or a global hit overlay. The additive span samples preserved premultiplied RGB and emits alpha1 under Godot's additive material so source alpha is not multiplied into RGB twice. The game canvas is opaque; transparent-destination alpha equivalence is not claimed. [Godot's renderer blend implementation](https://github.com/godotengine/godot/blob/master/drivers/gles3/rasterizer_canvas_gles3.cpp) informed this prototype; actual pinned4.7.2 native execution is the implementation check.

`tools/ordered_canvas_ui_verify.gd` passes8 native checks on Apple Silicon. Its supplied RGBA8 source adds exactly12/6/3 RGB bytes to the test background, later opaque geometry covers the flash exactly, unaffected geometry stays unchanged, and returning to one normal span clears stale layers. `builds/ordered-canvas-r120{,-cleared}.png` and its JSON/log retain this bounded evidence. This synthetic8×8 texture test is not real creep/Main integration, original GPU sampling, full layer/culling/lifetime proof or complete fidelity acceptance.

## Next work

Connect an ordered per-owner draw bridge while retaining the reference renderer for frozen comparisons. Verify no-hit rendered pixels, held animation epochs, placement/air/status/health/tower ordering and unchanged live performance before enabling actual hit state in Simulation. Then map damage callers, compare real preserved creep frames at hit/60ms/expiry/pause/poison and retain a fresh all-ten native package review. All required PLAN.md presentation items remain open.
