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

## Reviewed sampled frames

October13 inspection produced145 time-stamped frames and contact sheets under`builds/reference/annotations/`, with source filenames and exact sampled times in its manifest. These are observations at a sampled frame, not exact event-transition times or a numerical replay comparison. TouchGameplay is branded Spice Invaders; its title identifies an iPad2 recording but the encoded picture is1920×1080 and the source display/capture scaling is unverified. The other clips film a physical phone, include hands and use montage edits. All game versions remain unverified.

| Clip / exact sampled second | Observed state | Reconstruction use |
| --- | --- | --- |
| TouchGameplay100 | World map, initial profile strip and tutorial invitation. | Original top tab and bottom profile hierarchy. |
| TouchGameplay110 | Loading screen with planet/ship and tutorial destination. | Loading presentation target. |
| TouchGameplay120 | Tutorial welcome bubble and commander at lower right. | Main prompt placement differs from the current fixed upper-left panel. |
| TouchGameplay130 | Separate source and base labels with pointing lines. | Split page1 labels; do not combine them into the main instruction bubble. |
| TouchGameplay140 | Four designated build hexes and a pointer to the minigun control. | Placement arrows/markers and commander on the left for this page. |
| TouchGameplay150/160 | Three then four placed towers; wallet falls200→140→120. | Four original20-cost builds and the first enemy introduction. |
| TouchGameplay170/180 | First fighting waves, trails, muzzle flashes and ground death marks; reward instruction at180. | Combat presentation and tutorial money explanation. |
| TouchGameplay190 | Selected tower's top sell/upgrade buttons, range ellipse and separate upgrade pointer. | Tower panel and tutorial pointer geometry. |
| TouchGameplay200 | Unused fourth tower selected; sale instruction and sell button. | Sale flow and placement of its prompt. |
| TouchGameplay210/220 | Disco instruction, then confused enemies and ability particles. | The instructional delay and scattered enemy paths are visible. |
| TouchGameplay230/240 | Active Defense instruction, then simultaneous electricity from fighting towers. | Ability presentation and its separate pointer bubble. |
| TouchGameplay250/260 | Mine instruction, designated mine hex, then a placed mine. | Original mine prompt, pointer and active-placement gate. |
| TouchGameplay270 | Tank enters the tutorial; mine/tower fight continues. | Final tutorial enemy family. |
| TouchGameplay280 | Tutorial victory overlay with Replay/To the map controls and a separate final commander prompt. | The current simple results layout needs original framing. |
| TouchGameplay300 | World map after tutorial;3sp visible and first-mission invitation. | First-win reward and post-tutorial guidance. |
| TouchGameplay310/320 | Desert Freighter story image and narrative text. | Preserved local story asset is shown in the original flow. |
| TouchGameplay340/350 | Desert placement, source/base labels; then three gun towers. | Early battle composition. |
| TouchGameplay410/450 | Placement grid and additional towers; approaching Marines/aircraft. | Mixed early/later waves and map scale. |
| TouchGameplay540/610 | Tower selection, upgrade controls and branch preview. | Upgrade panel hierarchy. |
| TouchGameplay620 | Desert victory,23XP gained,3sp reward and accumulated battle statistics. | Comparison target; no equivalent input replay has been established. |
| TouchGameplay640 | First promotion overlay: level2,+5sp,+3 upgrade points and newly available magic/shop items. | Evidence that the current provisional1-point local promotion differs from this earlier release. Server-derived1.14 rewards remain unresolved. |
| TouchGameplay650/660 | Tech Shop instructions, missile unlock, wallet11sp→8sp. | A3sp missile technology purchase is observable. |
| TouchGameplay670/680 | World map shows subsequent location access. | Post-purchase progression display. |
| TouchGameplay690/700/710 | Career and fitting room body/hats tabs;8sp and3 upgrade points remain visible. | Avatar/career/fitting-room composition. |
| TouchGameplay730/740 | Upgrades Yard grid and Spice Shop with paid/free service offers. | Original arrangement; unavailable services remain explicit offline adaptations. |
| AppSpy10/15 | Tower placement grid, minigun combat and HUD; physical finger obscures part of the scene. | Phone layout reference. |
| AppSpy30/35/55 | Top tower sell/upgrade controls and F/S/W selection while gameplay continues. | Existing tower-panel layout needs improvement. |
| AppSpy40/60/70 |2× then4× indicators, accelerated combat and wave-counter progression. | Observable original speed controls; elapsed montage time cannot establish firing cadence. |
| AppSpy80/90/95 | Wooden Walls placement/routing scenario. | Original fence/map art and practical battle fixture. |
| GoGamers5/10 | World map navigation and profile level48. | Mature campaign interface; not a fresh-profile starting state. |
| GoGamers20/25/30 | Camps lobby with multiple players/friends. | Multiplayer reference retained for Phase6, not an offline feature claim. |
| GoGamers35/40/45 | Tower placement in The Cave. | Map/control alignment reference. |
| GoGamers75/90 | Selected gun/Tesla and upgrade-branch controls. | Original panel family differences. |
| GoGamers120/125/130 | Dense electric/chemical combat and explosion smoke. | Particle/mixing/depth target. |
| GoGamers140/150/160 | Tesla placement/selection, then a Baby Nuke selected during air combat. | Nuke and electric tower presentation. |
| GoGamers180/185/190 | Dense air combat, then a bright full-screen explosion. | Nuke blast/white flash target; cannot derive exact flight timing from these5-second samples. |

