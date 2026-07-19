# Release Asset Manifest - v0.5.4-study.9

Generated: 2026-07-19T13:47:25.7063325+08:00
Repo: `GravityblueX/YumeBox-MaterialDesign-Study`
Release: `YumeBox Study v0.5.4-study.9`
Published: 2026-06-23T23:55:21.0000000+08:00
Status: `OK`

## Summary

| Metric | Value |
|---|---:|
| Assets | 5 |
| APK assets | 2 |
| Debug APKs | 1 |
| Release APKs | 1 |
| Supporting reports | 3 |

## Gates

| Gate | Result | Detail |
|---|---|---|
| installability report exists | OK | C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\docs\apk-installability-report-v0.5.4-study.9.json |
| permission review exists | OK | C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\docs\apk-permission-review-v0.5.4-study.9.json |
| installability report ok | OK | ok=True |
| installability tag matches | OK | tag=v0.5.4-study.9 |
| permission review ok | OK | ok=True |
| permission review tag matches | OK | tag=v0.5.4-study.9 |
| release tag matches | OK | tag=v0.5.4-study.9 |
| release is not draft | OK | isDraft=False |
| release published timestamp recorded | OK | publishedAt=06/23/2026 23:55:21 |
| release published timestamp is not in the future | OK | publishedAt=06/23/2026 23:55:21, generatedAt=2026-07-19T13:47:25.7063325+08:00 |
| all release assets have names | OK | assets=5, missing=0 |
| release asset names are unique | OK | assets=5, duplicates=0 |
| all release assets have URLs | OK | assets=5, missing=0 |
| release asset URLs are unique | OK | assets=5, duplicates=0 |
| all release assets have positive sizes | OK | assets=5, invalid=0 |
| all release assets are uploaded | OK | assets=5, invalid=0 |
| all release asset digests are canonical SHA-256 | OK | assets=5, invalid=0 |
| all release asset URLs match release tag | OK | assets=5, invalid=0; tag=v0.5.4-study.9 |
| all release asset URLs use GitHub HTTPS downloads | OK | assets=5, invalid=0; prefix=https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/download/v0.5.4-study.9/ |
| all release asset URL filenames match asset names | OK | assets=5, invalid=0 |
| debug APK asset present | OK | 1 debug APK asset(s) |
| release APK asset present | OK | 1 release APK asset(s) |
| support reports uploaded | OK | 3 report asset(s) |
| support report asset content types match formats | OK | invalid=0; json=application/json; markdown=application/octet-stream,text/markdown,text/plain |
| release APK assets uploaded | OK | apkAssets=2 |
| APK asset digests are canonical SHA-256 | OK | invalid=0; apkAssets=2 |
| APK asset URLs match release tag | OK | invalid=0; tag=v0.5.4-study.9 |
| APK asset URLs use GitHub HTTPS downloads | OK | invalid=0; prefix=https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/download/v0.5.4-study.9/ |
| APK asset URL filenames match names | OK | invalid=0; apkAssets=2 |
| APK asset content types are Android package archives | OK | invalid=0; expected=application/vnd.android.package-archive |
| all release APKs in installability report | OK | apkAssets=2 |
| all installability APKs in release | OK | reportApks=2 |
| APK asset digests match report | OK | apkAssets=2 |
| APK asset sizes match report | OK | apkAssets=2 |
| APK tooling checks passed | OK | zipalign/badging/signature/digest |
| permission review covers APKs | OK | apkAssets=2 |

## APK Assets

| Asset | Kind | Size | SHA-256 | Tooling | Permissions |
|---|---|---:|---|---|---|
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk` | debug-apk | 60307760 | `9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80` | zipalign=True; badging=True; signature=True | 20 permissions; 7 attention |
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk` | release-apk | 28193436 | `7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc` | zipalign=True; badging=True; signature=True | 20 permissions; 7 attention |

## Supporting Assets

| Asset | Kind | Size | Digest |
|---|---|---:|---|
| `apk-installability-report-v0.5.4-study.9.json` | installability-json | 41956 | `sha256:826313061bbe42ac85cb073fa752814a612ffbe3c069222b93883700fd9e3b30` |
| `apk-installability-report-v0.5.4-study.9.md` | installability-md | 1918 | `sha256:7e55e00320bbab608ca071a7451e5efc8bcebf01bd9386444d3d38800dbab14a` |
| `release-health-v0.5.4-study.9.md` | release-health | 2156 | `sha256:b141938019ba12b74aa87d0601e2056a4750f16ecb167a0c31036180bf16b630` |

## Boundary

- This manifest proves release asset consistency against archived APK installability and permission-review reports.
- It does not replace a real-device install matrix, privacy review, or production release-signing audit.
