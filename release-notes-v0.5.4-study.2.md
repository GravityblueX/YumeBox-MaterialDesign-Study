# YumeBox Study v0.5.4-study.2

本次 Release 在学习版暗色首页基础上，补充固定的低内存本地发布脚本，并整理构建目录，便于后续重复发版。

## 变更内容

- 新增仓库内固定脚本 `scripts/build-apk-strict.ps1`
  - 显式设置 JDK 24
  - 固定 `GRADLE_USER_HOME`
  - 固定代理环境变量
  - 关闭 daemon / configuration cache
  - 统一输出构建日志并自动扫描 APK
- 新增仓库内固定脚本 `scripts/upload-apk.bat`
  - 支持按 tag 上传 APK 到既有 GitHub Release
  - 默认指向学习版仓库与 debug APK 输出路径
- 学习版版本号推进为 `0.5.4-study.2`
- 清理 D 盘构建副本中的试错脚本与日志，只保留最终可用脚本

## 说明

- 本次仍使用本机构建 APK 后上传 Release 的方式。
- 当前附带的是 `arm64-v8a` Debug APK，适合学习和自测。