No defeat overlay appears in the reviewed sampled clips. Do not fabricate a loss timestamp; locate another reference or inspect unsampled transitions. The generic files' near-identical duration does not establish identical bytes; keep their distinct hashes.

Native `IntroSequenceView::playIntroMovie`, `0x7353c`, builds `http://engine.tower.on-5.com/intro.php`. The preserved bundled MOV files are two On5 splash sequences. This is a concrete missing presentation dependency to recover, not permission to replace it with a trailer.

## Dense review after user feedback

All five supplied clips now have full-resolution1FPS captures,1,365 frames in total. Six main iPad sequences add1,995 frames at15FPS. There are62 contact sheets; each full clip's complete timeline has been reviewed, along with selected individual frames and dense sequence sheets. This does not mean all3,360 frames have been individually inspected. The source hashes, decoder and timestamps are bound in `builds/reference/dense/manifest.json`; source pixels have not been warped.

The iPad recording governs composition and interactions. Its apparent stretch is a capture limitation; runtime assets stay at their preserved proportions on a fixed4:3 canvas. Fresh Tutorial has a single glowing Training option. Ordinary selections use a six-row curved fan: gold adds light, locked modes subtract underlying color. The tray has six towers and a wand. The shortcut order is Disco, Active Defense, Mines. The earlier silver-icon identification as Freeze was wrong: CMagicPanel::UpdateItems0x97628 explicitly pins these three, and CMagicItem::UpdateParams0x96378 identifies the40×40 atlas icons. The original wave strip displays individual numbered waves/type symbols.

TouchGameplay628–630 and288–290 show a separate return-to-map scene with Earth, Moon, a departing rocket and exhaust. The porthole loading scene before each battle is a different scene. Tutorial275–287 and Desert615–627 supply XP/reward reveal targets; forced reconstruction captures are not equivalent earned input replays. Later footage631–746 covers promotion, shop instruction/purchase, Career, fitting categories, Upgrades Yard and Spice Shop. No verified defeat overlay was found in these full clip timelines.

The TouchGameplay opening appears to contain the continuous narrative sequence from approximately18–90s, ending at The Earth before the world map. This is a candidate recovery source requiring continuity/audio/crop verification. It is not the missing original streamed movie file, and has not yet been substituted into the app.


## October14 reconstruction comparison

`builds/fidelity-comparison/comparison.png` pairs seven sampled source scenes with packaged tutorial/menu captures, preserving each image aspect ratio with letterboxing. Its manifest binds source/capture hashes and the package. Reviewed differences led to camera edge bounds, original five-tab navigation, the1.14 build captions and final tutorial guidance, and preserved win/loss/statistic strings. The native captions `& here please` and `place tower` differ from the earlier recorded wording; selected1.14 code takes precedence. Exact row geometry, UIKit easing/reward reveal, source display scaling and equivalent input state remain unverified. No pixel-parity score is claimed.

