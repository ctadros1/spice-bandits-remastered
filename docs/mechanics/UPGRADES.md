# Upgrades Yard presentation

The tablet layout uses the preserved 1.14 NIB and recovered executable. TouchGameplay at 729.5 seconds is the principal visual guide, with its encoded stretch left in the reference image. Runtime assets stay at their original proportions.

## Recovered layout

`UpgradesViewController::viewDidLoad` at `0x31230` uses five columns, 150-pixel column spacing and 137-pixel row spacing. Twenty entries produce a 548-pixel content height. The tablet NIB scroll view begins at y164 and resizes with the root height. Its original 768-pixel width stays centered in the landscape canvas.

`loadItemAtIndex:` at `0x319cc` places each item and mirrors detail panels for columns 3 and 4. The source image remains 478×146 at y23. Its x coordinate is 5 on the left and −316 on the right. Panel name/description x is 171 or −284; cost x is 400 or −55. The mirrored image changes orientation; its text does not. The previous implementation shrank this art to 320×112 and replaced the name/cost fields with an invented sentence.

NIB text sizes are 21 for the item name, 13 for its count, 14 for the level lock, 22 for panel name/cost, and 18 for the description. `setKey:` at `0x68278` takes the absolute integer percentage, formats the original description and centers natural-size icon textures in a 120×100 container. The white `_1` image is the original fill mask. `updateFillImageForCount:` at `0x676a0` reveals its bottom `floor(height×level/10)` pixels. It is not an erroneous white rectangle to recolor.

`updateItemView` at `0x689e8` uses `Level %d/10` and `%dup` for the next allocation. The local schema stores complete levels, so its next-level marginal cost supplies the corresponding panel value. Original partially allocated raw-point profiles are not imported. `updateButtons` at `0x68090` hides minus at zero and plus at maximum; the friend-derived upgrade exposes neither. Locked items retain descriptions but have no allocation buttons. Affordability remains checked when pressing plus, rather than dimming the original icon before the press.

`animateSelect` at `0x67370` brings the item forward; `animateDeselect` at `0x674d8` sends it back. Both install a CATransition fade with a 0.30000001192092896-second duration. The reconstruction retains outgoing detail controls during its fade and disables their actions. The description has a separate dismissal hit area, as in `updateDescriptionButton` at `0x67248`.

`onUpgradesItemSelection:` at `0x31808` requests an animated scroll. It compares item y against the current offset, then against `rootHeight−210−itemHeight+offset`. For the 768-pixel canvas and a 187-pixel item, the last row moves from offset0 to40; selecting the top row returns to0. A separate translated content view retains the original 548-pixel content size while allowing this programmatic offset.

## Verification and limits

`tools/native_upgrade_layout_reference.py` executes original ARM placement/mirroring and selection-scroll functions. Forty layout records include 20 tablet and 20 supplemental phone items. The source gate compares the tablet records in 140 checks, plus 144 tablet selection-scroll cases across three root heights and six incoming offsets, for 284 checks. Objective-C/session/NIB allocation, notifications, threading, transforms and frame getters/setters are explicit stubs. This is isolated original-function evidence, not UIKit rendering or a whole original app.

The menu suite separately checks actual reconstructed nodes, transactions/refunds, button visibility, outgoing fades, left-facing panels and bottom/top selection scrolling. Native package captures include the grid, selected Range, fading deselection, fading/mirrored Wizard and selected last row. Synthetic level/points fixtures are not earned campaign progress.

UIKit text rasterization, default truncation, Core Animation blending/easing and interrupted transitions are not reproduced by the ARM probe. The recovered NIB uses 21-point one-line item labels; some long labels truncate in the reconstructed renderer, whereas the earlier recording shows complete names. This remains an explicit version/text-layout comparison. The scroll interpolation currently shares the reconstructed 300ms ease; the native function requests animation but does not specify its duration. Friend-derived levels and the original session's network posting remain unavailable offline.

## Native input regression and correction

The r51 physical mouse run reached the original Upgrades Yard through pause, map-return confirmation, navigation and first-visit guidance. Clicking Range opened its detail, but clicking that visible description selected Damage underneath it. The runtime snapshot and native screenshot are preserved in `builds/upgrades-native-input-r51/`; that input audit remains incomplete/failed despite clean exit and unchanged protected files.

Godot's drawing order did not change mouse dispatch order. The fix moves the selected item to the last sibling position as well as drawing it in front. Outgoing detail actions ignore mouse events during their visual fade. The source menu test now sends actual viewport press/release events to the description's coordinates and requires the selection to clear; direct button-signal calls would miss this regression. The r52 retry now passes actual native mouse verification: Range description dismisses without selecting Damage, Wizard mirrors left and dismisses, First class settles at the original40px offset, and Range restores0px. `builds/upgrades-native-input-r52-retry/` retains runtime snapshots, chronological observations and a passing isolated-process/save/resource/signature/exit audit. This fresh zero-XP/spice account makes no allocation, earned reward or campaign claim. The timed-out first r52 attempt remains failed; reconnecting after its timeout opened the regular app, which was closed without game interaction and with both normal hashes unchanged.


The r54 package repeats the native Range selection/description dismissal, mirrored Wizard/dismissal and First class40px→Range0px scroll with actual CUA mouse input. It also exercises Home and the newly rocking Play/Career/Upgrades controls. Command-Q exits0; no CUA observation follows it. `builds/menu-upgrades-native-input-r54/` retains its passed audit, observed states and action record. This account remains zero XP/spice and claims no purchases or earned progression. r52's earlier evidence remains preserved at its original hashes.
