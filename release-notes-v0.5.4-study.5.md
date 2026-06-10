# YumeBox Study v0.5.4-study.5

这次是偏 Infra / Control Center 风格的学习版改造，继续保持安全边界：不触碰代理 runtime/service/native 逻辑，只增强 UI、诊断说明与本地构建体验。

## 新增

- 首页新增 `INFRA CONTROL CENTER` 控制中心卡片。
  - 展示 Runtime / Profile / Node / Tunnel / Upload / Download 等指标。
  - 新增 Health 百分比与状态检查项。
  - 风格偏暗色基础设施 Dashboard。
- 设置页「学习版借阅」区块新增 Infra Lab 信息。
  - 显示构建目标：Debug / arm64-v8a / JDK 24 / Gradle strict build。
  - 提示本地构建脚本与 Gradle 缓存位置。
  - 提示 Release 操作流程。
- 版本升级到 `0.5.4-study.5` / `5405`。

## 延续

- 保留首页「今日学习提示」。
- 保留首页「模块结构速览」。
- 保留设置页「学习版更新日志」。
- 保留低饱和黑白灰 / 暗色优先视觉方向。

## APK

- 构建类型：Debug
- ABI：arm64-v8a
