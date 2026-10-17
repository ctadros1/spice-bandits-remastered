# Spice Bandits current handoff — October 17, 2026

Work in `/Users/christian/Projects/Spice Bandits - Remastered`. Read this first, then PLAN.md, README.md, the applicable instructions and original/research/fidelity notes. Preserve the working tree, original files, failed candidates and normal/earned saves. The persistent full offline goal is active and incomplete.

## Current source and package

R170 is a source-only native improvement: empty retained creep roots with nonpositive emission counts skip unused child callback binding while executing exactly the same clock/delay/disable/Emit/release/pool/alias update. Active parents still bind callbacks when their own rate is zero because their children may emit. The old eager path remains selectable. No particle arithmetic changed.

The independently repeated immutable R169 baseline has 2,560 complete state/callback rows. The final R170 test passes 41,301 checks, including pooled parent/child aliases with zero and negative counts, 3,204 pool reuses and 5,296 observed child births under a zero-rate parent. Ten unchanged targeted suites pass: R151 owner migration 7,003; R146 complete key/state 26,462; original owned particles 49,931; live owned rendering 2,445; retained lifecycle 116,841; constructor/birth/owner 144,989; Disco actor 43,471; Disco admission 77,446; allocation/defaults 184; all 82 runtime scripts. All 4,035 originals and four protected saves are unchanged. Tests completed sequentially/headless; no game remains. The new preservation gate is in tools/build_macos.sh.

Controlled ABBA owner timing improves by only about 0.5–0.9 microseconds per call. This does not close the live performance gap, so no new app was exported. The additional R171 owner key/default-allocation experiment was removed after noisy and small measurements; exact source patch, helper, raw results and failures are preserved. See docs/experiments/R170_PARTICLE_CALLBACKS.md and r170-particle-child-binding.json. Raw local records remain under builds/child-binding-r170-* and builds/owner-lookups-r171-*. The initial pool-reuse and later explosion-at-spawn test setup failures are retained; neither required changing runtime behavior or original fixtures.

The packaged app remains the exact frozen R169 correction, while game/native/bin/libspice_hotpaths.dylib is the later R170 source-build helper. Do not claim the installed app contains R170. R169 full source/build, 549 presentation checks/216 PNG, 15 exact RGBA pairs, 12 geometry comparisons and eight separate functional suites pass. The unchanged 33.34 ms median performance limit fails at 35.063 / 40.250 / 45.593 ms (p95 38.896 / 46.676 / 49.920), world 6.028 / 14.227, zero stalls. All four save/package/signature/isolation/cleanup guards pass. Do not rerun unchanged R169 or overwrite accepted R137 comparisons to hide that failure.

Exact R169 package and full 648-file candidate source are under builds/creep-health-offset-r169-candidate. PCK SHA-256 `63168eaf13e00399ccad857566e06a53f8c465f478c1ff2306702ce36880e2a0`; executable `e35ed21d5fb496a5e3e48c7e577854e25160433b3a0254a7c7f24409f929df80`; packaged helper `38d5de442678ec43062e347dad669535e886be5123b484c82ce7e3de5ac3aeb6`. First obsolete-QA-check failure is separately frozen with its exact app/gallery/full source. Original health evidence and all visual review are complete for this bounded change: 210/216 PNG equal R165; two corrected health images and four randomized transitions reviewed full resolution; all six health captures equal the first correct-runtime R169 app.

## Verified private recovery and signing

R169 recovery is complete in private draft 415633968:
https://github.com/ctadros1/spice-bandits-remastered/releases/tag/untagged-a87f6d5e106b41ac26d1

Six assets total 1,570,724,569 bytes. The actual downloaded 1,567,151,882-byte archive has SHA-256 `6634565d4c08cec4529c1275b4e24472746376cd6777e403a22e517c70427dfc`, verifies 2,311 members, restores 648 candidate plus 648 current-source files byte/executable-mode exact with pinned signatures, and launches the actual restored app in isolated native QA from an empty external working directory. Every remote asset SHA/size, strict app signature and all four save guards pass. Audit: docs/backups/2026-10-17-r169-health-anchor-failure.json. R165 and R162 recoveries remain separately verified. R137 is the last published all-ten historical app, not complete original fidelity.

