# Projectile flight and chemical activation

Reference: decrypted Spice Bandits1.14 ARMv7 executable SHA256 `e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`. Rules below are code-traced reconstructions. Ghidra expressions were checked against the saved assembly and executable literals. Original-device or footage comparison remains separate work.

## Ordinary tower missiles

`CMissile` constructor0xde4f0 starts at the tower animator position and moves10 pixels toward the original target. `Update`0xdee98 tracks the living creep's displayed aim point, including its resource offset. Each update checks a strict20-pixel axis rectangle, the previous movement segment against its edges, and a timeout strictly greater than8000ms. Collateral damage centers on the cached destination, even when the missile impacts before reaching it.

The steering recurrence at0xdf8ca..0xdfa52 uses seconds=min(deltaMs,100)/1000, gamma=(seconds*3.75)/float32(0.3), and desiredVelocity=normalized(destination-position)*rawVelocity*max(seconds,float32(0.04)). With previous velocity v and acceleration a, next velocity=v+a*gamma; next acceleration=a+(desiredVelocity-v-2*a)*gamma; position+=nextVelocity*seconds. At gamma>=1, v becomes desiredVelocity and a becomes zero before this recurrence. These are pixel units, not cells per second. The replay retains30ms steps and32-bit vector arithmetic.

`CTower::UpdateMissiles`0xe6e00 staggers Katyusha/AA missiles. Its shared counter enables one queued missile every `(3000/rawVelocity)*100` ms, with the counter reset after a threshold update. Launch offsets depend on volley count and alternate sides; three missiles include a central launch. Original counts, divisors and direct-hit/collateral eligibility remain in the simulation.

## Nukes

`ProcessNukeLaunch`0xe77ac accumulates reload time. When it exceeds ROF/support, the tower chooses a target, opens and starts its lights/sound. While opening it tracks the target, retaining the last point if the target disappears. Launch occurs at accumulated time>=ROF/support+2000ms. The accumulator is inherited from the previous tower form and constructor default100000ms; an already-ready inherited value can launch in the same opening update. There is no unconditional new two-second timer.

The nuke constructor starts at animatorY+missileTextureHeight/2+10. It fixes the destination, initializes flight velocity=rawVelocity*5 and acceleration=0. Every update subtracts the old acceleration from velocity, increments acceleration by deltaMs/5, and clamps velocity to the raw resource value. Ascent progress+=(1000/currentVelocity)*deltaMs/500. The missile interpolates vertically500 pixels above its launch point, scales by0.9*progress+0.15, and fades after progress0.8. Descent starts on the following update above the fixed target and uses rawVelocity. Its scale is1-0.5*progress, with the authored descending texture height adjustment. For rawVelocity3000 and30ms updates, ascent takes93 ticks and descent51 ticks:4320ms total flight. Closing begins after ascent. Explosion plays the preserved20-frame/15FPS resource at2× scale. Radiation uses the fixed impact point.

## Chemical bubbles and clouds

`CPoisonBubble` constructor0xe1c24 records a fixed creep aim point; the tower call passes the tracking flag false. It starts from the tower animator, with growthY=towerY-authored tower_height and endY=growthY-60. `Update`0xe21d0 increases age bydeltaMs/500 and progress bydeltaMs/(age+500), interpolates between those Y points, expands the bubble from16 to64 pixels and raises alpha from0.4. Growth takes510ms at30ms replay steps.

Flight then increases progress bydeltaMs/600 and interpolates recursively from the current position toward the fixed destination. Arrival is distance<5 pixels or progress>=1. The original64×64 bubble and20×16 shadow crops are retained. `CPoison::Update`0xe1268 suspends both damage and cloud lifetime until the linked bubble is inactive. `UpdatePoisons`0xe75dc updates clouds before bubbles; arrival activates damage on the next tick. Cloud damage/slow overlap retain powers-of-two diminishing exposure.

`CPoison::DoDamage`0xe17c0 adds the tower's direct-damage support bonus to poison damage. `ProcessSupply`0xe4650 computes that bonus from direct resource damage. Thus chemical resources with zero direct damage receive no poison damage boost; a700-damage nuke with10% support adds70 to its10 poison damage. This unusual rule is preserved.

## Texture import and remaining differences

`CResourceManager::LoadTextures`0x118a74 iterates every XML texture child. Both `<t>` and older `<texture>` forms now import. The preserved Katyusha sprites, shadows and pads previously omitted by the derived importer now resolve. Extra texture crops and vertical/horizontal flips are cached and used for projectiles.

Focused checks cover the recurrence, rectangle and crossing collisions, timeout boundary, nuke launch inheritance/warning/target snapshot/ascent/descent, bubble growth/arrival/lifetime, radiation support arithmetic, and older texture spelling. Packaged renderer coverage is recorded separately in `docs/VALIDATION.md`.

Open: the original particle system, missile height/shadow adjustments near impact, target scattering, precise damage/eligibility filters, ownership/frame order between different towers, variable-delta timing, blast wave/decal lifetimes and audio mixing. Enemy projectile steering from CCreepMissile::Update0x8120c is now ported with the same recurrence and constructor10px launch nudge. It checks only four10px rectangle edges, without the tower class's interior/timeout guards. Both classes use the native32-bit LineIntersectLine0x11095c instead of an engine intersection helper. Bombs retain the original launch facing; other projectiles track facing. Near-impact height, shadows and paired launch separation remain open. A synthetic renderer fixture does not establish source-device parity or campaign completion.
