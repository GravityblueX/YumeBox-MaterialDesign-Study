# YumeBox Study v0.5.4-study.9

本次继续把学习版 APK 发布链路做稳：重点不是新增页面，而是让 GitHub Release 上的 APK 下载后也能被复核、留档和追溯。

## 新增

- 新增 `scripts/apk-installability-report.ps1`。
  - 从 GitHub Release 下载 APK 资产。
  - 读取 GitHub Release asset digest。
  - 计算本地 APK SHA-256 并与远端 digest 比对。
  - 调用 Android SDK `zipalign`、`aapt dump badging` 和 `apksigner verify`。
  - 校验 package、versionName、versionCode 和 native ABI 是否匹配 `gradle.properties`。
  - 输出 Markdown 与 JSON 双报告。
- 新增 `docs/apk-release-assurance.md`，记录 APK 发布复核流程。

## 改进

- `RELEASE_STUDY.md` 增加可归档 APK 安装性报告步骤。
- 新增 v0.5.4-study.8 的安装性结构化报告，作为上一版 Release 资产复核样例。
- 版本升级到 `0.5.4-study.9` / `5409`。

## 验证

- `scripts/apk-installability-report.ps1 -Tag v0.5.4-study.8`
- `scripts/build-apk-strict.ps1`
- `scripts/build-apk-strict.ps1 -GradleTask ':app:assembleRelease' -LogName 'build-apk-release-strict.log'`
- `scripts/publish-apk-assets.ps1 -Tag v0.5.4-study.9`
- `scripts/verify-installable-apk.ps1 -FromRelease -Tag v0.5.4-study.9`
- `scripts/apk-installability-report.ps1 -Tag v0.5.4-study.9`

## 产物

- Debug APK：`YumeBox-Study-v0.5.4-study.9-arm64-v8a-debug.apk`
- Release APK：`YumeBox-Study-v0.5.4-study.9-arm64-v8a-release.apk`
- 发版体检报告：`release-health-v0.5.4-study.9.md`
- 安装性报告：`apk-installability-report-v0.5.4-study.9.md`
