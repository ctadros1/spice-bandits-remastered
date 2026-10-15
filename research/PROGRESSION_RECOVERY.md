# Progression recovery follow-up

October15,2026. The user confirms that the preserved IPA is the available original installation material; no additional running installation or old save is available. Continue reverse engineering and documentation research without treating this absence as a routine approval checkpoint.

## New observation from the supplied recording

The main iPad guide at670.5s (world) and691.5s (Career) shows level2, `31 / 55` XP,8 spice,3 upgrade points and2nd Lieutenant. Both unwarped full-resolution captures were inspected. `tests/fixtures/observed-progression.json` binds their timestamps and SHA-256 hashes. The exact earlier game version and unrounded account XP remain unknown.

Original `MenuBottomView::updateUserInfo0x512a8` formats current total xppoints against xppoints+tonextlevel. These two settled displays support55 total XP as the next threshold at level2. They do not establish a complete curve or exclude a fractional server threshold hidden by display rounding.55 is the matching whole-XP reference selection, not a recovered later1.14 server response. The previous local40 estimate is therefore replaced by55 under the selected main-recording policy. Level1's10 threshold remains bundled1.14 evidence; later thresholds remain explicitly provisional. No new complete curve is fitted from two points.

The first promotion frame also shows Freeze stock5. Its cause is not established: the later1.14 initial offline snapshot has no owned magic stock, and `CLevelUpNewItem` reads stock from user data. Do not silently turn that pictured quantity into a newly invented recurring or first-promotion grant.

## Decrypted client trace

The original executable SHA-256 remains `e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`. The bundled offline snapshot supplies only initial level1/xppoints0/tonextlevel10/levelpoints0/rank cadet/rank_short cdt. It includes shop locks and rewards but no later rank/XP table.

- `TDPlayer::addXP0x40a44` increments float32 xppoints/xp_delta, subtracts from tonextlevel and posts money; it does not supply the following threshold.
- `modAddXP:spice:puPoints:0x42e70` posts the addPoints module. Offline `TDServer::modAddPoints0x469f4` returns updated currency/points, without a later level/rank formula.
- `TDEventProxy::handleLevelUpWithData0x3f568` reads the already-updated level and accumulates supplied spice/up_points/newItems into the pending notice. This is a received promotion payload, not a table of its values.
- `O5Player::processResponse0x4c84` merges received user-data keys and dispatches received events. `TDPlayer::processResponse0x410ac` adds game-specific handling. `TDSession::logInWithId0x60d98` allocates the player; it contains no curve.
- `rank_short` feeds Career and promotion image selection. Multiple rank PNGs exist; their existence does not specify the levels at which they apply.

`tools/ProgressionReferences.java` inventories bounded static string/CFString/literal references in the Ghidra project. This is a discovery aid; indirect class/selector data may add candidates, and the inventory does not prove that all dynamic uses are covered. Read the actual function before treating a candidate as field-specific arithmetic. Logs retain the missing-Java-runtime attempt and the corrected invocation using the already-preserved toolchain. No original bytes were edited. The refined r77 pass restricts entry points to CString keys and small literal/CFString records, excluding selector strings and broad class records. It records six keys/27 candidate function uses in builds/progression-references-narrow-r77.log. This removes the first pass's unrelated class-method candidates. The original getters, point mutator, login allocator and response/event handlers were reviewed; no complete later curve was recovered.

## Surviving documentation reviewed

The current search covered exact game/rank/XP phrases, older Spice Invaders naming, Arqade, reviews and the4PDA discussion. No complete XP/rank table was found in this bounded pass.

