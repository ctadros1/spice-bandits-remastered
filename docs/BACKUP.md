# Private backup and edit history

Repository: [Spice Bandits: Remastered](https://github.com/ctadros1/spice-bandits-remastered), verified private on October15,2026. Source history retains the original implementation commit and subsequent reconstruction checkpoints. Large project files remain outside ordinary Git history and are backed up as private release assets. Keep the repository private: preserved original IPAs include store-account metadata and licensed assets.

The first source push and comprehensive archival upload are complete. The [private backup release](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/backup-2026-10-15-r89) contains seven archive parts totaling9,401,885,756 bytes, the per-file/part manifests, a complete Git bundle and the local verification report. Every archived regular-file hash, entry type, permission mode and link target passed local streaming verification:49,235 entries/45,636 regular files/11,125,488,719 uncompressed file bytes. GitHub's SHA-256 digests and byte counts match all11 uploaded assets. [Verification record](backups/2026-10-15-r89.json) binds the exact hashes.

## Snapshot scope

`python3 tools/archive_project.py builds/a-new-snapshot-directory` writes a compressed snapshot in parts under1.5GB each. It includes ignored originals, all supplied videos, imported runtime data, toolchains, recovered/decompiled material, packaged apps and validation evidence, together with source files. It preserves file modes and symlinks without following links outside the project. The per-file manifest records SHA-256 hashes and link targets. It does not alter original inputs or saves.

Exclusions are `.git`, Finder `.DS_Store` files and the chosen output directory. Git history is separately retained in the remote repository and an uploaded Git bundle. The normal Godot user save lives outside this project and is outside this snapshot; retained project-local verification saves/evidence are included. Backup staging files outside the snapshot directory are included.

GitHub's [release documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) permits assets under2GiB each. The archives use release assets to keep large binaries out of ordinary source history; this does not require Git LFS or a storage purchase.

The snapshot captures source commit`5fdf854` and project files present when creation began. Later source commits contain backup verification/tool corrections and do not change this historical archive. Commits`72020ae` and`5fdf854` verify locally using the configured SSH signing key; GitHub reports`unknown_key`, so its Verified badge is not claimed. The first system-Python compression argument failure and the verifier's original stat-type/permission comparison failure are preserved locally. The corrected verifier masks POSIX type bits when comparing tar permission modes; all file bytes and permissions pass.

## Restore

Clone the private repository for source/history. Download all snapshot parts and both JSON manifests from the indicated private backup release using an authenticated GitHub session. Check every part's byte count and SHA-256 against `PARTS.json` before joining the parts, in numeric filename order, into one `project-snapshot.tar.gz`.

Run `python3 tools/verify_project_archive.py /absolute/path/to/download-directory` to check every part and every archived file/link/mode without extracting. Inspect the tar listing and unpack into a new empty directory. Do not unpack over an existing checkout or original archive. Symlinks and executable modes are significant. `PROJECT-SNAPSHOT-MANIFEST.json` lists every saved regular-file hash, directory and link target. Verify the extracted files against it. GitHub's automatic source ZIP alone does not contain the private release archives.

The uploaded Git bundle supplies the captured source history independently of GitHub; inspect its advertised refs before cloning. Later source checkpoints should be committed and pushed after appropriate checks. Snapshot releases remain historical records; new archives should use new names/tags rather than replacing earlier evidence.

## Current reconstruction checkpoint

The [r94 private checkpoint](https://github.com/ctadros1/spice-bandits-remastered/releases/tag/backup-2026-10-15-r94) supplements the full r89 workspace snapshot. It contains the current macOS app ZIP, current QA evidence, additional captures and source history. All6 remote asset digests/byte counts match; the evidence archive verifies459 file hashes. The ZIP passed CRC checks, restored signature verification and an isolated menu launch with unchanged normal saves. [Checkpoint record](backups/2026-10-15-r94.json) binds source commitd9dbfe4 and PCKdbf34254. Nine native suites pass; live2x/4x performance and offline fidelity remain incomplete. This is not a new full workspace snapshot.
