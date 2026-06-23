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

## 改进

- 首页 `ReleasePipelineCard` 增加发版体检步骤。
- 设置页 Infra Lab 增加发版体检说明。
- `RELEASE_STUDY.md` 补充构建后体检流程。
- 学习版更新日志补充 v0.5.4-study.8 条目。
- 版本升级到 `0.5.4-study.8` / `5408`。

## 验证

- `scripts/build-apk-strict.ps1`
- `scripts/release-health.ps1 -Tag v0.5.4-study.8`

## 产物

- Debug APK：`YumeBox Study-arm64-v8a-debug.apk`
- 发版体检报告：`release-health-v0.5.4-study.8.md`
