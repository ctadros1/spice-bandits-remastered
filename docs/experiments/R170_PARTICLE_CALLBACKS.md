# R170 retained particle callbacks and R171 lookup experiment

The source now avoids creating an unused bound child callback for retained creep roots whose active particle array is empty and whose release count is nonpositive. Every root still executes the same update, including delay, clock, disable, interval, zero-count Emit, release timestamp, pool and owner-alias handling. Active parents keep their callback even when their own release count is zero, because their children can still emit. The previous eager binding remains selectable for comparison. No particle arithmetic, original asset or game content changed.

## Evidence

The original R169 source/helper was exercised twice before changing the native bridge. Both complete records are identical. The immutable 2,560-row baseline covers ten supplied creep resources (including the unused creep7 resource), both coefficient paths, variable deltas, delay, freeze, slow, Disco, damage/healing, death bursts, retained child emission and pool reuse. It records normalized complete actor/system dictionary bytes, key types/order, numeric bits, callback request order, RNG and serials. This is reconstruction behavior preservation, not original whole-game/GPU identity. Its capture source and provenance are preserved beside the fixture in tests/reference/.

The final test passes **41,301 checks**, including all unchanged historical rows, 3,204 pool reuses, and 5,296 observed child particle births while a parent root has zero release count. Additional cases use empty active arrays with actual pooled parents and child particles, for release counts 0 and -3. They verify full state equality, untouched pool/child state and aliases, no factory requests, continued clocks and nonpositive Emit release timestamps. These cases do not replace or modify any historical row.

The unchanged R151 owner migration (7,003 checks), R146 key/type/state baseline (26,462), original owned particles (49,931), live owned rendering (2,445), retained lifecycle (116,841), constructor/birth/owner (144,989), Disco actor (43,471), Disco admission (77,446), allocation/defaults (184) and all 82 runtime scripts pass. All 4,035 original files and four protected saves are unchanged. Tests were sequential, isolated and headless; no game remains. The new preservation test is mandatory in the full build.

## Timing and decision

Two controlled ABBA runs on 32 actual owners compare the old eager callback path with deferred binding. Each phase measures eight 2,048-owner-call samples after two warmups and checks identical complete final actor/system/RNG/serial bytes after 640 updates per root.

| Workload | Eager phase medians, microseconds per owner | Deferred phase medians |
| --- | --- | --- |
| Healthy, run 0 | 22.123 / 22.208 | 21.307 / 21.327 |
| Damaged, run 0 | 37.380 / 37.435 | 36.763 / 36.731 |
| Healthy, run 1 | 21.608 / 21.789 | 20.839 / 20.877 |
| Damaged, run 1 | 36.522 / 36.733 | 36.040 / 36.083 |

The small, repeatable saving supports retaining this simple guard. It does not close the packaged frame-rate gap or establish a live speedup. No new app was exported just for this change. The installed package and accepted comparison stay at R169 and R137 respectively. The unchanged 33.34 ms packaged performance limit still fails in the last R169 run (35.063 / 40.250 / 45.593 ms).

R171 additionally tried reusing owner-field Variant key wrappers and avoiding discarded Array/Dictionary defaults, with both paths sharing the same arithmetic. All 2,560 R169 rows and callbacks still match, but field-only measurements are noisy and the gain is too small to justify the added template/branch complexity. That runtime experiment was removed; its exact reviewable patch and measurements remain preserved. Combined timings cannot be attributed to the lookup change alone.

Raw benchmark data, gate summaries and immutable-report digests are in [r170-particle-child-binding.json](r170-particle-child-binding.json). The rejected source experiment is in [r171-owner-lookups.patch](r171-owner-lookups.patch). Local raw logs, before/after reports, helper binaries and failed test setups remain under builds/child-binding-r170-* and builds/owner-lookups-r171-*.

## Preserved test failures

The first pool-reuse setup hit the original disable-after gate because Restart only pools parents; it does not reset the clock. The corrected case explicitly supplies a new emission window. A later new boundary case incorrectly looked for explosion roots at ordinary spawn. The corrected setup invokes the existing death-burst creation before supplying one parent and a retained child. Neither failure required a runtime behavior change, fixture rewrite or relaxed threshold. Their exact test sources/logs/reports are retained for recovery.

## Remaining work

Actual hover motion, its independent Freeze update and unscaled body-offset rendering remain unported. Original sound ownership, Fly/portal/growth/status joins, the constructor working-smoke field and broader UI/campaign/progression fidelity remain open. No expansion content or multiplayer was added. A passing preservation test does not prove complete reconstruction.
