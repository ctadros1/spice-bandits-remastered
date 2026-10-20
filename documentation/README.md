# Documentation

**Understand the game, the reconstruction, and the evidence behind it.**

[Project introduction](../README.md) · [Current status](status.md) · [Setup](getting-started.md) · [Architecture](architecture.md) · [Reverse engineering](reverse-engineering/README.md)

Spice Bandits: Remastered rebuilds an older iOS tower-defense game for macOS. This guide connects the newcomer-facing explanations to the detailed research and checkpoint records already maintained in the repository.

## Choose a reading path

| If you want to… | Read |
| --- | --- |
| Learn what this project is for | [The project introduction](../README.md#the-project), then [current status](status.md). |
| Build or inspect the game | [Getting started](getting-started.md), then [architecture](architecture.md). |
| Understand the reverse-engineering process | [Workflow](reverse-engineering/README.md), [asset preservation](reverse-engineering/preservation-and-assets.md), then [binary analysis](reverse-engineering/binary-analysis.md). |
| Follow a specific discovery | [Worked case studies](reverse-engineering/case-studies.md), then the linked mechanics specifications. |
| Evaluate a fidelity claim | [Verification and evidence](reverse-engineering/verification.md), [fidelity record](../docs/FIDELITY.md), and the corresponding [validation receipt](../docs/validation/). |
| Continue development | [Handoff](../HANDOFF.md), [plan](../PLAN.md), and [detailed build notes](../docs/BUILD.md). |

## Where the records live

- **`documentation/`** explains the project and methods in reading order.
- **[`docs/mechanics/`](../docs/mechanics/)** contains subsystem specifications, discoveries, probe boundaries, and unresolved behavior.
- **[`docs/validation/`](../docs/validation/)** contains machine-readable checkpoint summaries. Their local file paths identify evidence from the producing workspace; those files are not automatically included in a public clone.
- **[`docs/backups/`](../docs/backups/)** records preservation and recovery checks. Historical references to a “private” repository describe visibility at the time; published releases may now be public, while drafts still require access.
- **[`research/`](../research/)** records sources, version assessments, footage observations, and content searches.
- **[`tests/`](../tests/)** holds frozen fixtures and reference records used by reconstruction checks.

## Reading checkpoint history

Labels such as **R183** and **R200** identify development checkpoints. A statement that a gate passed applies to that checkpoint's source, inputs, and package. Older “current” or “next” notes preserve their original context and may be superseded by a later record.

Start with [status.md](status.md) for a readable snapshot and [HANDOFF.md](../HANDOFF.md) for the latest detailed continuation record. The former front-page log is retained in [README_CHECKPOINTS.md](../docs/README_CHECKPOINTS.md); earlier consolidated history is in [RECONSTRUCTION_HISTORY.md](../docs/RECONSTRUCTION_HISTORY.md).