[Arqade's six-question tag index](https://gaming.stackexchange.com/questions/tagged/spice-bandits) leads to player reports on XP tactics and unlocks, rather than a threshold table. The [firsthand XP discussion](https://gaming.stackexchange.com/questions/53218/how-can-i-maximize-xp-gain-in-spice-bandits) distinguishes stars, proximity and repeat-play strategies; it does not supply rank transitions. These remain scenario leads rather than numerical rules.

The [2012 TouchArcade review](https://toucharcade.com/2012/02/06/spice-invaders-review/) describes the first continent gate at level20/42 spice, whereas the preserved1.14 data supplies a level16 free pass. That conflict reinforces the need to label versions instead of replacing recovered1.14 gates from an older review. The [preserved store description](https://gamefaqs.gamespot.com/iphone/660856-spice-bandits) states that offline experience/spice becomes available after server reconnection, consistent with a hosted progression dependency. Neither source supplies the missing curve.

The [4PDA thread](https://4pda.to/forum/index.php?showtopic=306041) is indexed with firsthand2012 play discussion, but a direct fetch failed in this pass. The Japanese review fetch also timed out. The web reader could not load the two Wayback indexes; direct read-only CDX requests subsequently returned HTTP200 with empty arrays for the exact game engine and tdoffline paths. Those bounded index queries are retained in builds/progression-archive-recovery-r77.json and do not prove that no other archive exists. Do not treat unavailable pages as inspected evidence or infer table values from search snippets.

## Implementation and preservation scope

New promotion journal rows record threshold and threshold_source separately from reward rule. Existing normal and earned campaign profiles are not recalculated, downgraded or replaced. The retained1,970-battle earned campaign used the earlier recorded threshold policy; it is historical campaign proof, not a new fresh campaign under the corrected55 threshold. Five focused checks cover the old40 regression, fractional XP below55, the55 boundary and once-only promotion. Later rewards remain the explicit local fallback.

Fresh r77 packaged verification passes all ten suites on PCK06d01c42b0ec0b8695a4a14a3fcca999fc06d6b2d5026a189b34de3f621abf90: menus184/55, presentation236/81, tutorial88/20, audio50/23 WAVs and the six remaining galleries. Native31/55 footer was inspected at full resolution. All protected saves and package resources remain unchanged; no game processes remain. R76 first passed menus but failed one presentation assertion that still expected the superseded40 denominator; its pixels/audit remain in builds/progression-stale-footer-expectation-r76/. R77 fixes that stale expectation and rebuilds/repeats the full suite. The separate native reference-only footer pose temporarily displays31/55 with the observed currency/points, restores its actual isolated10XP/5-spice notice account, and never saves the posed values. It must not be described as earned campaign play.


## Original execution and Simulator feasibility, October15

The user asked whether running the supplied IPA in an older iOS Simulator would provide primary progression evidence. Running the original successfully would help with screen geometry, animation timing, touch interactions and the client's actual offline behavior, subject to service availability. It has not been run as a whole app in this project.

The preserved1.14 Tower executable is Mach-O ARMv7, with cryptid0 in the existing executable audit. Info.plist declares MinimumOSVersion4.3, DTPlatformNameiphoneos, SDKiphoneos6.0, device families1/2 and the opengles-2 capability. This is a device build, not an Xcode Simulator build. Apple's [Simulator guide](https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/simulator_help_topics/Chapter/Chapter.html) requires an app built for Simulator; selecting an older runtime does not translate this ARMv7 device executable. [Apple QA1971](https://developer.apple.com/library/archive/qa/qa1971/_index.html) confirms that iOS11 cannot launch32-bit apps. A compatible physical device with a suitable iOS4.3–10 runtime is therefore a more promising execution route, but installation/signing and game behavior on any specific device remain untested. No additional device is available from the user.

A bounded legacy-emulator check reviewed the official [touchHLE README](https://github.com/touchHLE/touchHLE), [FAQ](https://touchhle.org/faq.html) and [compatibility database](https://appdb.touchhle.org/). Their current declared scope reaches iOS4.0.x, below this app's4.3 minimum; the database contains no Spice Bandits/Spice Invaders entry in this pass. This establishes no tested compatible full-app emulator. It does not prove that this binary could never run with further emulator work. No emulator or obsolete Xcode was installed, and no original IPA bytes were patched.

Even successful execution would not recreate missing hosted responses. The client/server trace above distinguishes observed local XP accumulation from later thresholds/ranks/reward payloads received from the service. Invented replacement responses must not be treated as recovered progression data. Existing selective ARM execution is primary evidence for bounded client functions with explicit stubs; it is not a working original installation or an observation of its missing server. Continue the offline implementation while retaining this unresolved recovery route.


## Controlled full-app emulator attempt, r89

The later r89 attempt goes beyond the compatibility-database check above. The official touchHLEv0.3.0 macOSx64 release archive was downloaded from [its release](https://github.com/touchHLE/touchHLE/releases/tag/v0.3.0),18,646,119bytes/SHA-25624cabca7a0640bef749ec459d650614563c88002b94ea89439978ba2239fa9fc, matching the official GitHub asset digest. The read-only DMG was mounted under work/toolchain, and the existing Rosetta installation executes the tool. Its --help initialization creates the emulator's own Application Support directory/options files; no existing Spice Bandits saves are used. The DMG is detached after the attempt.

A separate APFS copy of the unchanged1.14 Tower.app was launched with --device-family=ipad --no-error-popup and a30-second watchdog. Network access remains denied by default; no --allow-network-access was passed and both app-specific options lookups report no options. There are no fabricated server responses or patched game instructions. touchHLE warns that the4.3 requirement and declared OpenGL ES2 capability exceed its supported4.0/ES1.1 scope, then starts executing the client. It exits101 during startup because its UIWindow class does not implement setRootViewController:. The trace retains original LR0x32a1f; no menu, battle or progression was reached. This is an actual compatibility failure in this emulator release, not proof that the IPA is corrupt or could never be emulated.

Exact arguments/process/hash/exit evidence is in builds/touchhle-original-launch-r89.json and its adjacent log. Both original and copied executables retain SHA-256e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048. Tool provenance remains work/toolchain/touchHLE-v0.3.0/provenance.json. A successful future emulator port would still need validation against supplied videos and would not restore absent hosted progression data by itself. Continue bounded client probes and reconstruction without describing this startup attempt as original gameplay evidence.
