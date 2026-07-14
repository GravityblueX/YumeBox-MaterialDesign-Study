# YumeBox Study Release Health

Generated: 2026-06-24T07:55:53.4061923+08:00
Repository: `GravityblueX/YumeBox-MaterialDesign-Study`
Branch: `Yume`
Commit: `1d8e3ff2891b17a6fbce571d8cf39d2456755cae`
Version: `0.5.4-study.9` / `5409`
Tag: `v0.5.4-study.9`

## Checks

| Check | Status | Detail |
|---|---|---|
| gradle version name | OK | 0.5.4-study.9 |
| gradle version code | OK | 5409 |
| APK exists | OK | 2 APK file(s) |
| APK signatures | OK | apksigner verify passed |
| APK zipalign | OK | zipalign check passed |
| APK badging | OK | aapt badging passed |
| tracked git files clean | OK | clean |
| GitHub release visible | OK | https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/tag/v0.5.4-study.9 |

## APK

| File | Size | SHA-256 | Signature | Zipalign | Badging | Last Modified |
|---|---:|---|---|---|---|---|
| .\app\build\outputs\apk\debug\YumeBox Study-arm64-v8a-debug.apk | 57.51 MB | `9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80` | OK (C=US, O=Android, CN=Android Debug) | OK | OK (native-code: 'arm64-v8a') | 2026-06-24T07:40:18.7599140+08:00 |
| .\app\build\outputs\apk\release\YumeBox Study-arm64-v8a-release.apk | 26.89 MB | `7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc` | OK (C=US, O=Android, CN=Android Debug) | OK | OK (native-code: 'arm64-v8a') | 2026-06-24T07:51:25.4577574+08:00 |

## Release Assets

| Asset | Size | Digest |
|---|---:|---|
| YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk | 57.51 MB | sha256:9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80 |
| YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk | 26.89 MB | sha256:7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc |

## Next Commands

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1 -GradleTask ':app:assembleRelease' -LogName 'build-apk-release-strict.log'
powershell -ExecutionPolicy Bypass -File .\scripts\publish-apk-assets.ps1 -Tag v0.5.4-study.9
powershell -ExecutionPolicy Bypass -File .\scripts\release-health.ps1 -Tag v0.5.4-study.9
```

