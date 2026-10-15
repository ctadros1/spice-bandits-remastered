# Local build

Latest fully verified package r110 passes all ten native suites:392 presentation checks/130 PNGs,73 audio checks/23 WAVs, and the unchanged live performance gate. Normal ground lighting, textured enemy health bars and live-owner missile phase routing and placement phase are restored within recovered-code bounds. Offline fidelity remains incomplete.

## R106 XP emission and native audio capture

PCK `beb92a77192e3f41cde9ee750f126acac33d5f563ad82c9a436dc739a50c49c8`, executable `e2f2c2f6a3b36cc8d4a1a0c12aa41318388be9b0f7189e50d0a576c87e709d82`, native helper `94890f77cd5b7e0fd14b12a572e402358af8021f512202ef55f66c5aecc0554c`.

R106 restores XP emitter chronology: an idle zero-count system is created without premature births, particles update at the previous rendered tip, and the actual bar render sets the next release count from float32 X changes. The emitter survives empty quiet gaps for later medal XP. Five original constructor/update/Emit/render-block cases covering710 frames support4,971 source comparisons. Resource fields/bar tips are supplied and rand0/GPU are stubs; complete loader/Open, original global RNG and device pixels remain open. R103's inherited closed result timer and R102's clear-flag aircraft missile pass remain integrated; initial owner-body missile routing is still unresolved.

All ten r106 native suites pass on one frozen package: presentation364/113 PNGs, menus184/55, tutorial88/20, audio73/23 WAVs, projectiles4, turns5, towers1, Desert1 and campaign148. Live1×23.836ms median/26.133ms p95,2×24.723/30.463 and4×31.928/35.525 meet the unchanged33.34ms median gate; world6.611/13.937 passes. All live/input-isolation guards pass with zero stalled frames. Three mesh/direct particle and three old/prepared creep-layer/completed-growth frozen pairs match exact RGBA.351 counted PNGs/23 WAVs retain15 supplemental frozen-comparison PNGs separately. Normal/retained-campaign saves, package resources, strict signature, isolated process and cleanup pass. These are reconstruction checks, not complete offline or original-device acceptance.

The r104 audio exit capture failed with nonzero samples only in its first25ms chunk. R105 instrumentation passed but showed that a requested80ms scene timer waited47.745ms of wall time. R106 retains the intended80ms, measures it with the monotonic clock and asserts it for all23 captures (minimum80.142ms); the silence threshold is unchanged and the exit capture is exact silence. This fixes a demonstrated capture timing flaw without claiming the unlogged r104 cause is retrospectively proven. Original WAV/audits/diagnostics remain retained.

The fresh r106 comparison binds45 paired states/12 inspected sheets to its PCK, executable and helper, with90 hashed full-resolution copies. Six result pairs approximately align8XP/3sp phases using original source presentation timestamps. The first XP frame has no premature cloud; exact first emission/global RNG, earlier-version art/raster, other tutorial input/portrait/camera states and full owner/lighting remain open. All required fidelity checklist items remain open. builds/presentation-comparison-r106-review.json records the review; prior r103/r100 comparisons remain separately frozen.

Evidence: builds/audio-wall-settle-r106-native-suites.json. Universal2 compiled; Apple Silicon execution verified. Intel, notarization/Finder/Gatekeeper, physical input/speaker listening and original-device equivalence remain unverified. Source signing remains pending1Password; the r106 private recovery/package backup is published with all eight remote hashes/sizes verified.


## Retained r103 result lifecycle and package

PCK `830fb5ba094dd42deac2b522f89dd456b46a514c5c10f71d4406d64298d7bdfe`, executable `27fe3a37cf95e443aec9d65c068a6ad62f22b77844e968e3bc394d8d203335e4`, native helper `f179861ff1fc5ce88a9de2b555d424c033459bef2f8f4d23ee2cbb9ce53911ca`.

