# YumeBox Study v0.5.4-study.6

本次继续向 Infra / Observability 方向演进，让学习版更像一个可观测、可诊断、可借阅的运行时面板。

## 新增

- 首页新增 `OBSERVABILITY` 可观测性面板。
  - 展示 Runtime / Profile / Node / Latency / Traffic / IP 六个观测维度。
  - 标注每个维度的数据来源，例如 `HomeViewModel.controlState`、`selectedServerName`、`trafficNow`。
  - 使用 `GREEN / WATCH / IDLE` 状态帮助理解当前运行态。
- 首页新增「学习路线」卡片。
  - 引导阅读 `App.kt`、`MainActivity.kt`、`MainScreen.kt`、`HomeViewModel.kt`、`ProxyFacade.kt`、`AppSettingsStore.kt`、`RELEASE_STUDY.md`。
- 设置页 Infra Lab 增加故障排查和安全边界说明。
  - 提醒检查 `build-apk-strict.log`、JDK 24、D 盘 Gradle 缓存、C 盘空间、Kotlin daemon。
  - 提醒不要分享私人订阅/节点，不提交 `local.properties`，不随意改 `applicationId`。
- 版本升级到 `0.5.4-study.6` / `5406`。

## APK

- 构建类型：Debug
- ABI：arm64-v8a
