# APK Permission Justification - v0.5.4-study.9

Generated: 2026-06-24T11:58:59.7864366+08:00
Status: `OK`
Review status: `review_required`
Permission review: `C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\docs\apk-permission-review-v0.5.4-study.9.json`

## Gates

| Gate | Result | Detail |
|---|---|---|
| permission review exists | OK | C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\docs\apk-permission-review-v0.5.4-study.9.json |
| permission review ok | OK | ok=True |
| permissions discovered | OK | 20 permission(s) |
| all permissions have justification | OK | 0 missing |
| attention permissions have production actions | OK | 0 missing |
| APK permission sets consistent | OK | 2 APK(s) |

## Permission Reasons

| Permission | Sensitivity | Category | User Benefit | Production Action |
|---|---|---|---|---|
| `android.permission.ACCESS_NETWORK_STATE` | normal | network-state | Detects network availability before starting proxy, profile refresh, or diagnostics work. | Keep; mention network-status use in privacy documentation. |
| `android.permission.ACCESS_WIFI_STATE` | normal | network-state | Reads Wi-Fi state for connection display and network-aware routing behavior. | Keep only if UI or routing features still consume Wi-Fi state. |
| `android.permission.CAMERA` | dangerous | runtime-sensitive | Supports QR/profile scanning from the onboarding and profile import flows. | Gate behind an explicit user action and request at runtime with scanner copy. |
| `android.permission.FOREGROUND_SERVICE` | normal | foreground-service | Keeps the proxy/VPN runtime visible and controllable while traffic handling is active. | Keep notification text accurate and user dismiss/stop controls obvious. |
| `android.permission.FOREGROUND_SERVICE_DATA_SYNC` | normal | foreground-service | Covers foreground profile/data synchronization while the service is active. | Keep scoped to active user-visible sync work. |
| `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` | special | special-foreground-service | Documents the special foreground service class needed by the proxy runtime mode. | Review Play/store-facing declaration before production release. |
| `android.permission.INTERNET` | normal | network | Allows profile fetch, proxy control, diagnostics, and web-based feature surfaces. | Keep; disclose network use and avoid sending private profile data unexpectedly. |
| `android.permission.MANAGE_EXTERNAL_STORAGE` | special | broad-storage | Supports importing, exporting, and managing local configuration assets during study builds. | Reduce scope before store release or provide a specific user-facing all-files rationale. |
| `android.permission.POST_NOTIFICATIONS` | dangerous | runtime-sensitive | Shows service status, traffic state, and important runtime notifications on modern Android. | Request at runtime and keep notification categories user-controllable. |
| `android.permission.PROCESS_OUTGOING_CALLS` | restricted | legacy-telephony | Legacy compatibility surface inherited by the fork; no core study APK flow should depend on it. | Remove unless a tested, documented feature still requires it. |
| `android.permission.QUERY_ALL_PACKAGES` | special | package-visibility | Supports app selection, access control, and package-aware proxy routing views. | Minimize with package visibility queries when possible and document the user feature. |
| `android.permission.READ_EXTERNAL_STORAGE` | dangerous | legacy-storage | Reads imported profile files on older Android versions. | Keep maxSdk scoped; prefer system picker on newer Android versions. |
| `android.permission.RECEIVE_BOOT_COMPLETED` | normal | startup | Allows user-enabled service restoration after reboot. | Keep behind explicit auto-start setting and respect disabled state. |
| `android.permission.REQUEST_INSTALL_PACKAGES` | special | package-install | Supports user-initiated local package/update flows in study builds. | Require user confirmation and remove if release distribution does not install packages. |
| `android.permission.USE_BIOMETRIC` | runtime-protected | authentication | Supports biometric lock or sensitive action confirmation. | Keep optional and provide fallback authentication. |
| `android.permission.USE_FINGERPRINT` | runtime-protected | legacy-authentication | Supports older devices that expose fingerprint APIs. | Keep only for compatibility; prefer USE_BIOMETRIC where available. |
| `android.permission.VIBRATE` | normal | haptics | Provides tactile feedback for switches, dialogs, and runtime controls. | Keep lightweight and respect system haptic settings. |
| `android.permission.WRITE_EXTERNAL_STORAGE` | dangerous | legacy-storage | Writes exported profile or diagnostic files on older Android versions. | Keep maxSdk scoped; prefer app-scoped storage or system picker. |
| `com.android.permission.GET_INSTALLED_APPS` | vendor-special | package-visibility | Supports package-aware routing on Android distributions that expose this vendor permission. | Confirm device/vendor need and remove if redundant with Android package visibility APIs. |
| `com.github.yizuka17.yumebox.md3.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | signature | app-private | Protects app-internal dynamic receiver traffic from other apps. | Keep as app-private protection for internal broadcast surfaces. |

## Boundary

- This report explains the study APK permission surface; it does not certify production mobile security.
- Special and dangerous permissions remain review-required before a public store release.
- Installability remains verified separately by zipalign, package metadata, signature, and digest checks.

