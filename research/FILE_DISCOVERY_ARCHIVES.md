# Additional file discovery: archives and historical versions

Research date: 2026-10-13. Scope: public catalog and archive discovery only. No software was installed or executed. The repository already contains encrypted and decrypted 1.14 packages, the full set of 63 level ZIPs, and 89 costume images plus 89 previews; entries below are assessed against those holdings.

**Subsequent parent verification:** separate mirror research located a directly downloadable 1.27 IPA, now preserved and inspected. See [verified results](FILE_DISCOVERY_SUMMARY.md). The listing-only limitations below describe the archive/catalog discovery stage.

## Highest-value candidates

| Candidate | Direct source and file metadata | Access and verification | Reconstruction value and limitations |
|---|---|---|---|
| **Spice Bandits 1.27 (2017), possible later build** | [Soft112 listing](https://spice-bandits-ios.soft112.com/). It reports version **1.27**, update **2017-10-05**, iOS, and **117.1 MB**. | Listing page is accessible and reports the version/size, but offers no verified direct IPA URL. Its stated install path redirects to the App Store; I did not find an obtainable package. Treat size as listing metadata, not verified binary size. | **High if recovered**: later version might contain final balance/content, assets, or the iOS 11 compatibility changes absent in 1.14. There is no evidence yet of a changed level roster; listing only says the update fixed iOS 11 compatibility. |
| **Spice Bandits 2 turret art (2016 development concept)** | [Artist's source post](https://alsukelis.blogspot.com/2016/07/some-turrets-from-spice-bandits-2.html); direct image: [towerSB2_3D_01.png](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEikT4wT1nKya8k96TBxFgE5xRIurTkGRl2pFskRsqpoXLojhPbiarJAXP4YCtZIJWwJ0afYCf27NHC8uNJb29MsL41Rw7yUMI5jy-YGIEz0Eoe6ZfzZ9FFSoJ0qqwnRPfVXBXL84_qqZ4KP/s1600/towerSB2_3D_01.png), PNG, **705,944 bytes** (HTTP HEAD 200, image/png). | The original post states the image is from development of “Spice Bandits 2” and describes the turret lighting/model work. Image URL and response headers verified. | **Medium for visual reference**: potentially informs turret redesign and shows a sequel was in development. It is one rendered concept image, not source, a model file, a playable build, or evidence the sequel shipped. No broader asset bundle found. |

## Archive.org check

- Archive.org's official [Advanced Search API](https://archive.org/advancedsearch.php?q=%22Spice+Bandits%22&fl%5B%5D=identifier%2Ctitle%2Cmediatype&rows=50&page=1&output=json) returns one exact-title software item: [Spice Bandits (1.14, iOS 4.3)](https://archive.org/details/Spice_Bandits_1.14_ios_4.3_1782552222).
- Its [official item metadata](https://archive.org/metadata/Spice_Bandits_1.14_ios_4.3_1782552222) lists `Spice_Bandits_1.14_ios_4.3.ipa`, **84,993,685 bytes**, SHA-1 `b528141cc8b32a31c88752bf06afedd143210c8a`, bundle ID `com.chillingo.spicepirateshd`, minimum iOS 4.3, and 32-bit. These match the existing `original/archives/spice-bandits-1.14-encrypted.ipa` exactly by size and SHA-1, so this is a **duplicate** of already-held material, not a new build. Archive.org also lists `iTunesArtwork.png` (**91,353 bytes**), but the package already contains its artwork and app icons.
- The API and item metadata are readable. A HEAD request to the Archive.org direct IPA download URL returned HTTP 500 during this check, so direct payload access was not confirmed. Archive metadata marks the item as malware-checked by its curator; that label is not a substitute for independent package verification.
- Searches of the official API for `"Spice Pirates"`, `"Spice Invaders"`, the bundle ID, and `467338170` found no additional Spice Bandits software item. Results for “Spice Invaders” were unrelated titles or unrelated software. **No distinct 1.27, source archive, tools, Android build, or new level pack was located in Archive.org.**

## Lower-confidence leads and negative findings

- A public [4PDA Spice Bandits discussion](https://4pda.to/forum/index.php?showtopic=306041&st=40) mentions “Bonus MP urban level” and “Bonus MP winter level” in a 2012 post. Other participants question whether these were actually available. This is **not a file lead**: no download, archive identifier, filename, or size is provided. It may be useful as a check against multiplayer map content, but the claim is uncertain and the thread is forum discussion rather than a primary release record.
- The app's former title **Spice Invaders** is confirmed by contemporary reviews, while the store title is **Spice Bandits**. Searches using **Spice Pirates**, the bundle ID, and App Store ID **467338170** did not surface a distinct executable or Android package. A search result that claims an Android Google Play link has a blank package ID and no verifiable listing/package; it is not evidence of an Android release. No Android build is recommended for acquisition based on current evidence.
- Historical references describe the original release as 55 levels across five environments; this project already has 63 level ZIPs. The sources reviewed did not identify any extra standalone campaign/level-pack download beyond the already preserved set.

## Sources consulted

- [Archive.org Advanced Search API](https://archive.org/advancedsearch.php?q=%22Spice+Bandits%22&fl%5B%5D=identifier%2Ctitle%2Cmediatype&rows=50&page=1&output=json) and [item metadata API](https://archive.org/metadata/Spice_Bandits_1.14_ios_4.3_1782552222).
- [Soft112 Spice Bandits version history](https://spice-bandits-ios.soft112.com/).
- [Almantas Šukelis, “Some turrets from ‘Spice Bandits 2’”](https://alsukelis.blogspot.com/2016/07/some-turrets-from-spice-bandits-2.html).
- [4PDA Spice Bandits discussion](https://4pda.to/forum/index.php?showtopic=306041&st=40).
