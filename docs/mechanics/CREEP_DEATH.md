# Original creep death lifecycle: field port and integration gaps

R124 adds a disconnected source helper and reproducible original-code fixtures. The current verified macOS game and private recovery checkpoint remain R123; no new death behavior is enabled in Main or Simulation. Complete offline fidelity remains incomplete.

The preserved decrypted1.14 executable SHA256 is `e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`. Original compiled functions execute in bounded ARM probes with supplied records and explicit stubs. These are not authentic source, original game execution or original-device pixels.

## Recovered rules

Full SetDie0x7a150 stores previous state+173, sets state3 and cleans portal/tower references. Existing particle emit counts become0. Every resource particle alias containing `explosion` creates a system, sets its release interval to5 seconds, places it at the drawn aim point and emits its supplied initial count. Factory/resource/map/Emit/sound/decal calls are recording stubs in the resource fixture; actual particle construction/global RNG is outside it.

Damage kind2 omits ExplosionSplash. Other supplied kinds create the preserved splash at logical position+animator offset with300ms lifetime. Marine/drone/tank groups use initial scales.5/1/1.2 and integer scale divisors3/5 from their preserved definitions. Birth size is0 until Sprite.Update executes, including an explicit zero-delta update. Native Sprite constructor/Update/interpolation/Render execute in the supplied splash sequences. Fade and growth use separate float32 operations. Original weighted interpolation rounds two products and their sum; equal endpoints can still shift by one float bit. The port retains that behavior.

When no prior crater was created, SetDie submits an available `crater_list` texture at the logical point. The recorded scale is1 or authored1.6, with4000ms life/4000ms fade/no fade-in. Full spatial admission, decal rendering and integration remain open; a callback submission is not a successfully rendered crater.

DoOnDying0x7beb8 processes only state3. It zeros the attached emitter's rate and waits for both attached and mapped active particle counts to become nonpositive. Sprites whose life is nonpositive at entry are deleted/compacted. A sprite positive at entry blocks state2 for that update even if it reaches0 during Sprite.Update. A following call can remove it and set state2. The manager0xfbf10 deletes an actor already state2 before updating the remaining vector in order; a newly state2 actor survives until the following manager call.

Full IsAnyCreepTargetedForPlayer0xfc0c8 counts matching state2/3 enemies until their removal; it does not filter HP/state. Full CheckGameState0xd321c decompilation calls this predicate before victory. Complete room/outcome call execution, field mutation and original campaign transition timing still require verification.

Full D2 destructor0x79af4 executes its ownership loops on supplied objects. It cleans portal/tower references, marks a supplied footprint generator for deletion, deletes supplied shadow/shooter/sound/laser/particle/sprite/missile objects, compacts vectors and clears pointers. It unregisters from the map only for ground resourceclass1 and releases the displaced hex point. Child destructor, heap, map and string operations are recording stubs; no full child cleanup or concurrent live registry executes. This confirms owned missiles are deleted at final owner destruction. Current game removes dead actors immediately and can retain orphan missiles; neither timing is corrected by this disconnected port.

## Evidence

- `native_creep_death_reference.py`:3000 full DoOnDying/CSprite.Update supplied cases and5 multi-step sequences.
- `native_creep_death_setdie_reference.py`:640 full SetDie cases with null lookups/empty new-resource particle tree and supplied existing emitters.
- `native_creep_death_effects_reference.py`:100 full SetDie cases across ten preserved creature families, real parameter values/texture names/alias order and original Sprite constructor; resource/audio/particle/decal/RNG stubs remain explicit.
- `native_creep_death_sprite_reference.py`:100 supplied constructor/DoOnDying/Update/Render states, actual PNG dimensions and recorded native quad geometry; no GPU executes.
- `native_creep_death_tail_reference.py`:50 full Creep.Update/DoOnDying/UpdateParticles/Particle.Update supplied newborn-burst sequences,1992 frames at five deltas. Already-born linked particles/lifetimes/counts are supplied; unrelated creep subsystems, emission, trajectories/child effects and whole room are omitted.
- `native_creep_death_manager_reference.py`:10 supplied manager vectors, three calls each; Creep.Update is explicitly replaced with full DoOnDying, and virtual deletion/ResetEffectCounters are recording stubs.
- `native_creep_death_target_reference.py`:72 full target queries with supplied states/owner/target and empty base vector.
- `native_creep_death_destructor_reference.py`:162 full original D2 cases, supplied owned vectors and explicit child/heap/registry stubs. Original D2 code bytes and executable file remain unchanged.

Matching JSON records are retained under `tests/fixtures/native-creep-death*`. Regenerating a generator imports no other fixture writer. All seven earlier promoted fixtures equal their separately retained research records exactly; the destructor fixture has a separately documented stub correction.

`game/scripts/creep_death_view.gd` and `tools/creep_death_ui_verify.gd` pass27,469 comparisons in the main source tree. The build gates this helper. Exact lifetime/position/scale/RGBA/quad-size bits and creation/expiry submissions compare with original function outputs. These are source-field checks, not Main/Simulation, whole particle, original input or GPU equivalence.

## Preserved failures and limits

The first resource probe omitted the const Rb-tree successor stub0x36c11c and reachedPC0. Its log/generator/address trace remain in builds. The first checker used strict Array equality for integer bit labels versus JSON float labels. Recursive exact numerical comparison fixes those type artifacts; it adds no tolerance. The remaining ten true position mismatches led to the original weighted interpolation port. The full initial failure bytes are retained; the intermediate ten-error summary is explicitly reconstructed from the tool report.

The first D2 probe's heap-delete hook redirected PC but did not return correctly from an original conditional call. An executable-memory-only ARM `bx lr` replacement at the external operator-delete stub makes the recording stub return through the emulated instruction stream. Original D2 bytes are checked unchanged for every case; the preserved file is unchanged. This establishes the corrected bounded probe, not a proven general Unicorn root cause. First/debug logs, trace and generator remain preserved. No expected state, scalar, bit or performance threshold was weakened.

Actual runtime work still needs retained dying actors and once-only rewards, existing smoke/status/child particle ownership, birth/update chronology, owner before/body/after ordering (including the original two ground-after calls), spatial crater admission, sound/random stream, full caller/destructor semantics and campaign timing. Do not substitute a fixed guessed death delay or a global overlay for those rules. The R123 package and its all-ten results retain their own scope.
