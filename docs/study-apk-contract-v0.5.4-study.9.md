# Study APK Contract - v0.5.4-study.9

Generated: 2026-07-15T16:45:55.8114534+08:00
ProjectRoot: `C:\Users\123\Desktop\YumeBox-MaterialDesign-Study`
Status: `OK`

## Summary

| Field | Value |
|---|---|
| Check count | 237 |
| Failure count | 0 |
| Required files | 28 |
| APK evidence count | 2 |
| Release APK asset count | 2 |
| Provenance subject count | 2 |
| Device matrix status | `no_devices` |
| Permission review status | `review_required` |

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
| study contract emits summary section | OK | summary section |
| study contract records failure count | OK | summary failure count |
| study contract writes UTF-8 without BOM | OK | UTF-8 no BOM writer |
| study contract normalizes SHA-256 digests | OK | digest normalization |
| study contract cross-checks provenance APK names | OK | provenance asset name parity |
| study contract cross-checks provenance APK digests | OK | provenance asset digest parity |
| study contract cross-checks provenance material digests | OK | provenance material digest parity |
| study contract checks release health markdown | OK | release health markdown |
| study contract cross-checks release health APK digests | OK | release health APK digests |
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
| release provenance records dirty count | OK | dirty count evidence |
| release provenance writes UTF-8 without BOM | OK | UTF-8 no BOM writer |
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
| release asset manifest gates canonical APK digests | OK | canonical digest gate |
| release asset manifest gates release-tag APK URLs | OK | release URL gate |
| release asset manifest writes UTF-8 without BOM | OK | UTF-8 no BOM writer |
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
| CI channel skips study contract script | OK | paths-ignore |
| PR CI skips study contract script | OK | paths-ignore |
| release evidence contract covers PowerShell scripts | OK | release evidence paths |
| release evidence contract accumulates script parse failures | OK | parse failure collection |
| release evidence contract reports parse error locations | OK | parse error location |
| release evidence contract asserts markdown report exists | OK | markdown report existence |
| release evidence contract asserts JSON report type | OK | JSON reportType |
| release evidence contract asserts summary check count | OK | summary check count parity |
| release evidence contract asserts zero failure summary | OK | summary failure count |
| release evidence contract asserts markdown title tag | OK | markdown title/tag parity |
| release evidence contract asserts markdown OK status | OK | markdown OK status |
| release evidence contract asserts markdown check count | OK | markdown check count parity |
| release evidence contract asserts markdown failure count | OK | markdown failure count parity |
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
| release asset manifest gates recorded | OK | 20 gates |
| release asset manifest gate passes: APK asset digests are canonical SHA-256 | OK | invalid=0; apkAssets=2 |
| release asset manifest gate passes: APK asset URLs match release tag | OK | invalid=0; tag=v0.5.4-study.9 |
| release asset manifest includes release health report | OK | release-health-v0.5.4-study.9.md |
| release health asset digest recorded | OK | sha256:b141938019ba12b74aa87d0601e2056a4750f16ecb167a0c31036180bf16b630 |
| release health asset URL matches tag | OK | https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/releases/download/v0.5.4-study.9/release-health-v0.5.4-study.9.md |
| release health asset has stable size | OK | 2156 bytes |
| release health markdown exists | OK | release-health-v0.5.4-study.9.md |
| release health markdown tag matches | OK | tag=v0.5.4-study.9 |
| release health markdown has checks section | OK | ## Checks |
| release health markdown records no failed checks | OK | no FAIL rows |
| release health markdown lists APK digest YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk | OK | 7f7fb26716ab10333121e615421f79be76a2f32c3857a2e4631d4a6a3a760cdc |
| release health markdown lists APK digest YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk | OK | 9aa9c71d0de27ac08a0d224da6a40dff2baf8428013115b3590a593931a1ab80 |
| release provenance ok flag | OK | ok=True |
| release provenance tag matches | OK | tag=v0.5.4-study.9 |
| release provenance predicate recorded | OK | https://slsa.dev/provenance/v1 |
| release provenance APK subjects | OK | 2 subject(s) |
| release provenance links build environment | OK | build-environment-v0.5.4-study.9.json |
| release provenance links permission justification | OK | apk-permission-justification-v0.5.4-study.9.json |
| release provenance material digest matches release asset manifest | OK | recorded=fc42a0f5d6150f61e4a7b86dc82cc6897904889c3eb6180e19482434336aa551, actual=fc42a0f5d6150f61e4a7b86dc82cc6897904889c3eb6180e19482434336aa551 |
| release provenance material digest matches build environment | OK | recorded=29d4d88fc9d071042b7d0bf3954185eb8287ffc2afbb438394bfa6cc15286c1b, actual=29d4d88fc9d071042b7d0bf3954185eb8287ffc2afbb438394bfa6cc15286c1b |
| release provenance material digest matches permission justification | OK | recorded=38fdb803ebae0fc50412335dabc289a02c8f9c81b816b55e71afad5d4e5fa08b, actual=38fdb803ebae0fc50412335dabc289a02c8f9c81b816b55e71afad5d4e5fa08b |
| build environment ok flag | OK | ok=True |
| build environment tag matches | OK | tag=v0.5.4-study.9 |
| build environment version matches gradle | OK | 0.5.4-study.9/5409 |
| build environment build-tools recorded | OK | 36.0.0 |
| provenance APK comparison evidence present | OK | assets=2, subjects=2 |
| provenance APK subjects match release asset names | OK | assets=2, subjects=2 |
| provenance APK digests match release assets | OK | matched=2 |
