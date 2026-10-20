# Current reconstruction status

[Documentation](README.md) · [Evidence standards](reverse-engineering/verification.md) · [Exact R200 review](../docs/validation/2026-10-19-r200-packaged-native-review.json)

This snapshot describes **R200 as reviewed on October 19, 2026**. Writing this guide did not rebuild the game or repeat its native tests. Results below come from checkpoint records, including the subsequent app recovery receipt.

## What exists

The macOS reconstruction loads all **148 nonempty offline schedules** and implements tower placement, branching upgrades, selling, path and target rules, combat and support behavior, abilities, campaign access, tutorial, menus, results, local transactional saves, and progression adaptations. The preserved map inputs cover all **54 map IDs** required by those schedules.

The runtime is Godot with a C++ helper for selected expensive operations. The app is built for Apple Silicon and Intel as a Universal2 package; compiling the Intel slice does not establish that it runs correctly on Intel hardware.

The project's evidence includes selected original ARM function executions, exact field comparisons, image comparisons, recorded audio, packaged-app suites, and campaign experiments. These establish particular behaviors, with the limits recorded alongside each result.

## Latest packaged review

| Check | Recorded R200 result |
| --- | --- |
| Automated presentation | 764 checks and 235 PNG captures pass. |
| Eight functional suites | Menus, tutorial, audio, projectiles, turns, towers, Desert, and campaign pass their existing automated assertions. |
| Independent visual review | Fails the first projectile capture, `projectiles-300.png`: terrain and HUD are missing. Later captures show them. The same first-frame issue also exists in R196, so this does not establish a new bubble-runtime regression. |
| Performance at 1× / 2× / 4× | Median 41.381 / 42.848 / 41.979 ms; each exceeds the unchanged 33.34 ms limit. Recorded p95 values are 54.427 / 48.698 / 49.978 ms. |
| World-map performance | Median 5.469 ms; p95 14.741 ms. No stalls or runtime errors are recorded in the performance audit. |
| Preservation and isolation | Four protected save files, package/source identity, signature, runtime isolation, and cleanup guards pass. |
| Recovery | R200 source recovery is verified. The later [R200 app recovery receipt](../docs/backups/2026-10-19-r200-bubble-runtime-app-failure.json) verifies actual remote restoration of the failed app/evidence, source bytes/modes, signature, and isolated launch. |

The result is **not all-ten-suite acceptance** and does not establish complete offline fidelity. The exact failed package/evidence is preserved in a recovery draft. The next implementation work is a bounded projectile capture readiness check and review of a coherent corrected package. Repeating an unchanged performance test merely to obtain a passing sample would not resolve its failure.

## What remains

- Complete the original presentation and interaction requirements: tray and drag placement, location/mode windows, loading, results, tutorial, combat animation, menus, shop, career, and fitting.
- Resolve remaining factory/parser, complete room and owner ordering, particle/effect lifetime, original global randomness, audio ownership, and original rendering-environment joins.
- Keep reconstructed local progression separate from unknown hosted progression and reward behavior.
- Verify physical trackpad behavior, speaker listening, Intel execution, and distribution notarization separately.
- Complete the original offline experience before multiplayer or expansion work.

The [implementation plan](../PLAN.md) carries the full acceptance scope. The [fidelity record](../docs/FIDELITY.md) and [mechanics notes](reverse-engineering/README.md#mechanics-reference) retain detailed uncertainties.
