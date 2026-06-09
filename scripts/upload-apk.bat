@echo off
setlocal

if "%~1"=="" (
  echo Usage: %~nx0 ^<tag^> [apk-path] [repo]
  exit /b 1
)

set TAG=%~1
set APK=%~2
set REPO=%~3

if "%APK%"=="" set APK=%CD%\app\build\outputs\apk\debug\YumeBox Study-arm64-v8a-debug.apk
if "%REPO%"=="" set REPO=GravityblueX/YumeBox-MaterialDesign-Study

set HTTP_PROXY=http://127.0.0.1:7897
set HTTPS_PROXY=http://127.0.0.1:7897
set ALL_PROXY=http://127.0.0.1:7897
set NO_PROXY=localhost,127.0.0.1

if not exist "%APK%" (
  echo APK not found: %APK%
  exit /b 1
)

echo === APK file ===
dir "%APK%"

echo === Upload to GitHub Release ===
gh release upload %TAG% "%APK%#YumeBox-Study-%TAG%-arm64-v8a-debug.apk" --repo %REPO% --clobber
if errorlevel 1 exit /b %errorlevel%

echo === Release assets ===
gh release view %TAG% --repo %REPO% --json tagName,name,url,assets
