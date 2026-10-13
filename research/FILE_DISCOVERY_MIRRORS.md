# Original Spice Bandits material: mirror and forum findings

Research date: 2026-10-13. Scope: original On5/Chillingo iOS tower-defense game, also indexed under the prelaunch name **Spice Invaders**. Existing project inventory was supplied by the parent: decrypted/encrypted iOS 1.14, level ZIPs from `tower.on-5.com`, 89 costumes and 89 previews. No downloads were performed during this research.

**Subsequent parent verification:** the 1.27 candidate below was downloaded completely, CRC-checked, extracted, and compared. Embedded identity confirms version 1.27; both ARMv7/ARM64 code slices remain encrypted. See [verified results](FILE_DISCOVERY_SUMMARY.md). The original discovery-stage notes below retain what was known before acquisition.

## High-value candidate: 1.27 unedited IPA

- **Direct archive URL:** [Spice Bandits 1.27 [Unedited].ipa](http://dreamluckstudios.com/wp-content/ipa-archive/Games/Spice-Bandits/Spice%20Bandits%201.27%20%5BUnedited%5D.ipa)
- **Lead:** Reddit preservation conversation: https://www.reddit.com/r/MildlyVandalised/comments/feqtmt/spice_bandits/ and the relevant reply https://www.reddit.com/r/MildlyVandalised/comments/feqtmt/comment/kcwfw09/?force-legacy-sct=1
- The reply explicitly gives the URL above as the link to an IPA described in the surrounding conversation as version 1.27. The filename itself says `1.27 [Unedited].ipa`.
- **Live endpoint verified by HEAD only:** HTTP 200; `Content-Length: 98311415` bytes (about 93.7 MiB); `Last-Modified: Sun, 12 May 2024 15:55:31 GMT`; byte ranges advertised. This verifies that the named file endpoint currently responds and its server-reported size, not that its contents are valid or actually contain version 1.27. No payload was fetched, hashed, unpacked, installed, or run.
- **Version corroboration:** Soft112's catalog page independently lists the On5 iOS app's 1.27 release on 2017-10-05 and says the update fixes iOS 11 compatibility: https://spice-bandits-ios.soft112.com/. That page links back to App Store instructions; it does not provide the IPA itself. The title/date support the existence of 1.27, but do not authenticate the mirror payload.
- **Recommendation:** strong candidate for parent to acquire and inspect under their own archival process. Preserve the original filename/source and record a local hash and embedded bundle version if acquired. “Unedited” is a filename claim, not independently established provenance.

## Preservation/community leads

### Reddit: possible private/mediafire copy, now superseded by a public direct link

The Reddit thread above has a 2023 comment offering “the ipa file for 1.27,” followed by a comment saying it is on MediaFire and an offer to send a link. The MediaFire URL is not exposed in the accessible thread content. A later reply (2024) posts the Dreamluck Studios URL listed above. These comments are user claims; only the later URL endpoint was checked. Reddit also records a separate user report that a found IPA prompted for the original Apple ID, with replies attributing this to an uncracked/encrypted IPA: https://www.reddit.com/r/LegacyJailbreak/comments/1hso7yz/the_game_unavailable_in_appstore_wants_to_connect/. This is a useful warning about encrypted app-store packages, not proof that the Dreamluck file has that state.

### 4PDA thread: historical release discussion, no confirmed new package found

- Thread: https://4pda.to/forum/index.php?showtopic=306041 (indexed page: https://4pda.to/forum/index.php?showtopic=306041&st=40)
- Search-indexed thread material identifies the game as Spice Bandits / Spice Invaders and describes the authentic On5 tower-defense game. An indexed post #41 (2012-02-02) labels a package/version **1.02**; later posts discuss updates, DLC, bugs, and cheats.
- The accessible indexed page fragment did not expose a downloadable file URL, filename, or size. The forum's article page itself returned an internal error in the browser reader, so no attachment listing or binary access was verified. Treat v1.02 as a historical version lead only; it is older than the supplied 1.14 and does not yet establish a recoverable artifact.

## Android claim: likely unsupported / unresolved

A 2012 StopGame post claims Spice Invaders came in iPhone/iPad and Android versions: https://stopgame.ru/blogs/topic/30761/pervyy_iphon_i_3_gamy. However, contemporaneous product coverage identifies Spice Invaders as an iOS game by On5 and Chillingo (for example https://www.engadget.com/2012-02-09-daily-iphone-app-spice-invaders.html and https://www.pocketgamer.com/spice-invaders/). A Lithuanian 2013 article specifically places Spice Bandits among On5's iOS titles while distinguishing its other games available on Android: https://www.lrytas.lt/it/techno/2013/10/10/news/idomiausi-lietuviu-sukurti-zaidimai-ismaniesiems-irenginiams-4800142. Searches for an On5 Spice Bandits/Invaders APK produced no identifiable package. No APK, filename, version, size, or live Android download was confirmed. Do not infer an Android port from On5's general Android support or the single forum/blog claim.

## Other namesakes excluded

Search results for “Spice Invaders” include an unrelated modern Buldak/Samyang social tagging game (https://www.playspiceinvaders.com/), a Spice Girls student-made 2D platformer (https://sethglossop.wixsite.com/portfolio/spice-invaders), spice blend products, and unrelated Space Invaders clones. The target is the colorful On5/Chillingo mobile tower-defense game with space pirates mining Spice, multiplayer, and its 2012 iOS release; these namesakes do not count as source material.

## Remaining targets / gaps

- The 1.27 IPA is the only additional binary candidate found with a directly linked filename and a live, sized endpoint. Its archive contents and cryptographic hash remain unverified.
- No earlier IPA (including 1.02) or original patch/update package was found with an accessible direct file URL and verifiable metadata.
- No verified Android package or authentic Android build evidence was found.
- No source code, project files, development tools, or iOS saved-game/downloaded-game directory dump was located. The supplied level archives and costume material remain the known non-IPA assets; no additional such archives were found in this pass.
- 4PDA page extraction was incomplete, and the Reddit user's claimed MediaFire copy is not publicly linked in the thread view. These are the clearest follow-up avenues if additional versions become a priority.
