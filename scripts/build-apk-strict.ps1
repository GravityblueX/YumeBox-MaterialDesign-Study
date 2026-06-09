param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$JavaHome = 'C:\Program Files\Eclipse Adoptium\jdk-24.0.2.12-hotspot',
    [string]$GradleUserHome = 'D:\GradleCache-YumeBoxStudy',
    [string]$ProxyUrl = 'http://127.0.0.1:7897',
    [string]$GradleTask = ':app:assembleDebug',
    [string]$LogName = 'build-apk-strict.log'
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$logPath = Join-Path $ProjectRoot $LogName
if (Test-Path $logPath) {
    Remove-Item $logPath -Force
}

$env:JAVA_HOME = $JavaHome
$env:Path = "$JavaHome\bin;$env:Path"
$env:GRADLE_USER_HOME = $GradleUserHome
$env:HTTP_PROXY = $ProxyUrl
$env:HTTPS_PROXY = $ProxyUrl
$env:ALL_PROXY = $ProxyUrl
$env:NO_PROXY = 'localhost,127.0.0.1'
$env:GRADLE_OPTS = '-Dorg.gradle.daemon=false -Dorg.gradle.vfs.watch=false -Dfile.encoding=UTF-8'
$env:JAVA_TOOL_OPTIONS = '-Dfile.encoding=UTF-8'

function Write-LogLine {
    param([string]$Text)
    $Text | Tee-Object -FilePath $logPath -Append
}

Write-LogLine '=== YumeBox Study strict APK build ==='
Write-LogLine ("Time: {0}" -f (Get-Date -Format o))
Write-LogLine ("ProjectRoot={0}" -f $ProjectRoot)
Write-LogLine ("JAVA_HOME={0}" -f $env:JAVA_HOME)
Write-LogLine ("GRADLE_USER_HOME={0}" -f $env:GRADLE_USER_HOME)
Write-LogLine ("Proxy={0}" -f $ProxyUrl)

java -version 2>&1 | Tee-Object -FilePath $logPath -Append
javac -version 2>&1 | Tee-Object -FilePath $logPath -Append

Write-LogLine '=== Stop Gradle daemons ==='
& .\gradlew.bat --stop 2>&1 | Tee-Object -FilePath $logPath -Append

Write-LogLine ("=== Build {0} ===" -f $GradleTask)
& .\gradlew.bat $GradleTask --no-daemon --no-configuration-cache --stacktrace 2>&1 | Tee-Object -FilePath $logPath -Append
$code = $LASTEXITCODE
Write-LogLine ("=== Gradle exit code: {0} ===" -f $code)

Write-LogLine '=== APK search ==='
Get-ChildItem (Join-Path $ProjectRoot 'app\build\outputs') -Recurse -Filter *.apk -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, LastWriteTime |
    Format-Table -AutoSize |
    Out-String |
    Tee-Object -FilePath $logPath -Append

exit $code
