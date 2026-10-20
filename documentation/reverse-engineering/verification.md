# Verification, fidelity, and recovery

[Process](README.md) · [Current status](../status.md) · [Validation record](../../docs/VALIDATION.md) · [Backup process](../../docs/BACKUP.md)

Verification is layered because each kind of evidence answers a different question. Recovering one function, matching its fields, rendering a synthetic scene, and reproducing a complete original interaction are distinct achievements.

## What each layer proves

| Layer | Typical checks | What still needs separate evidence |
| --- | --- | --- |
| Preservation | Archive/file hashes, inventory, extraction integrity, version separation. | Gameplay correctness and completeness. |
| Import | Deterministic JSON, decoded image/audio checks, atlas/layout inspection. | Original rendering and playback equivalence. |
| Original-function oracle | Repeated ARM executions, exact fields/bits, ordered callback events. | Supplied callbacks, missing callers, platform services, and GPU/audio behavior. |
| Reconstructed component | Script/native comparisons against frozen fixtures and retained-state sequences. | Real constructors, owners, traversal, and scene integration. |
| Source integration | Actual simulation objects, held-state restoration, full build gates, log/error/leak checks. | Exported package behavior and visual acceptance. |
| Packaged application | PCK/executable/helper identity, isolated native suites, images, audio, performance. | Whole-game fidelity beyond the tested scenarios and manual review. |
| Original experience | Matched presentation states, interaction sequences, progression, sound, and campaign behavior. | Any remaining unobserved or unavailable original behavior. |

## Repeatability and immutable evidence

Run original probes independently and compare full outputs, not just headline counts. Pin the executable and resource inputs. Preserve field types, bit patterns, event order, and known nonfinite cases when the fixture requires them. A correction to a harness or supplied callback is recorded as such, with the first result retained.

Reference fixtures are evidence, not expected values to regenerate whenever implementation differs. First determine whether the implementation, the supplied environment, or the original interpretation is wrong. Keep failed runs and their exact source state so that later fixes remain explainable.

## Packaged checks and save protection

The complete packaged batch uses [`run_packaged_suites.py`](../../tools/run_packaged_suites.py). Its ten suites cover menus, presentation, performance, tutorial, audio, projectiles, turns, towers, Desert, and campaign. The runner records candidate identity and isolated QA context; protected normal and earned profiles must retain their hashes.

Source and package remain fixed for a batch. Use fresh labels, run native suites sequentially, inspect error/leak logs, and verify that owned processes exit. A package changed after verification needs a new identity-bound review.

Recorded audio output verifies selected mixer and file behavior; it does not replace listening through speakers. A Universal2 executable contains both architecture slices; Intel hardware execution remains a separate test. An ad hoc signature check is separate from distribution notarization.

## Image and interaction review

Compare source and reconstructed states with their platform, aspect ratio, mission mode, tower tier, timing, and known version recorded. Inspect full-resolution images, crops, geometry, alpha, ordering, and retained actors. Contact sheets help navigation but do not replace looking at the underlying frames.

Synthetic QA poses and source-native captures must be labeled separately from ordinary gameplay and packaged captures. A headless geometry match does not establish GPU pixels. A scripted tutorial replay does not establish physical mouse or trackpad behavior. The [R200 first-projectile failure](case-studies.md#3-when-an-automated-pass-misses-the-picture) demonstrates why independent visual review remains required even after automated assertions pass.

## Performance

Keep the established workload and threshold visible. Report median and tail timing with the tested speed settings and package identity. Current records use an unchanged **33.34 ms median limit**. Retain failures; changing a tolerance or repeating an unchanged test until one sample passes does not establish a correction.

Distinguish a microbenchmark of one helper from measured frame time in the app. Evolving fixtures and noisy runs do not establish an isolated speedup. The [R200 status](../status.md) reports the current failure and its exact measured values.

## Recovery as a reproducibility check

Historical checkpoints can include source bundles or patches, executable-mode/file manifests, signatures, apps, failed candidates, raw probe outputs, images, logs, and archive parts. A recovery claim requires downloading the actual remote assets, checking hashes and sizes, validating safe archive paths and integrity, and restoring source bytes and modes in an empty location.

App recovery adds package/signature checks and an isolated launch outside the development working directory, with protected saves unchanged. Upload success alone is not proof of restoration. Source recovery is also different from recovery of the actual compiled app and its evidence.

See [backup documentation](../../docs/BACKUP.md) and [checkpoint receipts](../../docs/backups/). Published recovery releases and private drafts have different access; a public source clone cannot resolve every local evidence path or draft URL in a historical record.

## Making a claim

State **what was implemented, what was tested, which exact candidate was tested, what passed or failed, and what remains supplied or unknown**. Do not convert a count of assertions, recovered symbols, or available maps into a percentage of overall fidelity. Complete offline reconstruction remains an acceptance objective, not a conclusion from a selected test suite.
