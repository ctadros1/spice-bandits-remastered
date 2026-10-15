# Private backup and edit history

Repository: [Spice Bandits: Remastered](https://github.com/ctadros1/spice-bandits-remastered), verified private on October15,2026. Source history retains the original implementation commit and subsequent reconstruction checkpoints. Large project files remain outside ordinary Git history and are backed up as private release assets. Keep the repository private: preserved original IPAs include store-account metadata and licensed assets.

The first source push and comprehensive archival upload are in progress. Do not treat this document as proof of a completed backup until the verification record is added below.

## Snapshot scope

`python3 tools/archive_project.py builds/github-backup-2026-10-15/snapshot` writes a compressed snapshot in parts under1.5GB each. It includes ignored originals, all supplied videos, imported runtime data, toolchains, recovered/decompiled material, packaged apps and validation evidence, together with source files. It preserves file modes and symlinks without following links outside the project. The per-file manifest records SHA-256 hashes and link targets. It does not alter original inputs or saves.

Exclusions are `.git`, Finder `.DS_Store` files and the chosen output directory. Git history is separately retained in the remote repository and an uploaded Git bundle. The normal Godot user save lives outside this project and is outside this snapshot; retained project-local verification saves/evidence are included. Backup staging files outside the snapshot directory are included.

GitHub's [release documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) permits assets under2GiB each. The archives use release assets to keep large binaries out of ordinary source history; this does not require Git LFS or a storage purchase.

## Restore

Clone the private repository for source/history. Download all snapshot parts and both JSON manifests from the indicated private backup release using an authenticated GitHub session. Check every part's byte count and SHA-256 against `PARTS.json` before joining the parts, in numeric filename order, into one `project-snapshot.tar.gz`.

Inspect the tar listing and unpack into a new empty directory. Do not unpack over an existing checkout or original archive. Symlinks and executable modes are significant. `PROJECT-SNAPSHOT-MANIFEST.json` lists every saved regular-file hash, directory and link target. Verify the extracted files against it. GitHub's automatic source ZIP alone does not contain the private release archives.

The uploaded Git bundle supplies the captured source history independently of GitHub; inspect its advertised refs before cloning. Later source checkpoints should be committed and pushed after appropriate checks. Snapshot releases remain historical records; new archives should use new names/tags rather than replacing earlier evidence.