R103 preserves the original closed result-screen timer across victory. It advances with unscaled active-room time, stops during pause/loading and lets XP begin after the opening fade during a normal-length battle. Six original constructor/closed/open-update cases and24 full room-caller cases support11,038 source comparisons. The complete service/GUI-heavy Open is omitted by the probe; its opening flag is supplied. R102 also restores visible aircraft missiles before all aircraft bodies in manager/per-owner order, supported by192 original owner cases/464 callbacks and421 source checks. Original missile suppression/lifetime, ground double-after and full owner/preview/global effects remain open.

All ten r103 native suites pass on one frozen package: presentation344/113 PNGs, menus184/55, tutorial88/20, audio50/23 WAVs, projectiles4, turns5, towers1, Desert1 and campaign148. Live1×24.544ms median/26.312ms p95,2×25.353/31.112 and4×31.509/34.438 meet the unchanged33.34ms median gate; world6.676/13.749 passes. All live/input-isolation guards pass with zero stalled frames. Three mesh/direct particle and three old/prepared creep-layer/completed-growth frozen pairs match exact RGBA.351 counted PNGs/23 WAVs retain15 supplemental frozen-comparison PNGs separately. Normal/retained-campaign saves, package resources, strict signature, isolation and process cleanup pass. Historical r101 fixture, r102 runner-count and4× performance failures remain retained; this is not original-device equivalence.

The fresh r103 comparison binds45 paired states/12 inspected sheets to its PCK, executable and helper and freezes90 hashed full-resolution frame copies.180 additional unwarped original frames retain actual presentation timestamps around the tutorial result. Six result pairs use approximate phase alignment with matching8XP/3sp amounts and the inherited room timer; precise first emission/RNG and older-version differences remain open. Other tutorial input, camera, stock and portrait ages still differ. Every original fidelity checklist item remains open. builds/presentation-comparison-r103-review.json records the review; the prior r100 comparison remains separately retained.

The preserved source timer and caller evidence is described in [result lifecycle](mechanics/RESULT_LIFECYCLE.md). Native evidence: builds/result-lifecycle-r103-native-suites.json. Universal2 was compiled; native execution is Apple Silicon. Physical input/speaker listening, Intel execution, notarization/Finder/Gatekeeper and original-device fidelity remain unverified. Private signed source history still reaches r98 while1Password is unavailable; r100 and r103 source recovery/package backups are verified; see the private checkpoint records in BACKUP.md.


The latest local r100 package retains separate aircraft bodies, the selected range and creep depth, reuses prepared creep drawing data and passes all ten native suites including live performance. [Validation](VALIDATION.md) binds its package hashes and remaining limits. Source build gates now include110 air-body routing,393 selected-range and3,880 creep-depth comparisons.

The project is pinned to Godot **4.7.2.stable.official.ed1daf0bf**, with the matching macOS export template. The local importer requires Python 3.9+, Pillow 12.3.0, and Apple's `afconvert`. Original inputs remain local beneath `original/`; the importer writes only derived assets, JSON, and its audit.

The measured range/target/movement and particle hot paths build as a Universal2 GDExtension using Xcode Command Line Tools, pinned godot-cpp commit`b8530af7546a3fcae80cef2477526569fd42ffc2` and SCons4.10.1. `tools/build_native.sh` prepares those isolated build dependencies under`work/toolchain` and writes the derived library under`game/native/bin`. The package build calls it before importing/testing/exporting. See [the native helper](../native/README.md) for rounding and reference checks.

Toolchain downloads used:

| Input | SHA-256 |
| --- | --- |
| [Godot 4.7.2 macOS Universal](https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip) | `c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e` |
| [Matching export templates](https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz) | `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` |
| [Ghidra 12.1.4](https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip) | `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db` |
| [Temurin JDK 25.0.4.1, macOS ARM64](https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/OpenJDK25U-jdk_aarch64_mac_hotspot_25.0.4.1_1.tar.gz) | `61979887f7506a24a57439ff99adb8b3a7fc89977d9cfe3b8984f58a981b7b9d` |
| [FFmpeg8.1.3 source](https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz) | `7138d28c96d9d3e3af4ee3d8cad72741f8ffb40da90c1112235dea3ecd3178a3` |

