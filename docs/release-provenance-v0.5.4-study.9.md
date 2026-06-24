# Release Provenance - v0.5.4-study.9

Generated: 2026-06-24T11:59:38.4769026+08:00
Predicate: `https://slsa.dev/provenance/v1`
Repo: `GravityblueX/YumeBox-MaterialDesign-Study`
Status: `OK`
Source commit: `33843ba31bc3e39ec7d69568ea0835de6822df79`

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
| git commit available | OK | 33843ba31bc3e39ec7d69568ea0835de6822df79 |
| release is not draft | OK | isDraft=False |
| package id recorded | OK | com.github.yizuka17.yumebox.md3 |
| version recorded | OK | 0.5.4-study.9/5409 |

## Boundary

- This provenance statement is study-release evidence, not a hosted trusted builder attestation.
- It links downloadable APK subjects to local build metadata, release asset manifest, and git source commit.
- Production release still requires private release signing, device matrix, privacy review, and trusted CI provenance.

