# YumeBox Study v0.5.4-study.4

本次是面向“借阅学习”的小版本，继续保持低风险：只改 UI、说明与构建脚本，不触碰代理 runtime/native 逻辑。

## 新增

- 首页新增「今日学习提示」卡片：每天展示一条项目源码学习线索。
- 首页新增「模块结构速览」卡片：可展开查看 app/data/runtime/core/ui/feature 等模块职责。
- 设置页「学习版借阅」区块新增「学习版更新日志」入口。

## 修复与构建

- 修复严格构建脚本中 `kotlin.daemon.jvm.options` 命令行传参导致 Kotlin daemon 启动失败的问题。
- 已在 D 盘副本完成 `:app:assembleDebug` 验证。

## APK

- 构建类型：Debug
- ABI：arm64-v8a
