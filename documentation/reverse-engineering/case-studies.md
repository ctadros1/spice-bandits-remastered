# Worked reverse-engineering examples

[Process](README.md) · [Binary analysis](binary-analysis.md) · [Verification](verification.md)

These examples follow the evidence from a specific question to an implementation result. They also show why passing an isolated reference comparison is only one stage of acceptance.

## 1. Which direction should a creature face?

**Question.** A walking or shooting creature needs to select the original authored animation direction. A generic nearest-angle implementation can look reasonable while disagreeing at wraparound, ties, or transitions.

**Original evidence.** R183 executes the full original shooting-direction method and its angle helpers, together with selected constructor/source/path/movement callers. Two independent runs reproduce a 7,822,894-byte fixture. The selected environment still supplies container operations, an external arctangent callback, and other recorded backend context.

**Recovered details.** The method retains float32 normalization, a minus-90-degree conversion, an asymmetric candidate-minus-360 comparison, strict first-wins ties, and the caller's body-offset aim before hover. The approach/alignment boundary also affects retained animation names.

**Implementation evidence.** The final comparison passes **80,423 assertions**, covering 656 direct directions, 21 tie cases, 24 actor sequences, and 2,440 movement frames. Earlier omitted-callback fixtures remain unchanged; their historical limitations are not erased by the broader probe.

**Boundary.** This recovers selected facing and caller behavior. It does not establish the original math library, animation backend, GPU output, or every special creature's complete lifecycle.

Read the [shooting specification](../../docs/mechanics/CREEP_SHOOTING.md), [probe](../../tools/native_creep_shooting_reference.py), [comparison](../../tools/creep_shooting_ui_verify.gd), and [R183 receipt](../../docs/validation/2026-10-17-r183-shooting-facing.json).

## 2. Why is a poison bubble more than a moving sprite?

**Question.** Chemical/Goo bubbles have a body, shadow, lift and dive clocks, trails, stars, arrival bursts, and particle tails. Correct motion alone cannot reproduce their lifetime or appearance.

**Original evidence.** R197 executes 2,812 selected original bytes across constructor, update, render, destruction, and interpolation/distance helpers. Two independent runs reproduce **216 supplied sequences and 3,824 frames**. The environment explicitly supplies textures, resource/target lookup, particle factory/status/update/render, draw/color/blend, and memory callbacks.

**Recovered details.** The body draws before its shadow; the lift shadow moves with the bubble's height. Retained particle roots can outlive active flight. Removal happens according to the original status/flag checks and traversal order. Caller analysis confirms that the two ordinary tower creation sites pass `follow_target=false`; the existence of a tracking branch does not justify enabling it for those callers.

**Port and integration.** R198's pure lifecycle controller passes **720,050 comparisons**. R199 joins real retained particles and passes **17,993 checks across 600 native/reference frame pairs**. That integration first exposes 16 held-restoration alias failures: restored wrapper particles and owned renderer particles must refer to the same array. The correction rebinds those arrays without changing serialized state or particle physics.

R200 connects normal constructors, owners, simulation, and rendering. Its new gate records **38,663 checks** over nine three-tier contexts, with 19 source-native PNGs reviewed. These are successive evidence stages; the earlier pure-controller result did not itself prove the later owner/runtime integration.

**Boundary.** Full original factory/parser header provenance, complete room ordering, global RNG, GPU/audio behavior, and whole-game presentation remain open. Dormant zero-disable particle roots are retained according to the observed imported behavior rather than removed using an invented timeout.

Read the [bubble specification](../../docs/mechanics/POISON_BUBBLE.md), [original probe](../../tools/native_poison_bubble_reference.py), [lifecycle port](../../game/scripts/bubble_lifecycle.gd), [runtime gate](../../tools/bubble_runtime_ui_verify.gd), and [R200 integration receipt](../../docs/validation/2026-10-19-r200-bubble-runtime.json).

## 3. When an automated pass misses the picture

**Question.** Does a passing packaged projectile suite mean its saved images are visually ready?

**Observed result.** R200 passes its existing projectile assertions and automated presentation checks. Independent full-resolution review nevertheless rejects `projectiles-300.png`: terrain and HUD sample points contain black pixels. Later 720/3000/4440 ms frames render the background. The first-frame problem is also present in R196, so the record does not claim a newly introduced bubble regression.

**Implication.** A suite can correctly verify the assertions it contains while omitting an essential visual condition. The next recorded correction is a bounded capture warmup/readiness check with independent rejection of an unready saved PNG, preserving the failed app and gallery.

**Separate performance finding.** The same package fails the unchanged 33.34 ms median limit at all three tested speed settings. A passing effect/controller comparison does not explain away that timing result.

Read the [exact R200 packaged review](../../docs/validation/2026-10-19-r200-packaged-native-review.json) and [current status](../status.md). The documentation reports the failure; this publication change does not repair the game or rerun those checks.
