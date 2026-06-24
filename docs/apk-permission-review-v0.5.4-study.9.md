# APK Permission Review - v0.5.4-study.9

Generated: 2026-06-24T11:02:00.1720842+08:00
Status: `review_required`
Installability report: `C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\docs\apk-installability-report-v0.5.4-study.9.json`

## APK Summary

| APK | Permissions | Attention Items |
|---|---:|---:|
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk` | 20 | 7 |
| `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk` | 20 | 7 |

## Attention Items

- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk`: `android.permission.CAMERA` - runtime sensitive permission; confirm scanner/onboarding flow
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk`: `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` - special foreground service declaration; confirm store-facing explanation
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk`: `android.permission.MANAGE_EXTERNAL_STORAGE` - broad file access; production release needs explicit user-facing justification
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk`: `android.permission.POST_NOTIFICATIONS` - runtime notification permission on modern Android
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk`: `android.permission.PROCESS_OUTGOING_CALLS` - legacy sensitive telephony permission; confirm compatibility need
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk`: `android.permission.QUERY_ALL_PACKAGES` - broad package visibility; keep scoped and documented
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk`: `android.permission.REQUEST_INSTALL_PACKAGES` - package install request permission; verify user-initiated flow
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk`: `android.permission.CAMERA` - runtime sensitive permission; confirm scanner/onboarding flow
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk`: `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` - special foreground service declaration; confirm store-facing explanation
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk`: `android.permission.MANAGE_EXTERNAL_STORAGE` - broad file access; production release needs explicit user-facing justification
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk`: `android.permission.POST_NOTIFICATIONS` - runtime notification permission on modern Android
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk`: `android.permission.PROCESS_OUTGOING_CALLS` - legacy sensitive telephony permission; confirm compatibility need
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk`: `android.permission.QUERY_ALL_PACKAGES` - broad package visibility; keep scoped and documented
- `YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk`: `android.permission.REQUEST_INSTALL_PACKAGES` - package install request permission; verify user-initiated flow

## Boundary

- This report is a study-build permission review, not a production mobile security certification.
- Installability remains covered by zipalign, badging, signature, digest, and optional device-install reports.
- Production release requires a separate privacy, permission, and upgrade-path review.
