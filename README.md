# YumeBox MaterialDesign Study

This repository is a personal study fork for building and verifying a standard Android-installable YumeBox APK.

## Current Delivery Target

- Package type: APK.
- ABI focus: `arm64-v8a`.
- Current study release: `v0.5.4-study.9`.
- Main assurance docs:
  - `RELEASE_STUDY.md`
  - `docs/apk-release-assurance.md`
  - `docs/apk-installability-report-v0.5.4-study.9.md`
  - `release-health-v0.5.4-study.9.md`

## APK Verification

The release flow verifies that the APK can be recognized by the standard Android package tooling:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1 -GradleTask ':app:assembleRelease' -LogName 'build-apk-release-strict.log'
powershell -ExecutionPolicy Bypass -File .\scripts\verify-installable-apk.ps1 -FromRelease -Tag v0.5.4-study.9
powershell -ExecutionPolicy Bypass -File .\scripts\apk-installability-report.ps1 -Tag v0.5.4-study.9
powershell -ExecutionPolicy Bypass -File .\scripts\device-install-matrix.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\apk-permission-review.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\release-asset-manifest.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\release-provenance.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-environment-report.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\study-apk-contract.ps1
```

`study-apk-contract.ps1` is the fast local contract check for an already archived study release. It compares `gradle.properties` with the installability JSON report and verifies the recorded APK digest, `zipalign`, `aapt badging`, signing, package id, version, and ABI evidence.
By default it archives the contract to `docs/study-apk-contract-<tag>.md` and `docs/study-apk-contract-<tag>.json`.

`device-install-matrix.ps1` records the real-device layer above APK tooling checks. With connected owned or authorized Android devices it runs `adb install -r -t`; without devices it archives an explicit `no_devices` report instead of pretending a device install happened.

`apk-permission-review.ps1` reads the archived installability report and creates `docs/apk-permission-review-<tag>.md/json`, separating installability from the Android permission and privacy review layer.

`release-asset-manifest.ps1` reads GitHub Release assets plus the archived installability and permission reports, then creates `docs/release-asset-manifest-<tag>.md/json` with APK digest, size, debug/release channel, and tooling consistency checks.

`release-provenance.ps1` creates `docs/release-provenance-<tag>.md/json`, linking downloadable APK subjects to SHA-256 digests, git source commit, release asset manifest, and study build metadata.

`build-environment-report.ps1` creates `docs/build-environment-<tag>.md/json`, recording Java, Gradle wrapper, Android SDK, build-tools, app id, version, and ABI evidence for the study build.

`build-apk-strict.ps1` runs `zipalign`, `aapt dump badging`, and `apksigner verify` after the Gradle build. If the local study release build does not have a private release signing config, the script signs the APK with the local Android debug keystore and verifies it again so the resulting file is still installable for study/testing devices.

With a connected Android device or emulator, run the same installability check with `-Install` to perform a real package-manager install:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-installable-apk.ps1 -FromRelease -Tag v0.5.4-study.9 -Install
```

## Local Files

- `.vscode/` is local editor state and is intentionally ignored.
- `local.properties`, signing files, APKs, logs, and Gradle caches are not source artifacts.
- Release notes and assurance reports are tracked when they document a published study release.

## Safety Boundary

This fork is for local learning, build repair, APK packaging, and Android installation verification on devices you own or are authorized to use. Treat study APKs as test builds unless a private release signing process, device matrix, privacy review, and upgrade path have been separately completed.
