# YumeBox Study v0.5.4-study.8

本次把学习版发版流程继续做厚：从“能构建、能上传”推进到“能体检、能留档、能校验资产”。

## 新增

- 新增 `scripts/release-health.ps1` 发版体检脚本。
  - 读取 `gradle.properties` 中的版本名和版本号。
  - 检查默认 APK 是否存在。
  - 计算 APK SHA-256。
  - 汇总当前 git 分支、提交和工作区状态。
  - 查询 GitHub Release 资产清单。
  - 生成 `release-health-v*.md` 报告。
- 新增 `scripts/publish-apk-assets.ps1` APK 发布脚本。
  - 复制 debug/release APK 为无空格标准资产名。
  - 上传 APK 到 GitHub Release。
  - 上传后刷新并发布体检报告。
- `scripts/build-apk-strict.ps1` 增加 APK 安装就绪校验。
  - 构建后自动调用 Android SDK `zipalign -c`、`aapt dump badging` 和 `apksigner verify`。
  - 学习版 release APK 若未配置正式签名，会使用本机 Android debug keystore 兜底签名并二次验签。
- 新增 `scripts/verify-installable-apk.ps1`。
  - 可验证本地 APK，也可用 `-FromRelease` 直接下载 GitHub Release 资产后验证。
  - 有真机或模拟器时可用 `-Install` 执行 `adb install` 真实安装验证。

## 改进

- 首页 `ReleasePipelineCard` 增加发版体检步骤。
- 设置页 Infra Lab 增加发版体检说明。
- `RELEASE_STUDY.md` 补充构建后签名校验和体检流程。
- `scripts/release-health.ps1` 把 APK zipalign、badging 和签名状态纳入报告。
- 学习版更新日志补充 v0.5.4-study.8 条目。
- 版本升级到 `0.5.4-study.8` / `5408`。

## 验证

- `scripts/build-apk-strict.ps1`
- `scripts/build-apk-strict.ps1 -GradleTask ':app:assembleRelease' -LogName 'build-apk-release-strict.log'`
- `scripts/release-health.ps1 -Tag v0.5.4-study.8`
- Android SDK `apksigner verify` for debug/release APKs
- `scripts/verify-installable-apk.ps1 -FromRelease -Tag v0.5.4-study.8`

## 产物

- Debug APK：`YumeBox-Study-v0.5.4-study.8-arm64-v8a-debug.apk`
- Release APK：`YumeBox-Study-v0.5.4-study.8-arm64-v8a-release.apk`
- 发版体检报告：`release-health-v0.5.4-study.8.md`
