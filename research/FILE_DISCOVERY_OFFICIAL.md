# Official linked-file discovery

Research was performed on 2026-10-13 against exact URLs extracted from `original/analysis/__cstring.txt` and `original/analysis/offline_data.json`. The files were treated as data. Reads were limited to those explicit URLs and no code was installed or run.

## Retrieved data

| URL | Result | Verified content and value |
| --- | --- | --- |
| `http://s3.amazonaws.com/tdoffline/offline.dat` | HTTP 200; saved as [`offline.dat`](../original/additional-files/official/offline.dat) | 592,230 bytes, JSON object, `Content-Type: binary/octet-stream`. Response `Last-Modified` is 2012-02-09; `ETag` is `85988ef5a6cd0906b7e9bd6c2a6f11ea`. Retrieval time from the response `Date`: 2026-10-13 04:37:30 UTC. The raw SHA-256 is `fc524160b2ab4e7f77eefecba7ee2b7dd0267c7e88c9a78c0418b4c5a6d42a13`; see [`manifest.json`](../original/additional-files/official/manifest.json). |

The fetched bytes exactly match `original/game-files/ipa-1.14/Payload/Tower.app/offline_data.dat` (same SHA-256). Its decoded JSON also equals `original/analysis/offline_data.json`. It provides external provenance confirmation, but no newer configuration or content delta. The 2012 server timestamp and match to the 1.14 bundle leave no evidence of a newer snapshot.

## Other exact linked URLs checked

- `http://on-5.com/i/logo.png` returned HTTP 404 (redirected response was HTML), so it was not preserved as an image.
- `http://d2r0y9kezmx52z.cloudfront.net/thumbs/` is a prefix, not a specific asset URL; the host did not resolve during a single HEAD request. No object names were guessed or enumerated.
- `original/analysis/offline_data.json` contains 181 unique URL strings. All concrete item/costume/preview and level-pack URLs are already recorded among the 241 entries in `original/analysis/download-manifest.json`; the remaining entries are the unavailable logo, the CloudFront prefix, and an iTunes review URL. The preexisting inventory noted in the research request includes 89 costume images and 89 previews. No additional directly linked game art was found.
- The extracted strings and config provide no direct developer press-kit URL. No broader site or bucket discovery was attempted.

## Preservation boundaries

Only `original/additional-files/official/offline.dat` and its JSON manifest were added for this research. `original/analysis/offline_data.json` and baseline game files were left untouched. No account-facing or mutating requests were made.
