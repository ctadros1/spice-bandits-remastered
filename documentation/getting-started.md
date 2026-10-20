# Getting started

[Documentation](README.md) · [Architecture](architecture.md) · [Detailed build record](../docs/BUILD.md) · [Status](status.md)

You can read the source, mechanics specifications, and committed fixtures from a normal clone. **Building the application also requires preserved original inputs and a prepared toolchain.** The repository is not a self-contained game download.

## 1. Get the source

```sh
git clone https://github.com/ctadros1/spice-bandits-remastered.git
cd spice-bandits-remastered
```

Published [release archives](https://github.com/ctadros1/spice-bandits-remastered/releases) are historical preservation/recovery checkpoints. Inspect each checkpoint's manifests, restoration instructions, and limitations before using it. Old records can call these releases “private,” reflecting the repository's visibility when the record was made. Draft-only checkpoints still require repository access and are not public downloads.

## 2. Restore the preserved-input layout

The build verifies a preservation corpus rather than accepting an arbitrary IPA dropped into the project. Its verifier expects archive manifests, extracted version inventories, downloaded-pack records, and matching files. Important paths include:

```text
original/
  archives/
  analysis/
    archive-manifest.json
    inventory.json
    ipa-1.27-inventory.json
    download-manifest.json
  game-files/
    ipa-1.14/Payload/Tower.app/
    ipa-1.27/
    downloaded-packs/
  additional-files/
    mirrors/download-manifest.json
    official/offline.dat
```

This is an overview, not a complete restoration manifest. Use the relevant checkpoint's `RESTORE.md` and manifest for exact paths and hashes. [`verify_originals.py`](../tools/verify_originals.py) is the authoritative input check. The public Git tree does not contain these originals, generated assets, or local toolchains.

## 3. Prepare the pinned tools

| Tool | Current build requirement |
| --- | --- |
| macOS development tools | Xcode Command Line Tools for C++, Swift, Apple media conversion, and signing utilities. |
| Godot | `4.7.2.stable.official.ed1daf0bf`, with matching macOS export templates. Default engine path: `work/toolchain/Godot.app/Contents/MacOS/Godot`. |
| Python | Python 3.9+ and Pillow 12.3.0 for content import. `SPICE_PYTHON` can select the prepared interpreter. |
| C++ bindings | godot-cpp commit `b8530af7546a3fcae80cef2477526569fd42ffc2`; the helper build prepares the checkout under `work/toolchain/`. |
| SCons | 4.10.1; the helper build prepares an isolated environment. |
| Video conversion | FFmpeg 8.1.3 with the pinned Theora/Vorbis/Ogg dependencies described in the build record, or verified cached conversions. |
| Further binary research | Ghidra/JDK for analysis and Unicorn 2.1.4 for the ARM harnesses. These are separate from app runtime dependencies. |

The [detailed build record](../docs/BUILD.md) contains the pinned archive hashes, template installation path, converter setup, and environment overrides. The scripts check pinned versions; substituting a newer engine changes the experiment.

## 4. Verify and build

From the repository root, with the preceding inputs and tools ready:

```sh
# Full source build and checks, stopping before app export.
zsh tools/build_macos.sh --verify-only

# Full checks followed by macOS export.
zsh tools/build_macos.sh
open 'builds/Spice Bandits Remastered.app'
```

The build verifies original hashes, imports derived content, builds the native helper, imports Godot resources, runs source gates, and scans logs. An exported app still needs its own packaged verification; source checks do not establish that the exported runtime behaves identically.

## 5. Work without risking normal saves

Once content is imported, open `game/project.godot` in the pinned Godot editor. Use the QA entry points for experiments: running the app normally uses the normal profile.

The existing packaged runner creates isolated QA contexts and records package identity and protected save hashes:

```sh
python3 tools/run_packaged_suites.py --label your-fresh-checkpoint
```

Run packaged suites sequentially, with a fresh label for each candidate, and keep the source/package fixed during the batch. Current performance and visual failures remain meaningful failures; see [status](status.md) and [verification standards](reverse-engineering/verification.md). Preserve old evidence rather than overwriting it to obtain a clean report.