Extract Godot into `work/toolchain/Godot.app`. Install the template's `macos.zip` in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Ghidra/JDK are required only for further binary research; they are not app dependencies. This Ghidra archive lacked the native macOS ARM decompiler, so it was built from its included C++ source with `make ghidra_opt`, ARM64 and macOS 11 flags, then placed in `Ghidra/Features/Decompiler/os/mac_arm_64/decompile`.

The two original publisher MOVs are derived as Theora/Vorbis without resizing or changing their25FPS rate. Godot supports this format through its [built-in video player](https://docs.godotengine.org/en/stable/classes/class_videostreamplayer.html). The source archive's detached signature was verified against the [official FFmpeg key](https://ffmpeg.org/download.html), fingerprint`FCF986EA15E6E293A5644F10B4322F04D67658D8`. The local converter uses FFmpeg8.1.3, Theora1.2.0, Vorbis1.3.7 and Ogg1.3.6, with quality10/8 and deterministic container flags. These are build dependencies only. Run `zsh tools/build_video_converter.sh` with those development libraries available through `pkg-config`; `SPICE_VIDEO_CONVERTER` may specify another FFmpeg8.1.3 build with these encoders. The importer needs it when converting missing or changed movies; it verifies cached runtime hashes before reuse.

Run from the project directory:

```sh
zsh tools/build_macos.sh
open 'builds/Spice Bandits Remastered.app'
```

`SPICE_GODOT` and `SPICE_PYTHON` can point to alternate installations of the same pinned versions. The script verifies preservation, regenerates content, imports the project, runs simulation, tutorial and menu UI checks, exports, and checks the ad hoc signature and executable slices. It does not establish original-game parity or an Intel hardware result.

Independent full image/audio conversion check:

```sh
python3 tools/verify_import.py
```

To develop, open `game/project.godot` in Godot. Generated content and Godot caches are ignored by Git. Keep the original archive with a local clone; source code alone intentionally does not redistribute the original art, account metadata, or videos.

## Local QA captures

The app accepts `-- --qa` to isolate its save from the normal profile. `--mission=8 --qa-demo` creates the documented Desert Freighter fixture with T1L3 technology already owned. It is not a fresh-profile progression result. `--capture=/absolute/image.png --smoke-quit` captures a frame and exits; `--qa-render-all --capture-root=/absolute/directory` captures all 148 authored offline configurations and writes a manifest.

QA normally bypasses startup. `--qa-intro --qa-intro-variant=1` (or2) exercises a chosen publisher movie; F9 replays it only with that QA flag. Normal startup selects either bundled variant. Click, Escape, Space or Enter skips it. The unavailable streamed narrative intro remains a recorded difference.

`--qa-run-tutorial` runs the QA engine-action replay in the packaged app; `--qa-tutorial-capture-root=/absolute/directory` also captures its18 pages and victory. It resets only the in-memory QA fixture, mutes audio, and injects the instructional clock. It is not an OS mouse recording. `python3 tools/run_packaged_qa.py --tutorial`, `--campaign`, `--towers`, `--desert`, `--projectiles`, `--turns`, `--audio`, `--menus`, `--performance`, or `--screen upgrades` runs an isolated native check and records the PCK/executable hashes before launch, fresh capture completeness, unchanged package resources and normal save files, exit/errors and signature verification. The tower fixture renders all54 forms at synthetic positions; it is a presentation audit. Campaign captures hold simulation updates so image export time cannot start unintended waves. The projectile fixture captures bubble growth/flight and nuke ascent/descent/impact, with assertions for the expected effect stages; its technology and targets are synthetic. Run these sequentially and rebuild before repeating after source changes.

`--qa-persist-progress` saves to a separate QA progress profile. `--qa-exit-xp-fixture` creates two pending50-score kills in an isolated verification profile and defers the ordinary save batch; native Command-Q then tests the quit-save path. The tutorial harness enforces QA behavior and an isolated path even when a command omits the QA flag.

Run the bounded passive combat corpus with `work/toolchain/Godot.app/Contents/MacOS/Godot --headless --path game --script "$PWD/tools/campaign_combat_probe.gd" -- --qa`. It records source hashes, event counts and outcomes for all148 schedules; it does not test winning strategies or fresh-profile progression.

The normal save is `~/Library/Application Support/Godot/app_userdata/Spice Bandits Remastered/profile.json`. QA and verification files use distinct subdirectories. Saves retain a verified backup and preserve an unreadable primary as a separate damaged copy. A newer schema is read-only to protect it.

The export is ad hoc signed for local use. It has not been notarized or tested on Intel hardware. Distribution signing needs the user's Developer ID; no credentials are stored here.

The turn gallery captures five aircraft/tank poses with original turn frames. Audio QA records23 stereo WAV stages and mixer/loop/mute checks before the muted app master; it does not use a microphone or change system volume. The QA harness stores normal-save snapshots before launch, requires an explicit isolated runtime context and rejects any normal-save change.

To regenerate the independent ARM corner fixtures, install pinned Unicorn2.1.4 into `work/reference-runtime` and run `tools/native_creep_reference.py --output=tests/fixtures/native-creep-reference.json` with the bundled Python runtime. Read [its scope](mechanics/CREEP_PRESENTATION.md) before treating these bounded function results as original-app evidence.

`--qa-menus` runs purchases/refunds/relaunch, fitting previews/apply/cancel/removal, medals, Africa pass transactions, pause/results and earned promotion tests. `--qa-menu-capture-root=/absolute/directory` writes54 native captures, including isolated promotion fade/failed-acknowledgement and first-rank Career states. Synthetic purchasing funds/outcome screens are explicitly distinguished from campaign play.

All nine generated JSON files reproduce on a second full import; the current hash record is `builds/import-nine-json-reproduction.json`. The importer retains90 particle systems and23 resource bindings. Run `python3 tools/native_particle_reference.py` to regenerate192 bounded ARM particle cases, with documented emission/render stubs.

`--qa-performance --qa-performance-root=/absolute/directory` runs a synthetic dense native scene at1x/2x/4x, with54 authored tower forms and200 initial enemies. Three real-time sampled stages and captures are retained; inflated fixture base health and no profile rewards are explicit. A successful import/build does not establish a frame-rate pass.

Ordinary offline play and the performance fixture use the code-traced live elapsed-time path. Replay/tutorial corpus fixtures retain fixed30ms steps. `--qa-live-runtime` enables live timing in an isolated interactive QA session. `python3 tools/native_room_reference.py` regenerates22 bounded original ARM dispatcher/timer cases; read [their limits](mechanics/UPDATE_TIMING.md).

Long-lived profiles preserve older transaction history in checksum-verified content-addressed snapshots beneath`<profile path>.history/`. Keep that directory with a backed-up profile to retain full history. After1024 ordinary events, compaction retains256 recent events and every promotion. Snapshot heads link prior history; compaction does not change balances, unlocks or progress.


The saved campaign verification reached all54 Normal wins and Madagascar. `builds/fresh-campaign-endpoint.json` retains the full1,970-battle prefix and the immutable final segment hashes. `tools/fresh_campaign_probe.gd` is a verification strategy, not normal app autoplay. Its recipes use actual purchases/charges, wait for earned funds through repeat victories, and stop at the saved endpoint. The simulation horizon is30 minutes to account for Freeze extending survival time. Neither this harness nor temporary pre-owned diagnostics replace the normal profile.

The build gate also runs tools/water_ui_verify.gd and tools/story_ui_verify.gd against preserved ARM fixtures. Native animated water can be inspected with --qa --qa-water; default Training follows the stable appearance in the selected TouchGameplay recording. The presentation suite captures those forced water states, the814 rendering fixture and story-glow ages separately. These diagnostic flags do not enable multiplayer.


The build also gates native wave-strip/count geometry, magic inventory flags/easing, tutorial GL fade order and mode-item opening/closing geometry. Regenerate the bounded references with python3 tools/native_wave_reference.py, tools/native_wave_indicator_reference.py, tools/native_magic_panel_reference.py, tools/native_tutorial_fade_reference.py and tools/native_mode_item_reference.py. Each retains the executable hash and explicit stub/early-stop scope. Presentation QA now requires49 fresh captures, including magic opening/refill/closing, tutorial half-fade, wave stages and separate fan move/text/closing stages. Native mouse verification must launch with --qa before attaching CUA; a locked Mac prevents physical input even when native viewport fixtures render successfully.

Additional bounded source gates cover reward clocks/medal geometry and particle clock, inactive tower previews/facing and early-wave collapse. Current menu QA includes original offline Spice Shop and an explicitly posed catalog, with all external actions disabled and no invented regional prices. See the current package audit for capture/check counts.


Menu QA now requires29 captures, including original offline/catalog Spice Shop poses and forward/back/Map/Home content transitions. Native tab audio and silent same-tab selection bring the mixer fixture to23 stages/50 checks. The build gates56 original menu-dispatch cases/504 comparisons with tools/menu_navigation_ui_verify.gd; regenerate its bounded original fixture with tools/native_menu_navigation_reference.py. UIKit layer rendering/default easing are outside that probe.


The build gates60 original portrait animation-request/block cases and484 lifecycle/touch/routing comparisons with tools/portrait_ui_verify.gd. Regenerate the bounded original requests with tools/native_portrait_fade_reference.py. UIKit raster/pacing and interrupted animation delivery are outside the probes. Menu captures pose500ms of the independent view clock; the tutorial driver waits through real simulated frame updates.

The portrait gate also reads132 original touch and32 afterClose cases, regenerated with tools/native_portrait_touch_reference.py and tools/native_portrait_close_reference.py. tools/tutorial_arrow_ui_verify.gd gates96 tablet arrow/layout checks against64 original device/orientation/presence cases from tools/native_tutorial_arrow_reference.py. The packaged runner records PID/arguments, rejects other engine/game instances and retains before/after normal-save bytes/hashes. A failed or concurrent save audit must remain failed; do not restore normal saves to make it pass.

The build now gates tools/build_hex_ui_verify.gd:7,716 hex/range-oval geometry and color checks, using tools/native_build_hex_reference.py and tools/native_preview_oval_reference.py. Source oracle submissions do not prove Godot rasterization. Interactive test time limits must include human/tool-paced instruction reading and observation; preserve timeout failures and never reattach CUA to a closed app before an explicit QA launch.


Native input reward verification (r38): --qa-input-rewards creates a new user://verification/native-input/<pid>-<startup-tick>/profile.json before the profile loads and enables the ordinary reward transactions in that account. It does not use or reset qa-progress or the earned campaign profile. Six neutral startup/write/reload/normal-path-guard checks pass. This flag is diagnostic only; default QA galleries continue to skip reward writes. --qa-state-file now records the actual profile path, credit mode, kills/score, magic stock, mine cells, active effects, base HP and result clock to bind native input observations. The original data/combat/reward rules are unchanged. Native earned-reward input is in progress; no new completion claim follows.

R38 physical earned-account test reached19 kills and7.500001430511475 saved XP with no normal/campaign save changes. It exposed the paused mine-transition loss and did not finish. R39 freezes the tutorial page/fade while paused, retaining the pending launch until resume; source68 and packaged88 tutorial checks pass. Native r39 repeat completed; its detailed input record is below. Native verification can be launched with tools/run_native_input_qa.py; it always uses a new isolated reward account, records input-state changes and protects normal/campaign saves and package resources. Do not read a closed CUA app after Command-Q: that observation can reopen the app without QA. Verify exit via process inventory.

Native r39/PCKa3c2793d completed the tutorial through CUA mouse/keyboard input: four tray drags, three upgrades, confirmed sale, Disco, Active Defense, mine at7,6, Space pause/resume, victory, To the map, guidance dismissal and the unlocked Desert Normal fan. During pause the actual saved state retains page17 pending/display16/wave2/spawn hold; resuming launches wave3 once. Victory has20 kills,$181,81 score and100% base health; the separate checksum-valid save retains8.100001335144043 XP,3 spice,tut and completed1 with no normal tutorial career-stat increment. Native screenshots and runtime observations agree. Command-Q exits0, signature/isolated paths/only-QA process and all normal/campaign/package protected hashes pass. builds/tutorial-native-input-r39/input-observations.json records the exact scope; loading is skipped under this QA flag, and trackpad/Intel/audio listening/original pixels remain unverified.

R41/PCKe68db9451eed420b0971015ebedfb962a776263e5fe3f9a3f6fc0e12ba308027 restores eight original animated world-map objects.504 original CAnimatedObject::Render/CKeyFrameAnimator::Update frames pass3,528 source comparisons with quad rendering stubbed; the XML paths/textures/loop/ease/speeds are preserved, and two native scenery captures were inspected. Five fresh native suites pass141 presentation/57 PNGs,88 tutorial/20,114 menus/29,50 audio/23 WAVs and3 performance captures. The older r39 all-ten suite and completed earned native tutorial remain separately bound. R40 and the first r41 presentation audit missed an owned relative-path failed source process; they are explicitly retained as failed inventory audits. It was terminated, the relative path is covered, and r41 repeats verify the sole QA process and unchanged normal saves. Portal preview follows delivered pointer events and has no invented exit-status banner. World clouds, windmill resource initialization, original framebuffer and other named fidelity differences remain open.


The r45 build additionally gates tools/world_cloud_ui_verify.gd (1,314 bounded original arithmetic/ordering checks) and tools/xp_ui_verify.gd (216 original footer comparisons plus ten local libc-format regressions). Regenerate with tools/native_world_cloud_reference.py and tools/native_xp_footer_reference.py. Presentation now requires65 captures and performance four stages, including the full world map. tools/run_native_input_qa.py --name=<new-name> --loading launches an independent earned-reward QA account with original scene transitions enabled; use native CUA input, and verify quit by process inventory without observing the closed app. See [current exact package validation](VALIDATION.md).


Current r47 adds world_camera_ui_verify.gd (1,176 comparisons) and message_ui_verify.gd (504 comparisons), regenerated by native_world_camera_reference.py and native_message_reference.py. Presentation requires66 native captures; menus31; performance retains four stages including an explicit diagnostic0.2 world zoom. run_native_input_qa.py --scope=interface --mission=8 requires ordered pause/resume and a bounded0.25 world state; tutorial scope still requires actual victory and return. Neither scope grants resources. The currently verified full earned tutorial/loading belongs to r45; the focused current dialog/camera input belongs to r47.

The build also gates original Upgrades Yard layout/selection scrolling (284 comparisons) and main-menu animation declarations/selection plus local interpolation/anchor regressions (530). See [Upgrades Yard](mechanics/UPGRADES.md) and [main menu animation](mechanics/MAIN_MENU_ANIMATION.md). The native menu audit requires 41 captures and at least four distinct hashes among five explicitly timed main-menu poses; an actual viewport click checks that a selected description receives input ahead of covered tiles. Neither assertion establishes original-device pixel equality.


The r54 build adds source gates `menu_float_ui_verify.gd` (820 comparisons) and `menu_motion_ui_verify.gd` (1,334), alongside `menu_bubble_ui_verify.gd` (865). Their fixtures come from bounded original ARM methods with explicit framework/RNG stubs. `menu_layout.json` now retains original image alpha and tags, including nine initially transparent lamp views. The native menu gallery has47 PNGs; the audit requires eleven menu poses and at least ten distinct hashes. It also checks actual viewport activation of the rocking Play control. The source menu gate has112 checks. Do not reuse the earlier41-image count for this package.

All ten r54 native suites pass the hashes in VALIDATION.md. `builds/menu-upgrades-native-input-r54/` separately records actual mouse/keyboard verification. Its QA title request was not reflected in the AX title: checking the live owned process/arguments and isolated runtime immediately before CUA binding remains essential. After Command-Q, observe only process/harness results; never rebind/observe the closed app through accessibility.

The macOS build also runs `tools/render_mode_text.swift` with the system Swift/CoreText/CoreGraphics frameworks. It derives seven English mode-title shadow textures from the preserved Kautiva Pro Bold font. The metadata records the rendering OS, content scale, dimensions and shadow parameters. It is a build dependency only; the app uses packaged textures. Current macOS font raster is not proof of old UIKit pixel equivalence.


Electrical source gates now also include bolt_construct_ui_verify.gd (1,040 original point/vector comparisons), bolt_appearance_ui_verify.gd (195 caller/ball/UV/resource checks) and bolt_clock_ui_verify.gd (2,107 original clock/anchor comparisons). The probes record framework, allocation, sound, renderer and supplied-state stubs. The native presentation gallery currently requires81 frames, including source-ball fading, area re-entry, drawn aim and all five custom beam colors. Its current package/count/hash and physical-input scope are in [VALIDATION.md](VALIDATION.md). Inspect the pixels: the preserved r66 white-strip defect passed its automatic assertions and was rejected visually.

Promotion source checks use tools/native_promotion_reference.py and tools/promotion_ui_verify.gd. The build runs the9,661 original clock/render/control comparisons before export; native menu captures remain a separate rendered check. See docs/mechanics/PROMOTION.md for explicit stubs and missing service mappings.

The r84 build also runs `bolt_order_ui_verify.gd` (51 original Render/owner-call checks) and `bolt_ribbon_ui_verify.gd` (13,004 original-fixture/script-native checks). Current presentation has83 PNGs and282 checks; menus55/184. Run the complete isolated native set with `python3 tools/run_packaged_suites.py --label <fresh-label>`, keeping package/source fixed until it exits. The batch records normal and retained-campaign hashes even on failure. A fresh label prevents overwriting its batch/log evidence. All ten suites passing does not establish original visual acceptance.

The r86 broad-bolt atlas uses the root canvas stretch to match actual readback pixels. Root texture size metadata is unsuitable here; native wide/tall/restored captures exercise this. The full frozen-package verification can be repeated with `python3 tools/run_packaged_suites.py --label <fresh-label>`. R86 passes all ten suites (295 presentation checks/86 PNGs); original owner-depth, old text raster, global RNG and positional audio remain open. See [particle evidence](mechanics/PARTICLES.md).

The r89 build adds651 tower-depth checks. Full packaged verification passes all ten suites on PCK87fc196a, with300 presentation checks/88 PNGs. Native-input retry is explicitly partial; read [tower presentation](mechanics/TOWER_PRESENTATION.md) and [validation](VALIDATION.md) before interpreting its scope.

## Asset and map inspector

Run `python3 tools/inspect_assets.py`, then open `http://127.0.0.1:8765/`. This separate development tool serves derived assets/data only on loopback; it does not ship in the game. Atlas controls show imported crops, quarter turns, flips, trim offsets, untrimmed bounds and extra images, including shadows and pads. Map controls show all67 maps, foreground bounds/current depth, authored hex flags and selected offline base/source configuration. Click a hex for its flags and center. Save buttons export the current preview/overlay as PNG.

R90 actual browser verification covers108 resources/67 map choices, rotated Minigun frames, flipped creep animation, extra-image natural-size fallback, Training cell8,6 and Desert object5/current depth483. Two PNG exports were inspected in `builds/asset-inspector-r90/`; the audit is `builds/asset-inspector-r90.json`. Foreground order follows the current reconstruction. Water animation, original map registration/ties, GPU pixels and gameplay are outside this inspector. The package remains r89.

The current r93 source gate passes2,063 depth checks, including all20 bases/54 towers. Presentation QA requires91 captures/305 checks. Performance QA alone disables external input/GUI handling and requires a progressing simulation in every sampled stage; interactive QA and normal input are unchanged. The r93 live4x median still fails; nine other suites pass. Read docs/VALIDATION.md before relying on older timing results: r89's retained Paused frame invalidates its live stress interpretation.

R94 uses direct particle triangles with mesh-equivalent color conversion. Source tools/particle_draw_verify.gd requires native OpenGL and --qa (100 checks/40 PNGs at the attested capture); tools/particle_draw_benchmark.gd is a fixed renderer-only A/B/B/A diagnostic, not a live FPS gate. The packaged stress fixture requires exact frozen mesh/direct RGBA and independent live-clock/input guards. Nine r94 suites pass; live2x/4x performance remains failed. Current comparison-sheet generation correctly refuses that failed audit, so the older sheets are not claimed current.
