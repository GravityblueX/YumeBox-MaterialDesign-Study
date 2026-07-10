# YumeBox Study Release Flow

本地学习版发版按下面顺序执行。

## 前置条件

- JDK 24：`C:\Program Files\Eclipse Adoptium\jdk-24.0.2.12-hotspot`
- Android SDK 已可用，`local.properties` 指向本机 SDK
- 代理可用：`http://127.0.0.1:7897`
- `gh auth status` 正常，已登录 GitHub CLI
- 建议使用独立 Gradle 缓存：`D:\GradleCache-YumeBoxStudy`

## 发版步骤

1. 更新 `gradle.properties`
   - `project.version.name`
   - `project.version.code`
2. 准备 release notes，例如 `release-notes-v0.5.4-study.9.md`
3. 提交代码并推送分支
4. 创建并推送 tag
   - `git tag v0.5.4-study.9`
   - `git push origin v0.5.4-study.9`
5. 本地构建 APK

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1 -GradleTask ':app:assembleRelease' -LogName 'build-apk-release-strict.log'
```

`build-apk-strict.ps1` 会在构建后调用 Android SDK 检查 APK 是否达到安装就绪状态：`zipalign -c`、`aapt dump badging` 和 `apksigner verify`。若学习版 release APK 未配置正式 `signing.properties` 而导致未签名，脚本会使用本机 Android debug keystore 兜底签名，并再次验签；正式发布前请配置私有 release keystore。

`build-apk-strict.ps1` 会在构建前检查项目盘和 Gradle 缓存盘空间。空间不足时可用 `-GradleUserHome <路径>` 移动缓存，或用 `-MinGradleDriveFreeGb <GB>` 调整本机学习构建的缓存盘阈值。

6. 生成发版体检报告

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release-health.ps1 -Tag v0.5.4-study.9
```

它会检查 `gradle.properties`、debug/release APK 文件、APK zipalign、manifest/badging、APK 签名、SHA-256、git 状态和 GitHub Release 资产。

任一体检项失败时，脚本会在终端错误流输出失败检查名，并以非零退出码停止，报告中对应行标记为 `FAIL`。

7. 验证 APK 下载后可被 Android 安装器识别

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\device-install-matrix.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\apk-installability-report.ps1 -Tag v0.5.4-study.9
powershell -ExecutionPolicy Bypass -File .\scripts\apk-permission-review.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\release-asset-manifest.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\release-provenance.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-environment-report.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\study-apk-contract.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-installable-apk.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-installable-apk.ps1 -FromRelease -Tag v0.5.4-study.9
```

`study-apk-contract.ps1` 是快速合同检查：读取 `gradle.properties` 和已归档的安装性 JSON 报告，确认版本、包名、ABI、GitHub digest、zipalign、badging 和签名证据一致。默认会归档 `docs\study-apk-contract-<tag>.md` 和 `docs\study-apk-contract-<tag>.json`。

`device-install-matrix.ps1` 是真机/模拟器安装矩阵层：有已连接且授权的设备时执行 `adb install -r -t`，没有设备时归档 `no_devices` 报告，避免把工具链安装性验证误写成真机安装验证。需要强制真机门禁时追加 `-RequireDevice`。

`apk-permission-review.ps1` 是权限复核层：读取安装性报告里的 `aapt badging` 权限清单，列出需要人工说明的敏感或特殊权限，避免把“能安装”误写成“已完成生产安全审计”。

`release-asset-manifest.ps1` 是发布资产账本层：读取 GitHub Release 资产、安装性报告和权限复核报告，确认 debug/release APK 的大小、SHA-256、GitHub digest、安装性证据和权限复核记录一致。

`release-provenance.ps1` 是发布来源声明层：记录可下载 APK subject、SHA-256、git 源提交、发布资产账本和学习版构建元数据，方便以后追溯“这个 APK 从哪里来”。

`build-environment-report.ps1` 是构建环境账本层：记录 Java、Gradle wrapper、Android SDK、build-tools、app id、版本和 ABI，让 APK 证据不只停留在产物层。

有真机或模拟器连接时，可以追加 `-Install` 做真实安装验证：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-installable-apk.ps1 -FromRelease -Tag v0.5.4-study.9 -Install
```

8. 生成可归档的 APK 安装性报告

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apk-installability-report.ps1 -Tag v0.5.4-study.9
```

该脚本会从 GitHub Release 下载 APK，比较本地 SHA-256 与 GitHub Release asset digest，并输出 Markdown/JSON 双报告。默认报告路径：

```text
docs\apk-installability-report-v0.5.4-study.9.md
docs\apk-installability-report-v0.5.4-study.9.json
```

9. 创建或更新 GitHub Release

```bash
gh release create v0.5.4-study.9 --repo GravityblueX/YumeBox-MaterialDesign-Study --title "YumeBox Study v0.5.4-study.9" --notes-file release-notes-v0.5.4-study.9.md
```

如果 Release 已存在，只上传 APK：

```bat
scripts\upload-apk.bat v0.5.4-study.9
```

推荐使用 PowerShell 发布脚本上传标准命名资产：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish-apk-assets.ps1 -Tag v0.5.4-study.9
```

## 产物与日志

- 默认 Debug APK 路径：`app\build\outputs\apk\debug\YumeBox Study-arm64-v8a-debug.apk`
- 默认 Release APK 路径：`app\build\outputs\apk\release\YumeBox Study-arm64-v8a-release.apk`
- 构建日志：`build-apk-strict.log`
- 发版体检报告：`release-health-v*.md`
- 安装就绪验证：`scripts\verify-installable-apk.ps1`
- 可归档安装性报告：`docs\apk-installability-report-v*.md` 和 `docs\apk-installability-report-v*.json`
- 发布资产账本：`docs\release-asset-manifest-v*.md` 和 `docs\release-asset-manifest-v*.json`
- 发布来源声明：`docs\release-provenance-v*.md` 和 `docs\release-provenance-v*.json`
- 构建环境账本：`docs\build-environment-v*.md` 和 `docs\build-environment-v*.json`

## 说明

- `scripts/build-apk-strict.ps1` 会自动设置 `JAVA_HOME`、`GRADLE_USER_HOME` 和代理。
- 构建前空间检查同时覆盖项目盘和 Gradle 缓存盘；必要时使用 `-GradleUserHome` 和 `-MinGradleDriveFreeGb` 调整。
- 当前固定上传学习版 `arm64-v8a` debug/release APK，适合自测和学习。
- 更多细节见 `docs\apk-release-assurance.md`。
