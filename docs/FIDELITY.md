# Offline fidelity status

This is a playable reconstruction in development. It is **not yet the completed original offline game**, and multiplayer restoration has not begun. No expansion content has been added.

## Release-blocking differences

1. Navigation now implements native ordered links, horizontal shortcut blockers, the unusual A* comparison, goal-to-source smoothing and base-selection cost. Movement interpolation, per-player penalties, ownership, reacquisition and every target eligibility rule remain open.
2. All populated enemy resources are loaded. Marine kamikaze, native stand-off checks, nine-point attacker displacement and reload after alignment are implemented; bombing, missiles, burst presentation, orbiting, growth, isolation and escort behavior are incomplete.
3. All54 tower forms have focused combat/support checks. Missile volley counts/divisors, direct versus collateral hits and circular splash are traced. Construction uses a provisional one-second delay; nuke warning has the traced two-second stage but the full original nuke/projectile animation timing is incomplete. Cloud launch/buff details need review.
4. The tutorial is winnable through UI actions, but uses a compressed page graph. Exact prompt timing, confirmations, required kills, camera movement and three placement positions still need parity work.
5. Campaign schemas and valid spawn routes have been exercised for all148 nonempty schedules. That is not a campaign playthrough: every mission/mode must still be tested for wins/losses, special bases, static portals, mine maps, dense waves and endpoint progression.
6. Single perfect stars, shop prices/unlocks and upgrade definitions are present. Original rank/level thresholds, live XP persistence, refund/reset rules, special medals, repeatable medal records, gift spice and service reconciliation are unresolved. The local threshold curve/starter consumables are provisional adaptations.
7. Original fonts, map layers, directional frames, shadows, pads, sounds and story images are used. Menu layers/positions now derive from the original NIB; avatar slot order and selected logo/gear timing are traced. Desktop landscape anchoring is an explicit adaptation. Logo rocking, eye tracking, bubbles, full UI geometry, particle/electric/chemical/water/debris effects and exact sound mixing/loop tails remain partial.
8. The narrative intro was streamed from `http://engine.tower.on-5.com/intro.php`; the bundled MOVs are publisher splashes. Supplied trailer clips contain intro excerpts but are not verified original intro files. No trailer has been relabeled as the original movie.
9. The Universal2 package has native Apple Silicon launch and basic mouse/keyboard/fullscreen/settings evidence. Intel hardware, physical trackpad gestures, focus/Retina edge cases, final repeated packaged checks and notarized distribution are outstanding.

## Content audit

`content-audit.json` records four narrowly scoped XML repairs, three conflicting candidates (bundled1.14 selected), no missing direct animation/map image references, and seventeen campaign-data anomalies accounted for by native source/null-resource guards and an unused trailing source entry. Three filename metadata edges remain unresolved: two deprecated creep7 particle references and an extra tower1_2 icon reference. Creep7 is not a populated runtime enemy family; the main tower icons resolve through other original metadata. Keep these as explicit gaps until their runtime use is fully ruled out.

Original files and archived downloads are checked against the preservation manifests. Conversion is derived, with source hashes and per-asset output hashes. The source repository deliberately excludes preserved original material, generated art/data, reference videos, local research traces and packaged builds.

## Next work

Finish enemy state machines and native paths first, then tower/effect timing and tutorial parity. Resolve and document progression replacements, exercise the full offline campaign, and complete the macOS visual/input/audio audit. Begin multiplayer only after the offline release gate passes.