R169 implementation 480694f7f03ad1df79bf4bd08a354f010b600623 and latest recovery publication 99755824c3c67d7b5780198eb93abe9245b29f97 are signed and confirmed on private main. Normal 1Password signing works. User explicitly directs: future signing failures must not stop development; continue and commit when normal signing works, without repeated questions, unsigned bypasses or key/settings resets. Local Good signature is separate from GitHub's badge. Allowed signers: builds/github-backup-2026-10-15/snapshot-02/allowed-signers; fingerprint SHA256:PJZf/txTjoXik5mogVE/7PMFZ9uGF+O8ELR2pEM9PxI. Private repo: https://github.com/ctadros1/spice-bandits-remastered. Source push can use the configured gh credential helper over HTTPS. Bound signer attempts to 60 seconds and preserve failures.

## Next actions

1. Finish signed source/evidence recovery for the source-only R170 checkpoint; the existing R169 app backup remains authoritative. Preserve the rejected R171 lookup experiment and raw test failures. No large duplicate app backup is needed for an unchanged package.
2. Implement actual original hover motion from R164/R166/R167/R168 evidence. It continues during Freeze even when walking/animation stop. Actor hover offsets are unscaled, added before separately scaled frame offsets; health bars use raw animator position. Do not add hover to the shared raw health anchor. Full Fly/portal/growth/status joins and original sound ownership remain open.
3. Resolve the original constructor working-smoke interval separately: current live construction copies the base interval, but original raw+0x2e8 is distinct (for example 0.05). The immutable R151 baseline includes the older value and must not be silently changed or weakened. Record explicit correction scope.
4. Continue every open PLAN.md requirement for UI, interactions, animation, sound, campaign and progression. Full tests do not prove original identity or full completion. No multiplayer or expansion before offline acceptance; no stretched assets.

## Full authorized objective

Fully recreate the original Spice Bandits offline game for macOS in Godot, using the preserved 1.14 assets and recovered code with the supplied iPad recording as the main visual and interaction guide. Preserve original asset proportions on the fixed 4:3 canvas, original files and existing saves. Complete and verify gameplay, UI, animation, sound, campaign and progression before multiplayer or expansion. Record unresolved evidence gaps honestly in PLAN.md. Continue autonomously without routine milestone approval. Maintain the authorized private GitHub repository spice-bandits-remastered as a verified backup and edit history.

The iPad recording looks stretched; use it as a guide without stretching assets. Other AI agents share the main pointer: prefer isolated/headless or app-scoped tests. No subagents have been used. Earlier Bad Request cause remains unidentified; do not reset app/history/settings to guess at a cause.

## Protected saves and execution

Under `~/Library/Application Support/Godot/app_userdata/Spice Bandits Remastered/`:

| File | SHA-256 |
| --- | --- |
| profile.json | 9529b9a6adff84f71fe1ec02a0dc1438fb4c9119408e4ebcbe006fbd5daeb9f3 |
| profile.json.bak | 56312e4722ba92d158a2d3e19b23ed8ec122d414ab3778d00385345686bb94fd |
| verification/fresh-campaign-profile.json | c782a6802e2aec82f79edd0b36a4f0bac703038e1aa352e6f599844b480cc4bd |
| verification/fresh-campaign-profile.json.bak | ec7513e50cae9b6c2d40dd4d6751151b0408a9ecf8082e21c57f455b2392e6bb |

Never reset, seed or replay earned profiles. QA uses isolated fresh profiles. Every actual Godot/game run MUST include `-- --qa`, except editor import/version/export commands. Pinned Godot: work/toolchain/Godot.app/Contents/MacOS/Godot 4.7.2. Preflight tools/run_packaged_qa.py app_processes(); never overlap engines or mutate runtime/package during a batch. Inspect exit codes and SCRIPT ERROR / ERROR / leaked instances even on exit zero. Keep commands bounded and reap completed sessions.

Full build: `zsh tools/build_macos.sh > builds/<unique>-build.log 2>&1`. Packaged suites: `python3 tools/run_packaged_suites.py --label <unique> > builds/<unique>-native-batch.log 2>&1`. A performance failure stops the batch; any eight later functional suites must be reported separately. PIL Python: /Users/christian/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3.

Read original/README.md, research/SOURCES.md, research/GAMEPLAY_FINDINGS.md, research/EXECUTABLE_AND_ASSET_ASSESSMENT.md and docs/FIDELITY.md. Original executable SHA-256 e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048. Unicorn evidence executes unchanged original bodies with explicit supplied inputs/callback stubs; no complete original game/GPU parity is claimed. Do not repeat failed touchHLE startup or Apple Simulator ARMv7 attempts without new evidence. Canonical project list: work_state_read(list="offline-reconstruction", includeClosed=true); update list and task separately. Earlier handoffs are preserved in docs/history/ and Git history; newest status above supersedes historical running-process notes.
