# APK Installability Report - v0.5.4-study.9

Generated: 2026-06-24T07:56:23.3138243+08:00
Repository: `GravityblueX/YumeBox-MaterialDesign-Study`
Release: https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/tag/v0.5.4-study.9
Android SDK: `C:\Users\123\AppData\Local\Android\Sdk`
Build tools: `C:\Users\123\AppData\Local\Android\Sdk\build-tools\36.0.0`

## Result

Installability report passed.

## APK Assets

| APK | Size | SHA-256 | GitHub digest | Digest match | zipalign | badging | signature |
|---|---:|---|---|---|---|---|---|
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk` | 57.51 MB | `9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80` | `sha256:9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80` | OK | OK | OK | OK (v2=True, v3=False) |
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk` | 26.89 MB | `7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc` | `sha256:7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc` | OK | OK | OK | OK (v2=True, v3=True) |

## Metadata

| APK | Package | Version | SDK | Label | Native ABI |
|---|---|---|---|---|---|
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk` | `com.github.yizuka17.yumebox.md3` | `0.5.4-study.9 / 5409` | min 26, target 37, compile 37 | YumeBox Study MD3 | `arm64-v8a` |
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk` | `com.github.yizuka17.yumebox.md3` | `0.5.4-study.9 / 5409` | min 26, target 37, compile 37 | YumeBox Study MD3 | `arm64-v8a` |

## Failures

- none

## Notes

- This report checks APK files downloaded from the GitHub Release.
- It compares local SHA-256 values with GitHub Release asset digests when available.
- It validates Android installability signals with zipalign, aapt badging, and apksigner.
- It does not run `adb install`; use `verify-installable-apk.ps1 -Install` with a connected device for that final check.

