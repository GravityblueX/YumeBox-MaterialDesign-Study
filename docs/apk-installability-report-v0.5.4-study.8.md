# APK Installability Report - v0.5.4-study.8

Generated: 2026-06-24T07:26:35.8867322+08:00
Repository: `GravityblueX/YumeBox-MaterialDesign-Study`
Release: https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/tag/v0.5.4-study.8
Android SDK: `C:\Users\123\AppData\Local\Android\Sdk`
Build tools: `C:\Users\123\AppData\Local\Android\Sdk\build-tools\36.0.0`

## Result

Installability report passed.

## APK Assets

| APK | Size | SHA-256 | GitHub digest | Digest match | zipalign | badging | signature |
|---|---:|---|---|---|---|---|---|
| `YumeBox-Study-v0.5.4-study.8-arm64-v8a-debug.apk` | 57.51 MB | `ecca0766d2117b82d527ca3ee9efdf7518ccf8508abc1bdc4d361efb406abb7f` | `sha256:ecca0766d2117b82d527ca3ee9efdf7518ccf8508abc1bdc4d361efb406abb7f` | OK | OK | OK | OK (v2=True, v3=False) |
| `YumeBox-Study-v0.5.4-study.8-arm64-v8a-release.apk` | 26.89 MB | `9ea9283f0075c0e1aebd9f147997c8058d6c235d874764122f6b77cd4b892049` | `sha256:9ea9283f0075c0e1aebd9f147997c8058d6c235d874764122f6b77cd4b892049` | OK | OK | OK | OK (v2=True, v3=True) |

## Metadata

| APK | Package | Version | SDK | Label | Native ABI |
|---|---|---|---|---|---|
| `YumeBox-Study-v0.5.4-study.8-arm64-v8a-debug.apk` | `com.github.yizuka17.yumebox.md3` | `0.5.4-study.8 / 5408` | min 26, target 37, compile 37 | YumeBox Study MD3 | `arm64-v8a` |
| `YumeBox-Study-v0.5.4-study.8-arm64-v8a-release.apk` | `com.github.yizuka17.yumebox.md3` | `0.5.4-study.8 / 5408` | min 26, target 37, compile 37 | YumeBox Study MD3 | `arm64-v8a` |

## Failures

- none

## Notes

- This report checks APK files downloaded from the GitHub Release.
- It compares local SHA-256 values with GitHub Release asset digests when available.
- It validates Android installability signals with zipalign, aapt badging, and apksigner.
- It does not run `adb install`; use `verify-installable-apk.ps1 -Install` with a connected device for that final check.