## Training water appearance, October14

The right-edge water crops at128.5,131.5,162.5 and180.5s in the main iPad recording retain the same painted pattern. Pairwise absolute RGB differences average about1.6–2.4/255, consistent with the visible compression noise; this sample does not prove that every original release disables water. Review artifact: builds/reference/water-motion-review.png. The recovered1.14 CWater animation produced visibly brighter, moving caustics in the reconstruction. Training now follows the selected recording's stable appearance. The native animation remains in explicit QA captures and the preserved814 render fixture; the exact version/renderer discrepancy is unresolved.


The current reconstruction comparison additionally exposes remaining portrait wrapping: the main guide's Welcome panel uses five opening text lines, while the reconstructed22pt UIKit port wraps that opening paragraph to four. The original assets are not stretched to compensate. GL callout wrapping is corrected separately at180px. New original-function probes supply inventory500ms slide flags, tutorial400ms page fades, and mode-item300ms movement/separate text; their captures are authored-code comparisons with explicit callback/font/service stubs, not equivalent input replays. The original result code uses XpBarGrow and xp_bar_grow, not a generic drawn glow circle. Its gain0.1 loop/growth stop now have native mixer captures.


October14 r23 reward review: the refreshed34-pair/9-sheet comparison binds current PCK9a9f5b1df8b423d650270c25ef7c202c6bb17d946aac04802c3b1e53e2479a91. The native result clock, medal0.8 sizing/shrink and short preserved reward bursts are ported. An initial r22 cloud exposed a particle-field misread; native release_interval5/clock multiplier1.6 corrected it. The iPad tutorial result guide at284.5s has no medals and a different input/reward clock, so growing-medal captures are explicit fixtures rather than equivalent guide frames. Welcome portrait remains wider/four lines versus five in the earlier recording; original UIKit raster/measurement remains unresolved. No assets are warped to match the encoded recording.


The r25 comparison34 pairs/9 sheets was inspected at full sheet resolution. It retains different timing/actions/progression: page5 and15 reference portraits were dismissed; the fixture keeps them, and early tower facings previously lost their dragged-preview frame. That facing behavior is now ported from RenderInActive. Native source has also supplied the original gold footer for Upgrades/Spice and the Spice Shop layout/tutorial. Its anonymous state hides purchases; the supplied earlier online frame740.5s shows real StoreKit offers, regional prices and an earlier gift/ad arrangement. A catalog pose is a fixture, not working purchase services or equivalent original offline play.


October14 menu review adds1,080 full-resolution30FPS frames across six selected later-menu ranges (19 new contact sheets). All19 sheets were inspected; several ranges capture static menus or guidance/fitting transitions rather than a tab change. Upgrades-to-Spice around734.48–734.88s and Tech Shop-to-Upgrades around722.70–723.10s show outgoing/incoming content moving horizontally while tabs/footer stay fixed. Selected individual full-resolution transition frames were inspected. Exact default easing, alpha and prior-version UIKit behavior are not yet measured as pixel-equivalent. Total reference captures now4,440; no claim that every frame was inspected individually.


October14 r32 comparison:37 pairs/10 inspected sheets bind PCK40d411d092fec7d414eafb3c8ce125c65510ddfbd21bdcb77a5b2f65b8af693c. Portrait500ms opening/closing poses are separate reconstructed lifecycle captures, not equivalent original frames. The actual readable tutorial now finishes at86070ms; earlier reward and physical mouse evidence keeps its package scope. Exact Welcome wrapping/UIFont raster remains open.


October14 build-arrow check: main iPad frames140.5/145.5/149.5s show a single long landscape arrow, retained during the first drag and absent after a tower is placed. Source1.14 Page01_EndCondition0xb8078 agrees across64 bounded device/orientation/tower-presence cases. r35 removes the portrait-orientation overlay and hides the landscape arrow after the first requested placement. This does not close the missing neighborhood hex outlines/red buildability shading in the moving preview. The current38-pair/10-sheet comparison was inspected in full, retaining the unstretched app canvas and unwarped recording.
