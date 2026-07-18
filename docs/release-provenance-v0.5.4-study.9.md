# Release Provenance - v0.5.4-study.9

Generated: 2026-07-19T05:57:32.6183704+08:00
Predicate: `https://slsa.dev/provenance/v1`
Repo: `GravityblueX/YumeBox-MaterialDesign-Study`
Status: `OK`
Source commit: `6306c23a371632ff20f3f0b9e89e3c93fb471f5e`

## Subjects

| APK | Kind | Size | SHA-256 | Package | Version |
|---|---|---:|---|---|---|
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk` | debug-apk | 60307760 | `9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80` | `com.github.yizuka17.yumebox.md3` | 0.5.4-study.9/5409 |
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk` | release-apk | 28193436 | `7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc` | `com.github.yizuka17.yumebox.md3` | 0.5.4-study.9/5409 |

## Gates

| Gate | Result | Detail |
|---|---|---|
| asset manifest exists | OK | C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\docs\release-asset-manifest-v0.5.4-study.9.json |
| build environment exists | OK | C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\docs\build-environment-v0.5.4-study.9.json |
| permission justification exists | OK | C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\docs\apk-permission-justification-v0.5.4-study.9.json |
| asset manifest ok | OK | ok=True |
| asset manifest tag matches | OK | tag=v0.5.4-study.9 |
| debug and release APK subjects | OK | 2 subject(s) |
| all subjects have sha256 | OK | 2 subject(s) |
| all subjects have names | OK | subjects=2, missing=0 |
| subject names are unique | OK | subjects=2, duplicates=0 |
| all subjects have URIs | OK | subjects=2, missing=0 |
| subject URIs are unique | OK | subjects=2, duplicates=0 |
| all subjects match release tag asset URIs | OK | subjects=2, invalid=0; tag=v0.5.4-study.9 |
| all subjects use GitHub HTTPS release downloads | OK | subjects=2, invalid=0; prefix=https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/download/v0.5.4-study.9/ |
| all subject URI filenames match names | OK | subjects=2, invalid=0 |
| all subjects have positive sizes | OK | subjects=2, invalid=0 |
| all subjects have canonical sha256 | OK | subjects=2, invalid=0 |
| git commit available | OK | 6306c23a371632ff20f3f0b9e89e3c93fb471f5e |
| release is not draft | OK | isDraft=False |
| package id recorded | OK | com.github.yizuka17.yumebox.md3 |
| version recorded | OK | 0.5.4-study.9/5409 |
| all materials have URIs | OK | materials=4, missing=0 |
| material URIs are unique | OK | materials=4, duplicates=0 |
| all materials have digest evidence | OK | materials=4, missing=0 |
| all file materials have canonical sha256 | OK | fileMaterials=3, invalid=0 |
| all file materials reference expected docs JSON | OK | fileMaterials=3, expected=3, unexpected=0, missing=0 |
| repo material has canonical git commit | OK | repoMaterials=1, invalid=0 |

## Boundary

- This provenance statement is study-release evidence, not a hosted trusted builder attestation.
- It links downloadable APK subjects to local build metadata, release asset manifest, and git source commit.
- Production release still requires private release signing, device matrix, privacy review, and trusted CI provenance.
