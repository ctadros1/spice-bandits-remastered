# Additional Game Files: Verified Results

Checked October 13, 2026. Independent searches covered preservation archives, obscure community mirrors/forums, and exact original-service URLs. The individual search reports remain available for provenance and unresolved leads.

## Useful addition: version 1.27

The [community-mirror IPA](http://dreamluckstudios.com/wp-content/ipa-archive/Games/Spice-Bandits/Spice%20Bandits%201.27%20%5BUnedited%5D.ipa) was downloaded completely, hashed, CRC-checked, and statically inspected. It was not installed or launched. Preserve it separately from 1.14:

- Archive: `original/additional-files/mirrors/spice-bandits-1.27-unedited.ipa`
- Extraction: `original/game-files/ipa-1.27/`
- Download provenance: [manifest](../original/additional-files/mirrors/download-manifest.json)
- Full comparison: [comparison JSON](../original/analysis/ipa-1.27-comparison.json)
- Individual file hashes: [inventory](../original/analysis/ipa-1.27-inventory.json)

| Check | Result |
| --- | --- |
| Embedded identity | `com.chillingo.spicepirateshd`, version 1.27, build 16 |
| Package | 98,311,415 bytes; 1,348 non-directory files; all ZIP CRC checks passed |
| SHA-256 | `7f910500b9bbef8fc3026cc9b60ebc31361346da696e35a241f3f202496fe495` |
| Executable | ARMv7 and ARM64 slices; both have `cryptid=1` and encrypted code ranges |
| Build metadata | iPhoneOS 11.0 SDK; minimum iOS 8.0 |
| Compared with decrypted 1.14 | 839 files byte-identical, 427 changed, 82 added, 18 removed |
| Offline definitions | `offline_data.dat` byte-identical |
| XML content | All 200 XML files byte-identical; no added/removed XML files |
| Audio/video | All shared CAF, MP3, and MOV files byte-identical |

The added files mostly concern newer app packaging, icons, advertising/analytics resources, and interface backgrounds. Genuine additional presentation assets include `career_2017.jpg`, `tech_shop_2017.jpg`, `spiceshop_2017.jpg`, `upgrades_1472x828_960.jpg`, and phone/tablet main-menu images. The career and tech-shop backgrounds were visually inspected: both are wide 1472×828 compositions with a central panel and original themed artwork.

Changed files include 378 PNGs, 42 NIB interface files, and two tutorial-map JPGs. A changed file hash alone does not establish changed pixels or gameplay. Later executable behavior could differ even though the bundled definitions match; encrypted code prevents the same direct inspection available in decrypted 1.14.

**Practical value:** more original interface material and a preserved later release. **No additional campaign definitions were found in this package.** It does not replace the decrypted 1.14 executable as the behavioral reference. The mirror's “Unedited” filename is not authenticated provenance, and a valid archive is not proof of runtime compatibility.

## Confirmed duplicates

| Discovery | Why it adds no new gameplay content |
| --- | --- |
| [Archive.org 1.14 item](https://archive.org/details/Spice_Bandits_1.14_ios_4.3_1782552222) | Its declared size and SHA-1 match the held encrypted 1.14 archive. |
| [Original S3 offline snapshot](http://s3.amazonaws.com/tdoffline/offline.dat) | Downloaded JSON is byte-identical to bundled `offline_data.dat`; preserved with its [manifest](../original/additional-files/official/manifest.json). |

## Remaining leads

- A historical 4PDA post references version 1.02, but no working attachment/package URL was established.
- A Reddit user mentions a private MediaFire copy of 1.27 without exposing the URL. The public mirror above supplies an inspected 1.27 package already.
- The original artist published a Spice Bandits 2 turret concept. It is sequel-development reference art, not original campaign content, source code, or a playable sequel. Keep it outside the clone scope.
- No authentic engine source, Xcode project, hosted-server source, verified Android port, extra level archive beyond the 63 preserved URLs, or original downloaded-game/save-directory dump was found.

These are the results of this research pass, not a claim that no further material exists. Follow-up searching should target a specific gap, especially original multiplayer recordings, a working reference installation, or saved profile/download directories.

Detailed reports: [archives](FILE_DISCOVERY_ARCHIVES.md), [mirrors](FILE_DISCOVERY_MIRRORS.md), and [original services](FILE_DISCOVERY_OFFICIAL.md).
