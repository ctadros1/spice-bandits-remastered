# R189 active particle array allocation

R188 identifies particle advancement as the largest measured creep subphase. This bounded experiment changes only allocation of each nonempty owned system’s next active array. A shallow duplicate initially holds the same particle dictionary references in order. Survivors compact in the new array and the final resize drops expired entries. The previous active array remains structurally unchanged. Empty roots retain their existing clock/Emit path, and typed inputs retain the prior untyped append output. Recursive child updates propagate the same selection. The prior append path remains callable with `copy_active=false`.

Particle scalar arithmetic, definition/header reads, update order, callbacks, pool order, RNG, serials and rendering are unchanged. Removing only the allocation option from the candidate source reproduces the complete prior particle source byte for byte. All 82 game scripts remain byte exact R187. There is no particle count reduction, timestep change or asset/geometry change.

The mandatory source gate passes **315,806 checks**. Both allocation branches match all 2,560 independently repeated immutable R169 full actor/system/key/numeric/RNG/serial/callback rows, plus explicit previous-array, fresh-output, particle dictionary and pool alias checks. Twenty additional comparisons cross typed/untyped, mutable/read-only, all live, all expired, alternating expiry, prefix expiry and suffix expiry using actual smoke particles. Active children still emit with stopped parents; both coefficient and deferred callback selections are covered. The initial new alias assertion incorrectly tested old-array emptiness after Emit had filled an initially empty root. Its complete failed script/report/log and corrected pre-update snapshot check are retained; its 2,560 historical rows already matched. No expected row or numeric tolerance changed.

Two controlled ABBA runs use 32 actual healthy/damaged owners, eight measured samples after two warmups and 640 updates per root. Every complete final actor/system/RNG/serial hash matches. Phase medians in microseconds per owner are:

| Run / workload | Retained outer phases | Copied inner phases |
| --- | --- | --- |
| 0 healthy | 21.545 / 21.511 | 21.007 / 21.068 |
| 0 damaged | 38.475 / 37.270 | 35.771 / 36.862 |
| 1 healthy | 21.325 / 21.562 | 21.114 / 21.075 |
| 1 damaged | 37.169 / 37.128 | 35.847 / 35.858 |

The saving is modest, roughly 2% healthy and 3–4% damaged when averaging each run’s phase medians. This is a controlled helper observation, not a live frame-rate pass or isolated package speedup. The small allocation branch is retained; the previous R171 larger lookup/template experiment remains rejected.

The full **source-only** build passes in 144.85 seconds: 41,544 simulation checks, 4,035 original hashes, 82 runtime scripts and 100 explicitly enumerated fresh logs without errors/leaks. All 147 existing fixture/reference JSON files are byte exact. No new app was exported, no numeric performance gate was rerun, and no visual fidelity acceptance is claimed. Current R187 package, four normal/earned saves and accepted R137 guide are preserved. R187’s unchanged 33.34 ms performance limit still fails. Combine source work with further original caller reconstruction before the next coherent package review.

See [validation and complete timings](../validation/2026-10-19-r189-particle-active-copy.json), `tools/particle_active_copy_ui_verify.gd` and `tools/particle_active_copy_benchmark.gd`. Before/candidate helpers, raw unit/benchmark/build reports and failures remain under builds/particle-copy-r189-* and will be included in private source/evidence recovery. Full original gameplay, UI, sound, campaign and progression fidelity remain incomplete.
