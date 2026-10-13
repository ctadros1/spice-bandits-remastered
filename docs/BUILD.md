# Local build

The project is pinned to Godot **4.7.2.stable.official.ed1daf0bf**, with the matching macOS export template. The local importer requires Python 3.9+, Pillow 12.3.0, and Apple's `afconvert`. Original inputs remain local beneath `original/`; the importer writes only derived assets, JSON, and its audit.

Toolchain downloads used:

| Input | SHA-256 |
| --- | --- |
| [Godot 4.7.2 macOS Universal](https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip) | `c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e` |
| [Matching export templates](https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz) | `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` |
| [Ghidra 12.1.4](https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip) | `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db` |
| [Temurin JDK 25.0.4.1, macOS ARM64](https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/OpenJDK25U-jdk_aarch64_mac_hotspot_25.0.4.1_1.tar.gz) | `61979887f7506a24a57439ff99adb8b3a7fc89977d9cfe3b8984f58a981b7b9d` |

Extract Godot into `work/toolchain/Godot.app`. Install the template's `macos.zip` in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Ghidra/JDK are required only for further binary research; they are not app dependencies. This Ghidra archive lacked the native macOS ARM decompiler, so it was built from its included C++ source with `make ghidra_opt`, ARM64 and macOS 11 flags, then placed in `Ghidra/Features/Decompiler/os/mac_arm_64/decompile`.

Run from the project directory:

```sh
zsh tools/build_macos.sh
open 'builds/Spice Bandits Remastered.app'
```

`SPICE_GODOT` and `SPICE_PYTHON` can point to alternate installations of the same pinned versions. The script verifies preservation, regenerates content, imports the project, runs simulation and tutorial UI checks, exports, and checks the ad hoc signature and executable slices. It does not establish original-game parity or an Intel hardware result.

Independent full image/audio conversion check:

```sh
python3 tools/verify_import.py
```

To develop, open `game/project.godot` in Godot. Generated content and Godot caches are ignored by Git. Keep the original archive with a local clone; source code alone intentionally does not redistribute the original art, account metadata, or videos.

## Local QA captures

The app accepts `-- --qa` to isolate its save from the normal profile. `--mission=8 --qa-demo` creates the documented Desert Freighter fixture with T1L3 technology already owned. It is not a fresh-profile progression result. `--capture=/absolute/image.png --smoke-quit` captures a frame and exits; `--qa-render-all --capture-root=/absolute/directory` captures all 148 authored offline configurations and writes a manifest.

The normal save is `~/Library/Application Support/Godot/app_userdata/Spice Bandits Remastered/profile.json`. QA and verification files use distinct subdirectories. Saves retain a verified backup and preserve an unreadable primary as a separate damaged copy. A newer schema is read-only to protect it.

The export is ad hoc signed for local use. It has not been notarized or tested on Intel hardware. Distribution signing needs the user's Developer ID; no credentials are stored here.
