# Original menu bubbles, floating text, lamps, flies and notes

Baseline: decrypted1.14 executable and `TowerViewController.nib`. These are menu presentation effects; they do not alter battle state, progression, campaign saves or asset proportions.

## Bubbles

`loadAnimations0x1ec6c` creates150 blank1×1 views. `bubblesAnimation0x1f39c` requests four ordinary emissions per callback. `startAnimations` supplies the0.05999999865889549-second interval. When `rand()%50==10`, it selects one of nine source views and requests another10–29 emissions from that same view. The sources are the five menu buttons, greetings group, XP, balance and blank auxiliary view beneath `flotersView`; they are not the foreground urchins.

`createBubble:0x1f668` computes each local spawn with float32 width/height times `(rand()%100)/100`, converts it into the bubble container and selects the next pooled slot modulo150. Speed is60 and distance is `clamp(convertedY-10,0,100)`. Direct ARM execution corrected an initial decompiler reading that missed intermediate distances. `startBubble0x1f900` retains the vertical path, float32 distance/speed duration, opacity `[0,1,1,0]`, solid white color and ease-in group. The group expires while its child animations request retention. The renderer draws the original1px views, centered on their layer positions; no invented particle texture is used.

`native_menu_bubble_reference.py` executes54 path declarations,54 creation cases and54 timer callbacks. Objective-C, paths, color, frame lookup and point conversion are explicit stubs.865 source comparisons pass. The r53 menu package passes152 checks/41 PNGs with five distinct menu poses. Full-resolution1.4/2.025-second views were inspected; `builds/menu-bubbles-r53/` retains the gallery and audit. PCK `77d71f3bbc566204a42c9dfba8af097a8cee396769aa12e2e1a06622d2b5356c`, executable `5e24ee831f4d462d386cff1483467a8a973b9c010bbf08810545d02078b54f0b`, helper `ff3bd8afa78f716b201f63171a21b053e31a09c06f7ed5060001a30f504fe011`. This is reconstructed rendering, not original-device pixels.

## Floating menu text

`floteView:0x1ff60` applies separate position and rotation keyframe animations to all nine direct source views. It begins at the original layer position, adds random x/y displacements and repeatedly multiplies both by−0.8999999761581421, alternating around the center until integer magnitudes fall below1. It closes the path at the original center. The20-second path reverses and repeats. X displacement is `(rand()%100)*2/100`; y is `2+(rand()%int(rootHeight/10))*6/100`, using original float32 ordering.

Rotation values are `[0,0.01+(rand()%40)/1000,0,-0.01-(rand()%40)/1000]`, with float32 division followed by the original double constant addition. Its period is float32 `4+(rand()%100)/100` seconds, with reversing, cumulative and ease-in/ease-out declarations. The macOS port applies the same pose to the rendered label and its input control, around the original center. The greetings group's children inherit its transform. Hit testing is adapted to the visible desktop control; original UIKit model/presentation hit delivery is not executed.

## Lamps

`startLampsightsAnimations0x22298` animates nine NIB image views tagged100–108. Their NIB model alpha is0; earlier rendering incorrectly showed every glow immediately. Each repeats a nonadditive3.5-second ease-in/ease-out opacity animation. The begin time is float32(mediaTime+tagRemainder/10) plus `(100+index)*0.08`, starting at eight seconds and staggered by about180ms.

The original supplies three values `[0,1,0]` but five key times. The requested arrays are retained in the fixture; rendering uses the documented invalid-array fallback to equal spacing.24 original floating-text cases and three original nine-lamp declarations supply820 source comparisons. Framework defaults are based on Apple's [nil timing function](https://developer.apple.com/documentation/quartzcore/caanimation/timingfunction?language=objc), [key-time requirements](https://developer.apple.com/documentation/quartzcore/cakeyframeanimation/keytimes) and [keyframe timing guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/CreatingBasicAnimations/CreatingBasicAnimations.html), not an old iOS compositor run.

## Fireflies and musical notes

`startFliesAnimations0x203e4` initializes six authored3px firefly images. Each starts at a float32 random point inside the logo-flies frame, followed by4–9 cubic segments and a final cubic returning to its start. Tablet control/end-point offsets use40px random extents; phone uses16px. The two-second path repeats with linear timing. The runtime retains these cubic points and evaluates each original segment. Core Animation path flattening and its exact curve parameterization remain rendering differences.

`notesAnimation0x1f470` always requests the eye animation. Its music flag independently gates one note per0.699999988079071-second callback, cycling ten NIB images. The note starts at the original randomized x/y, rises by that y over four seconds and alternates x by a random0–5.94px on tablet (phone half). `startNote0x1fc10` supplies six path vertices and a separate70%-duration opacity animation `[0,1,0.7,1,0.8,1,0]`. When that animation expires, the original model opacity0 makes the note invisible. Muting stops new emissions; existing notes finish fading.

`native_menu_motion_reference.py` executes12 single-fly path cases,48 note declarations and24 music/index callbacks. Fast enumeration, view frames, device/music flags, objects, paths and global random inputs are explicit stubs.1,334 source comparisons pass, including every original cubic point, note path/opacity duration, music guard and pool wrap. Supplemental phone cases do not claim a phone UI port.

## Remaining limits

Visual RNG uses separate local streams and fixed QA seeds. Original global-rand consumption, historical lifecycle/resume phases, interrupted animations, implicit transactions, UIKit text/rasterization, Core Animation path interpolation and full original-framebuffer equivalence remain unresolved. Fixed1024×768 geometry uses original-proportion art; it does not duplicate the recording's apparent stretch. The r54 native menu audit passes166 checks/47 PNGs, including eleven distinct menu poses. Delayed-lamp and note/float poses were inspected at full resolution. All ten native package suites pass the exact resources in VALIDATION.md. The r54 physical-input run also verifies Home and the moving Play/Career/Upgrades controls, plus upgrade selection/dismissal/mirroring/scrolling. These are reconstructed rendering/input checks, not original-device equality.
