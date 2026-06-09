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
2. 准备 release notes，例如 `release-notes-v0.5.4-study.2.md`
3. 提交代码并推送分支
4. 创建并推送 tag
   - `git tag v0.5.4-study.2`
   - `git push origin v0.5.4-study.2`
5. 本地构建 APK

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1
```

6. 创建或更新 GitHub Release

```bash
gh release create v0.5.4-study.2 --repo GravityblueX/YumeBox-MaterialDesign-Study --title "YumeBox Study v0.5.4-study.2" --notes-file release-notes-v0.5.4-study.2.md
```

如果 Release 已存在，只上传 APK：

```bat
scripts\upload-apk.bat v0.5.4-study.2
```

## 产物与日志

- 默认 APK 路径：`app\build\outputs\apk\debug\YumeBox Study-arm64-v8a-debug.apk`
- 构建日志：`build-apk-strict.log`

## 说明

- `scripts/build-apk-strict.ps1` 会自动设置 `JAVA_HOME`、`GRADLE_USER_HOME` 和代理。
- 当前固定上传学习版 `arm64-v8a` debug APK，适合自测和学习。
