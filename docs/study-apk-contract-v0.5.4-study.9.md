# Study APK Contract - v0.5.4-study.9

Generated: 2026-07-11T04:18:26.7115893+08:00
ProjectRoot: `C:\Users\123\Desktop\YumeBox-MaterialDesign-Study`
Status: `OK`

## Checks

| Check | Result | Detail |
|---|---|---|
| gradle.properties exists | OK | C:\Users\123\Desktop\YumeBox-MaterialDesign-Study\gradle.properties |
| version name present | OK | 0.5.4-study.9 |
| version code present | OK | 5409 |
| application id present | OK | com.github.yizuka17.yumebox.md3 |
| arm64 ABI configured | OK | arm64-v8a |
| required file README.md | OK | README.md |
| required file RELEASE_STUDY.md | OK | RELEASE_STUDY.md |
| required file docs\apk-release-assurance.md | OK | docs\apk-release-assurance.md |
| required file release-health-v0.5.4-study.9.md | OK | release-health-v0.5.4-study.9.md |
| required file docs\apk-installability-report-v0.5.4-study.9.md | OK | docs\apk-installability-report-v0.5.4-study.9.md |
| required file docs\apk-installability-report-v0.5.4-study.9.json | OK | docs\apk-installability-report-v0.5.4-study.9.json |
| required file docs\device-install-matrix-v0.5.4-study.9.md | OK | docs\device-install-matrix-v0.5.4-study.9.md |
| required file docs\device-install-matrix-v0.5.4-study.9.json | OK | docs\device-install-matrix-v0.5.4-study.9.json |
| required file docs\apk-permission-review-v0.5.4-study.9.md | OK | docs\apk-permission-review-v0.5.4-study.9.md |
| required file docs\apk-permission-review-v0.5.4-study.9.json | OK | docs\apk-permission-review-v0.5.4-study.9.json |
| required file docs\apk-permission-justification-v0.5.4-study.9.md | OK | docs\apk-permission-justification-v0.5.4-study.9.md |
| required file docs\apk-permission-justification-v0.5.4-study.9.json | OK | docs\apk-permission-justification-v0.5.4-study.9.json |
| required file docs\release-asset-manifest-v0.5.4-study.9.md | OK | docs\release-asset-manifest-v0.5.4-study.9.md |
| required file docs\release-asset-manifest-v0.5.4-study.9.json | OK | docs\release-asset-manifest-v0.5.4-study.9.json |
| required file docs\release-provenance-v0.5.4-study.9.md | OK | docs\release-provenance-v0.5.4-study.9.md |
| required file docs\release-provenance-v0.5.4-study.9.json | OK | docs\release-provenance-v0.5.4-study.9.json |
| required file docs\build-environment-v0.5.4-study.9.md | OK | docs\build-environment-v0.5.4-study.9.md |
| required file docs\build-environment-v0.5.4-study.9.json | OK | docs\build-environment-v0.5.4-study.9.json |
| required file scripts\build-apk-strict.ps1 | OK | scripts\build-apk-strict.ps1 |
| required file scripts\verify-installable-apk.ps1 | OK | scripts\verify-installable-apk.ps1 |
| required file scripts\release-health.ps1 | OK | scripts\release-health.ps1 |
| required file scripts\apk-installability-report.ps1 | OK | scripts\apk-installability-report.ps1 |
| required file scripts\device-install-matrix.ps1 | OK | scripts\device-install-matrix.ps1 |
| required file scripts\apk-permission-review.ps1 | OK | scripts\apk-permission-review.ps1 |
| required file scripts\apk-permission-justification.ps1 | OK | scripts\apk-permission-justification.ps1 |
| required file scripts\release-asset-manifest.ps1 | OK | scripts\release-asset-manifest.ps1 |
| required file scripts\release-provenance.ps1 | OK | scripts\release-provenance.ps1 |
| required file scripts\build-environment-report.ps1 | OK | scripts\build-environment-report.ps1 |
| required file scripts\publish-apk-assets.ps1 | OK | scripts\publish-apk-assets.ps1 |
| study contract pads boundary code span backticks | OK | boundary backtick padding |
| strict build filters APKs by Gradle task | OK | Get-ApkNamePatternForGradleTask |
| strict build logs APK name pattern | OK | ApkNamePattern log |
| strict build preserves Gradle exit code | OK | exit $code |
| strict build creates Gradle cache dir | OK | GRADLE_USER_HOME mkdir |
| strict build supports ambient JAVA_HOME fallback | OK | ambient JAVA_HOME |
| strict build exposes Gradle cache relocation | OK | GradleUserHome parameter |
| strict build logs Gradle cache home | OK | GRADLE_USER_HOME log |
| strict build enforces Gradle cache free space | OK | MinGradleDriveFreeGb |
| release health requests release assets | OK | gh release assets |
| release health records asset digests | OK | asset digest |
| release health records APK SHA-256 | OK | APK SHA-256 |
| release health omits itself from asset table | OK | skip OutputName |
| release health marks failed checks as FAIL | OK | FAIL status |
| release health collects failed checks | OK | failedChecks |
| release health exits nonzero on failure | OK | exit 1 on failures |
| release health captures GitHub release errors | OK | gh release stderr |
| release health has release error fallback | OK | release error fallback |
| release health only falls back when release is missing | OK | fallback requires missing release |
| release health prints failed check names | OK | failed check summary |
| release health failure summary preserves explicit exit | OK | stderr without Write-Error termination |
| release health escapes markdown table cells | OK | table cell escaping |
| release health escapes check details | OK | check detail escaping |
| release health escapes APK status fields | OK | APK status escaping |
| release health formats markdown code spans | OK | code span fencing |
| release health code-spans APK SHA-256 | OK | APK SHA-256 code span |
| release health pads boundary code span backticks | OK | boundary backtick padding |
| release health code-spans repository header | OK | repository header code span |
| release health code-spans version header | OK | version header code span |
| release health code-spans tag header | OK | tag header code span |
| installability report escapes markdown table cells | OK | table cell escaping |
| installability report escapes APK status cells | OK | status escaping |
| installability report escapes metadata labels | OK | label escaping |
| installability report formats markdown code spans | OK | code span fencing |
| installability report code-spans APK names | OK | APK name code span |
| installability report pads boundary code span backticks | OK | boundary backtick padding |
| installability report code-spans repository header | OK | repository header code span |
| installability report code-spans Android SDK header | OK | Android SDK header code span |
| installability report code-spans build tools header | OK | build tools header code span |
| installability report code-spans SHA-256 values | OK | SHA-256 code span |
| installability report code-spans GitHub digests | OK | GitHub digest code span |
| installability report code-spans package names | OK | package name code span |
| release provenance escapes markdown table cells | OK | table cell escaping |
| release provenance formats subject names as code spans | OK | subject name code span |
| release provenance escapes gate details | OK | gate detail escaping |
| release provenance formats markdown code spans | OK | code span fencing |
| release provenance code-spans APK digests | OK | digest code span |
| release provenance code-spans predicate header | OK | predicate header code span |
| release provenance pads boundary code span backticks | OK | boundary backtick padding |
| release provenance code-spans repository header | OK | repository header code span |
| release provenance code-spans status header | OK | status header code span |
| release provenance code-spans source commit header | OK | source commit header code span |
| release provenance code-spans package names | OK | package code span |
| release asset manifest escapes markdown table cells | OK | table cell escaping |
| release asset manifest escapes newlines | OK | newline escaping |
| release asset manifest escapes APK asset kind | OK | asset kind escaping |
| release asset manifest formats markdown code spans | OK | code span fencing |
| release asset manifest code-spans APK asset names | OK | asset name code span |
| release asset manifest code-spans repository header | OK | repository header code span |
| release asset manifest pads boundary code span backticks | OK | boundary backtick padding |
| release asset manifest code-spans release header | OK | release header code span |
| release asset manifest code-spans status header | OK | status header code span |
| release asset manifest code-spans APK asset digests | OK | APK digest code span |
| release asset manifest code-spans supporting asset digests | OK | supporting digest code span |
| build environment report escapes markdown table cells | OK | table cell escaping |
| build environment report escapes newlines | OK | newline escaping |
| build environment report escapes gate details | OK | gate detail escaping |
| build environment report formats markdown code spans | OK | code span fencing |
| build environment report code-spans SDK root | OK | SDK root code span |
| build environment report pads boundary code span backticks | OK | boundary backtick padding |
| build environment report code-spans command output | OK | command output code span |
| permission review escapes markdown table cells | OK | table cell escaping |
| permission review escapes markdown text | OK | inline text escaping |
| permission review escapes attention reasons | OK | attention reason escaping |
| permission review formats markdown code spans | OK | code span fencing |
| permission review code-spans APK summary names | OK | APK summary code span |
| permission review code-spans attention permissions | OK | attention permission code span |
| permission review pads boundary code span backticks | OK | boundary backtick padding |
| permission review code-spans status header | OK | status header code span |
| permission review code-spans installability report path | OK | installability path code span |
| permission review removes fixed attention code spans | OK | no fixed attention code span |
| permission review removes fixed summary code spans | OK | no fixed summary code span |
| permission justification escapes markdown table cells | OK | table cell escaping |
| permission justification accepts object table cells | OK | object-to-string normalization |
| permission justification formats markdown code spans | OK | code span fencing |
| permission justification code-spans status header | OK | status header code span |
| permission justification code-spans review path | OK | review path code span |
| permission justification pads boundary code span backticks | OK | boundary backtick padding |
| permission justification escapes gate names | OK | gate name escaping |
| permission justification escapes gate details | OK | gate detail escaping |
| permission justification escapes permission names | OK | permission name escaping |
| device install matrix escapes markdown inline values | OK | inline escaping |
| device install matrix escapes APK path | OK | APK path escaping |
| device install matrix escapes application id | OK | application id escaping |
| device install matrix escapes version text | OK | version escaping |
| device install matrix escapes device serials | OK | serial escaping |
| device install matrix captures native command output | OK | native command capture |
| device install matrix captures adb devices stderr | OK | adb devices capture |
| device install matrix captures adb install stderr | OK | adb install capture |
| device install matrix formats markdown code spans | OK | code span fencing |
| device install matrix code-spans APK path | OK | APK path code span |
| device install matrix pads boundary code span backticks | OK | boundary backtick padding |
| device install matrix code-spans device serials | OK | device serial code span |
| device install matrix preserves RequireDevice code span | OK | RequireDevice code span |
| README mentions tag | OK | v0.5.4-study.9 |
| release flow mentions installability | OK | verify-installable-apk.ps1 |
| README documents Gradle cache relocation | OK | GradleUserHome |
| README documents Gradle cache threshold | OK | MinGradleDriveFreeGb |
| release flow documents Gradle cache relocation | OK | GradleUserHome |
| release flow documents Gradle cache threshold | OK | MinGradleDriveFreeGb |
| release flow documents release health failure summary | OK | release-health stderr summary |
| report ok flag | OK | ok=True |
| report tag matches | OK | tag=v0.5.4-study.9 |
| report package matches gradle | OK | com.github.yizuka17.yumebox.md3 |
| report version name matches gradle | OK | 0.5.4-study.9 |
| report version code matches gradle | OK | 5409 |
| report has debug and release APKs | OK | 2 APKs |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk digest matches | OK | sha256:9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80 |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk zipalign | OK | OK |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk badging | OK | OK |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk signature | OK | C=US, O=Android, CN=Android Debug |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk package metadata | OK | com.github.yizuka17.yumebox.md3 |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk version metadata | OK | 0.5.4-study.9/5409 |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk ABI metadata | OK | arm64-v8a |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk digest matches | OK | sha256:7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk zipalign | OK | OK |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk badging | OK | OK |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk signature | OK | C=US, O=Android, CN=Android Debug |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk package metadata | OK | com.github.yizuka17.yumebox.md3 |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk version metadata | OK | 0.5.4-study.9/5409 |
| APK YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk ABI metadata | OK | arm64-v8a |
| release health tag matches | OK | v0.5.4-study.9 |
| release health version matches gradle | OK | Version: `0.5.4-study.9` / `5409` |
| release health APK count matches report | OK | 2 APK file(s) |
| release health records APK signatures OK | OK | APK signatures |
| release health records APK zipalign OK | OK | APK zipalign |
| release health records APK badging OK | OK | APK badging |
| release health records GitHub release visible | OK | GitHub release visible |
| release health release URL matches report | OK | https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/tag/v0.5.4-study.9 |
| release health lists YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk | OK | YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk |
| release health records YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk SHA-256 | OK | 9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80 |
| release health records YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk asset digest | OK | sha256:9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80 |
| release health lists YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk | OK | YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk |
| release health records YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk SHA-256 | OK | 7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc |
| release health records YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk asset digest | OK | sha256:7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc |
| device install matrix ok flag | OK | ok=True |
| device install matrix tag matches | OK | tag=v0.5.4-study.9 |
| device install matrix package matches gradle | OK | com.github.yizuka17.yumebox.md3 |
| device install matrix version matches gradle | OK | 0.5.4-study.9/5409 |
| device install matrix status recorded | OK | status=no_devices |
| device install matrix result boundary | OK | status=no_devices, devices=0, results=0 |
| permission review ok flag | OK | ok=True |
| permission review tag matches | OK | tag=v0.5.4-study.9 |
| permission review status recorded | OK | status=review_required |
| permission review covers APKs | OK | 2 APKs |
| permission justification ok flag | OK | ok=True |
| permission justification tag matches | OK | tag=v0.5.4-study.9 |
| permission justification covers permissions | OK | 20 permission(s) |
| permission justification has gates | OK | 6 gates |
| release asset manifest ok flag | OK | ok=True |
| release asset manifest tag matches | OK | tag=v0.5.4-study.9 |
| release asset manifest APK assets | OK | debug=1, release=1 |
| release asset manifest gates recorded | OK | 18 gates |
| release provenance ok flag | OK | ok=True |
| release provenance tag matches | OK | tag=v0.5.4-study.9 |
| release provenance predicate recorded | OK | https://slsa.dev/provenance/v1 |
| release provenance APK subjects | OK | 2 subject(s) |
| release provenance links build environment | OK | build-environment-v0.5.4-study.9.json |
| release provenance links permission justification | OK | apk-permission-justification-v0.5.4-study.9.json |
| build environment ok flag | OK | ok=True |
| build environment tag matches | OK | tag=v0.5.4-study.9 |
| build environment version matches gradle | OK | 0.5.4-study.9/5409 |
| build environment build-tools recorded | OK | 36.0.0 |

