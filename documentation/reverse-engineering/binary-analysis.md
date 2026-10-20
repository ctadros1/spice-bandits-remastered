# Binary analysis and bounded execution

[Process](README.md) · [Case studies](case-studies.md) · [Verification](verification.md)

The decrypted 1.14 executable is useful because it retains substantial symbol information. The initial assessment counted **91,868 symbol-table entries** and indexed **2,248 function records** associated with 102 game/engine compilation units, including library templates. Those counts describe analysis leads, not recovered source code or a measured percentage of fidelity.

## Static analysis

The executable and resource definitions are examined together. Named methods such as `CCreep::UpdateShootingDirection` identify likely behavior; call sites, branch instructions, resource reads, field offsets, and update/render/destructor relationships explain how that behavior is used.

Ghidra and focused disassembly support this analysis. Decompiled output is an interpretation: types, ownership, initialization, floating-point conversions, and caller assumptions still need verification. The [executable assessment](../../research/EXECUTABLE_AND_ASSET_ASSESSMENT.md) explains the original platform and the limits of source recovery.

The original program depends on legacy iOS frameworks, graphics/audio backends, platform ABI, and services. Reading an unencrypted function does not make the complete app runnable on modern macOS. The [progression investigation](../../research/PROGRESSION_RECOVERY.md) records unsuccessful full-app reference approaches separately from successful bounded function execution.

## Dynamic reference harnesses

The reference tools use **Unicorn 2.1.4** to execute selected ARM/Thumb instructions from the preserved binary. A harness maps code and data, prepares registers and object memory, invokes selected entry points, and records resulting fields or events.

The [`base creep harness`](../../tools/native_creep_reference.py), for example, pins the original executable SHA-256 before executing it. More specialized probes build on earlier harnesses to join constructors, movement, routing, states, and effects.

Every probe has two important boundaries:

- **Executed behavior:** the unchanged original function bodies and any explicitly included callees.
- **Supplied environment:** object/resource records, memory allocation, containers, random or math callbacks, particle statuses, rendering calls, sound, and services that the harness models or records.

A callback that records a draw call proves that the selected original routine requested that draw under the supplied inputs. It does not prove the original GPU produced matching pixels. A particle status callback can establish an owner's removal order without establishing the particle system's complete physics.

## Inputs that reveal real differences

Useful probes cover boundaries and sequences rather than a single attractive example: zero and negative values where relevant, exact expiry points, one-bit flags, null/missing objects, equal candidates, angle wraparound, transitions, repeated calls, and destruction. Long sequences expose retained-state and rounding differences that isolated calls can miss.

The ports retain **float32 operation order**, strict versus inclusive comparisons, integer truncation, update-before-remove versus remove-before-update behavior, first-wins ties, and authored traversal order. Signed zero and nonfinite values are preserved or explicitly documented where a finite presentation fallback is required. Approximate decimal agreement is insufficient when the original fixture specifies exact bits.

The C++ helper uses `-ffp-contract=off -fno-fast-math` to avoid changing recovered arithmetic through fused operations or reassociation. Reference checks still apply to the particular inputs and implemented paths.

## Reproduce without replacing the baseline

After restoring the required original inputs and analysis files and preparing the reference runtime, run from the repository root with new output paths:

```sh
mkdir -p builds
python3 tools/native_creep_shooting_reference.py \
  --output builds/shooting-independent-a.json
python3 tools/native_creep_shooting_reference.py \
  --output builds/shooting-independent-b.json
cmp builds/shooting-independent-a.json builds/shooting-independent-b.json

python3 tools/native_poison_bubble_reference.py \
  --output builds/bubble-independent-a.json
python3 tools/native_poison_bubble_reference.py \
  --output builds/bubble-independent-b.json
cmp builds/bubble-independent-a.json builds/bubble-independent-b.json
```

These generators reject an existing output file. Use fresh names on another attempt. Independent equality demonstrates repeatability of that probe; compare its bytes/hash with the committed fixture and inspect its stated callbacks before treating it as a baseline. Preserve the established fixture when investigating a difference.

## Traceability

| Behavior | Original probe | Frozen fixture | Port/comparison | Specification |
| --- | --- | --- | --- | --- |
| Shooting direction | [`native_creep_shooting_reference.py`](../../tools/native_creep_shooting_reference.py) | [`native-creep-shooting-reference.json`](../../tests/fixtures/native-creep-shooting-reference.json) | [`creep_shooting_ui_verify.gd`](../../tools/creep_shooting_ui_verify.gd) | [Shooting](../../docs/mechanics/CREEP_SHOOTING.md) |
| Poison bubble lifecycle | [`native_poison_bubble_reference.py`](../../tools/native_poison_bubble_reference.py) | [`native-poison-bubble-reference.json`](../../tests/fixtures/native-poison-bubble-reference.json) | [`bubble_lifecycle.gd`](../../game/scripts/bubble_lifecycle.gd), [`poison_bubble_ui_verify.gd`](../../tools/poison_bubble_ui_verify.gd) | [Poison bubbles](../../docs/mechanics/POISON_BUBBLE.md) |

The [case studies](case-studies.md) explain what these chains recovered and what remains outside them.
