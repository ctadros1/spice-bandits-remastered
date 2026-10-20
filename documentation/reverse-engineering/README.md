# Reverse-engineering process

[Documentation hub](../README.md) · [Preservation](preservation-and-assets.md) · [Binary analysis](binary-analysis.md) · [Case studies](case-studies.md) · [Verification](verification.md)

Reverse engineering here means recovering the original game's behavior from its preserved data, executable, interface resources, and footage, then implementing it in a maintainable desktop runtime. Decryption makes compiled instructions readable; it does not recover the original source project or remove the need to reconstruct missing platform and service behavior.

The primary behavioral reference is **version 1.14**. Version 1.27 and footage from different periods are tracked separately. No complete original installation has been run as an end-to-end reference in this project; selected original functions execute in controlled local emulation.

## From a question to an implementation

1. **Choose a concrete question.** Examples: which animation faces a target at an angular tie? When does a poison cloud remove an expired particle? Does a shadow draw before or after a projectile?
2. **Preserve the inputs.** Identify the executable, resource definitions, archive version, and relevant footage. Pin hashes and keep source inputs unchanged.
3. **Trace the code and data together.** Use symbols, disassembly, decompiler output, callers, field offsets, and authored values to identify a bounded behavior. A function name is a lead, not proof of its complete semantics.
4. **Execute selected original instructions.** Construct explicit inputs and memory, record external callbacks, and capture fields and event order. State exactly which surrounding systems are supplied rather than executed.
5. **Repeat and freeze the evidence.** Regenerate independently, compare bytes and hashes, and preserve a fixture with provenance. Keep exploratory and failed runs separate.
6. **Port and compare.** Implement the selected behavior in Godot/C++, preserving operation order, field types, ownership, and branch boundaries. Demonstrate both the prior mismatch and the corrected result where available.
7. **Join the real runtime.** Verify actual constructors, owners, retained particles, simulation updates, and render calls. A correct isolated helper may still be wired incorrectly.
8. **Review the packaged app.** Export a coherent candidate, run isolated suites, inspect full-resolution images and timing, and preserve the exact source/package/evidence. Record remaining differences before advancing the fidelity claim.

## Evidence vocabulary

| Term | What it establishes |
| --- | --- |
| Preserved input | An original file with a recorded identity, version, and integrity check. |
| Static finding | A conclusion from instructions, data, resources, or call sites; it may still need execution evidence. |
| Bounded original execution | Selected original instructions executed with a stated environment and callback boundary. |
| Fixture | A frozen record of inputs, outputs, fields, or events used for later comparisons. |
| Runtime integration | The reconstructed behavior runs through actual game objects and owners. |
| Packaged verification | The exported app passes a named check with recorded package identity and isolated saves. |
| Fidelity acceptance | The required original behavior and presentation match within the stated scope; broader acceptance needs broader evidence. |

“Native” in older filenames can refer to original ARM reference execution, the C++ helper, or a rendered macOS application. Read each record's scope instead of treating the word alone as a guarantee.

## Mechanics reference

These specifications connect recovered rules to probes, fixtures, runtime ports, and unresolved joins:

| Topic | Detailed records |
| --- | --- |
| Rules, targets, timing | [Baseline](../../docs/mechanics/BASELINE.md), [targeting](../../docs/mechanics/TARGETING.md), [update timing](../../docs/mechanics/UPDATE_TIMING.md) |
| Enemy movement and state | [Approach and routes](../../docs/mechanics/CREEP_APPROACH.md), [air paths](../../docs/mechanics/CREEP_AIR_PATH.md), [state and hover](../../docs/mechanics/CREEP_STATE.md), [shooting](../../docs/mechanics/CREEP_SHOOTING.md), [rewards](../../docs/mechanics/CREEP_REWARDS.md) |
| Animation and rendering | [Animator](../../docs/mechanics/ANIMATOR.md), [enemy presentation](../../docs/mechanics/CREEP_PRESENTATION.md), [health bars](../../docs/mechanics/CREEP_HEALTH.md), [map render order](../../docs/mechanics/MAP_RENDER_ORDER.md) |
| Particles and ownership | [Particles](../../docs/mechanics/PARTICLES.md), [children](../../docs/mechanics/PARTICLE_CHILDREN.md), [clocks](../../docs/mechanics/PARTICLE_CLOCKS.md), [enemy ownership](../../docs/mechanics/CREEP_PARTICLE_OWNER.md) |
| Combat effects | [Projectiles](../../docs/mechanics/PROJECTILES.md), [clouds](../../docs/mechanics/CLOUD_LIFECYCLE.md), [poison bubbles](../../docs/mechanics/POISON_BUBBLE.md), [Disco](../../docs/mechanics/DISCO.md), [decals](../../docs/mechanics/DECALS.md) |
| Interface and progression | [Interface](../../docs/mechanics/INTERFACE.md), [tutorial layout](../../docs/mechanics/TUTORIAL_LAYOUT.md), [results](../../docs/mechanics/RESULT_LIFECYCLE.md), [progression](../../docs/mechanics/PROGRESSION.md), [campaign access](../../docs/mechanics/CAMPAIGN_ACCESS.md) |
| Sound | [Audio](../../docs/mechanics/AUDIO.md) |

## Working rules

Preserve original archives, immutable fixtures, earned profiles, failed candidates, and previous comparison evidence. Repair derived content rather than source archives. Never loosen an assertion or performance limit merely to pass a candidate. Label supplied resource records, callback math, synthetic scenes, and local-service adaptations where they enter the experiment.

The [case studies](case-studies.md) show why these boundaries matter. The [verification guide](verification.md) explains the final checks and recovery records.
