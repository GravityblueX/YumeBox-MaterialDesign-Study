# YumeBox Study v0.5.4-study.7

本次把 Agent 自动发版能力产品化到学习版 UI 里，让「改代码 → 推仓库 → 打 Release」整条链路在首页和设置页都能看见。

## 新增

- 首页新增 **Agent 发版流水线** 卡片（`ReleasePipelineCard`）。
  - 展示当前版本号、SSH + gh 就绪状态。
  - 展开后列出 6 步发版流程：改代码 → 版本号 → push → tag → 构建 APK → 上传 Release。
- 可观测性面板增加 **OBS 得分百分比**（6 维观测各计 1/6，与 GREEN / WATCH / IDLE 并列展示）。
- `StudyStatusCard` 标题区显示当前 `BuildConfig.VERSION_NAME`。
- 学习路线补充 `HomePager.kt`；今日学习提示新增 `gh auth`、发版流程相关条目。
- 设置页 Infra Lab 增加 **Agent 发版流水线** 说明。
- 学习版更新日志对话框补充 v0.5.4-study.4 ~ study.7 条目。
- 版本升级到 `0.5.4-study.7` / `5407`。

## 说明

- 本 Release 仅包含源码与 Release Notes，**暂不附带 APK**。
- 需要安装包时，可在本地执行 `scripts/build-apk-strict.ps1` 构建，再用 `scripts/upload-apk.bat v0.5.4-study.7` 上传到本 Release。

## 本地构建（可选）

- 构建脚本：`scripts/build-apk-strict.ps1`
- 预期产物：`app/build/outputs/apk/debug/YumeBox Study-arm64-v8a-debug.apk`
- 构建类型：Debug · ABI：arm64-v8a
