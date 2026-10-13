# Local video observations

Reference files are retained unchanged in `videos/`; their hashes/dimensions/durations are in `videos/video-manifest.json`. Original game version is unverified in all five clips. Do not equate pre-release Spice Invaders footage with the decrypted1.14 baseline.

| File / time | Visually observed | Use and limit |
| --- | --- | --- |
| TouchGameplay iPad2 HD clip,170s | Tutorial map and tower placement presentation. | Used to infer the first three designated tower cells. Fourth tower and mine positions have separate native-code evidence. |
| TouchGameplay iPad2 HD clip,450s | Desert battle appearance, tower/enemy relative scale and HUD. | Saved reference frame at `builds/reference/desert-450.png`; no equivalent-state parity score yet. |
| googlevideo.mp4,10s | On5 publisher mark. | Identifies a trailer/presentation segment, not an original-game installation. |
| googlevideo.mp4,40s | Animated alien-world narrative. | Possible intro excerpt; complete original streamed movie unverified. |
| googlevideo.mp4,80s | Earth narrative shot with overlaid text. | Same limitation. |
| googlevideo.mp4,110s | Career/avatar screen with promotional '3 single player modes' overlay. | Confirms this supplied file includes promotional footage and cannot simply be used as the original intro. |

The AppSpy/PocketGamer and GoGamers clips are preserved and inventoried, but detailed time annotations for upgrades, selling, wave timers, outcomes and unlocks remain pending. The generic files' near-identical duration does not establish identical bytes; keep their distinct hashes.

Native `IntroSequenceView::playIntroMovie`, `0x7353c`, builds `http://engine.tower.on-5.com/intro.php`. The preserved bundled MOV files are two On5 splash sequences. This is a concrete missing presentation dependency to recover, not permission to replace it with a trailer.
