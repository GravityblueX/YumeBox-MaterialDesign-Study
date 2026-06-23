# APK Installability Audit - v0.5.4-study.8

Date: 2026-06-24

Release: https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/tag/v0.5.4-study.8

## Scope

This audit rechecked the APK assets downloaded from the GitHub Release, matching the path a normal user would use before installing on a standard Android device.

No APK contents were rebuilt or changed during this audit.

## Command

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-installable-apk.ps1 -FromRelease -Tag v0.5.4-study.8
```

## Result

Installable APK verification passed.

| Asset | Size | SHA-256 | zipalign | badging | signature |
| --- | ---: | --- | --- | --- | --- |
| `YumeBox-Study-v0.5.4-study.8-arm64-v8a-debug.apk` | 60,307,760 bytes | `ecca0766d2117b82d527ca3ee9efdf7518ccf8508abc1bdc4d361efb406abb7f` | OK | OK | OK, v2 |
| `YumeBox-Study-v0.5.4-study.8-arm64-v8a-release.apk` | 28,197,532 bytes | `9ea9283f0075c0e1aebd9f147997c8058d6c235d874764122f6b77cd4b892049` | OK | OK | OK, v2/v3 |

## APK Metadata

- package: `com.github.yizuka17.yumebox.md3`
- versionCode: `5408`
- versionName: `0.5.4-study.8`
- minSdk: `26`
- targetSdk: `37`
- compileSdk: `37`
- application label: `YumeBox Study MD3`
- native ABI: `arm64-v8a`

## Notes

- The APKs are structurally valid Android APK files and pass local installability checks available without a connected device.
- No connected Android device or emulator was available in this audit, so `adb install` was not executed.
- The `.vscode/` directory remains untracked and intentionally untouched.
