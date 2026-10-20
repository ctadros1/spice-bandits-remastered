# Preservation and asset recovery

[Process](README.md) · [Binary analysis](binary-analysis.md) · [Original assessment](../../research/EXECUTABLE_AND_ASSET_ASSESSMENT.md)

The preservation layer keeps the original files available and distinguishable from the reconstructed runtime. Every conversion starts from a versioned input; a repaired map or decoded image is a derived artifact, not a replacement original.

## Establish the reference version

Two supplied 1.14 archives contain matching game art and data. Their important executable difference is encryption state: the readable copy reports `cryptid=0`, while the encrypted archive reports `cryptid=1`. The decrypted executable is a **32-bit ARMv7 Mach-O**, not compilable source.

Version **1.27** is preserved independently. Its ARMv7 and ARM64 code slices are encrypted, and its embedded offline data and 200 XML files match 1.14 byte for byte. Later assets can inform presentation research, but a newer package does not automatically supersede the primary reference or add campaign definitions. See the [version comparison](../../research/FILE_DISCOVERY_SUMMARY.md).

Archive manifests, extracted inventories, ZIP checks, and SHA-256 digests establish identity. [`verify_originals.py`](../../tools/verify_originals.py) checks the preservation corpus before the normal build proceeds.

## Recovered material

The [October 13 assessment](../../research/EXECUTABLE_AND_ASSET_ASSESSMENT.md) records the following inventory. Counts describe different kinds of material and should not be combined into an invented total of “levels.”

| Material | Recorded inventory | Reconstruction use |
| --- | --- | --- |
| Images | 875 PNGs, including 455 Apple CgBI files; 44 files named `.jpg`, one containing PNG bytes. | Sprites, atlases, maps, effects, and interface art. |
| XML | 200 authored files. | Maps, content definitions, sprite and animation metadata. |
| Audio | 92 CAF files, comprising 59 PCM and 33 IMA4; eight MP3s. | Effects, music, and reconstructed mixing behavior. |
| Other media and UI | Two MOVs, five fonts, and 44 NIB files. | Video conversion, text rendering, and original interface geometry. |
| Embedded offline data | 18 tower forms with 54 level entries, 29 populated enemy definitions, 20 upgrades, 78 medals, 298 mission listings, and 149 offline records. | Authored balance, progression clues, and mission configuration. |
| Usable wave schedules | 148 nonempty schedules containing 2,305 wave entries. | Offline campaign reconstruction; the remaining record is an empty special configuration. |
| Additional preserved files | 63 referenced level ZIPs and 89 costume images with 89 previews. | Map/content coverage and presentation references. |

The combined archives contain 66 distinct numbered map IDs, including every one of the 54 IDs used by the nonempty offline schedules. File coverage alone does not prove every mission is playable or visually faithful.

## Conversion without altering evidence

The [`original content importer`](../../tools/importers/import_original.py) reads preserved files and generates Godot assets and JSON. Its responsibilities include Apple-specific PNG decoding, atlas and animation metadata, content definitions, map layers, NIB-derived layouts, audio conversion, and import audits.

Two bundled XML prefix defects and strict-parse errors in downloaded `map_100.xml` and `map_1004.xml` need documented handling in derived content. When a downloaded asset differs from the bundled 1.14 version, precedence is recorded rather than silently replacing the reference.

CAF audio is converted with Apple's tools. The publisher movies are derived as Theora/Vorbis while preserving their dimensions and 25 FPS cadence. Current macOS font rendering and media decoding still need separate visual/audio comparison with the original environment; successful conversion is not evidence of old UIKit or GPU pixel identity.

Use [`verify_import.py`](../../tools/verify_import.py) for the independent media conversion check, and [`inspect_assets.py`](../../tools/inspect_assets.py) for the local atlas/map inspector. See [build instructions](../getting-started.md) for prerequisites.

## Footage and interface evidence

NIBs retain authored geometry and view relationships but cannot be loaded as Godot scenes. Gameplay footage shows composition, transitions, tutorial sequences, and interaction context that static files do not fully explain.

The supplied iPad TouchGameplay recording is the main visual/interaction guide. The reconstruction keeps a 1024 × 768 logical canvas and original asset proportions; a recording that appears stretched is not a reason to distort imported art. Phone footage, earlier Spice Invaders material, later packaging, and promotional claims retain their own context.

See the [source catalog](../../research/SOURCES.md), [video observations](../../research/VIDEO_OBSERVATIONS.md), and [gameplay findings](../../research/GAMEPLAY_FINDINGS.md). A link being discovered is different from footage being reviewed, and a sampled frame is different from a complete comparison.

## Public source and recovery archives

The Git tree excludes `original/`, generated `game/assets/` and `game/data/`, `work/`, and `builds/`. Historical release archives may contain preserved inputs, compiled apps, or raw evidence. Their restoration instructions and manifests define what they contain. Public availability does not change the ownership of original game materials.
