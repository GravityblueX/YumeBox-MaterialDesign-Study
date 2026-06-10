param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$JavaHome = 'C:\Program Files\Eclipse Adoptium\jdk-24.0.2.12-hotspot',
    [string]$GradleUserHome = 'D:\GradleCache-YumeBoxStudy',
    [string]$ProxyUrl = 'http://127.0.0.1:7897',
    [string]$GradleTask = ':app:assembleDebug',
    [string]$LogName = 'build-apk-strict.log',
    [string]$GradleJvmArgs = '-Xmx2g -XX:MaxMetaspaceSize=768m -XX:+UseG1GC -Dfile.encoding=UTF-8',
    [string]$KotlinDaemonJvmArgs = '-Xmx1024m -XX:+UseG1GC',
    [int]$MinProjectDriveFreeGb = 8
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}
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
$gradlePropertyArgs = @(
    ('-Dorg.gradle.jvmargs={0}' -f $GradleJvmArgs),
    '-Dorg.gradle.daemon=false',
    '-Dorg.gradle.parallel=false',
    '-Dorg.gradle.configuration-cache=false',
    '-Dorg.gradle.configuration-cache.parallel=false',
    '-Dorg.gradle.workers.max=1',
    '-Dandroid.r8.maxWorkers=1',
    '-Dkotlin.incremental=false',
    '-Dkotlin.incremental.useClasspathSnapshot=false',
    '-Dkotlin.incremental.multiplatform=false',
    '-Dkotlin.compiler.execution.strategy=in-process'
)
$gradlePropertyArgString = ($gradlePropertyArgs | ForEach-Object { '"{0}"' -f $_ }) -join ' '

function Write-LogLine {
    param([string]$Text)
    $Text | Tee-Object -FilePath $logPath -Append
}

function Get-DriveFreeBytes {
    param([string]$Path)
    $resolvedPath = (Resolve-Path $Path).Path
    $root = [System.IO.Path]::GetPathRoot($resolvedPath)
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($root.TrimEnd('\\'))'"
    if ($null -eq $drive) {
        throw "Cannot determine free space for drive $root"
    }
    return [int64]$drive.FreeSpace
}

function Format-BytesToGb {
    param([int64]$Bytes)
    return ('{0:N2} GB' -f ($Bytes / 1GB))
}

Write-LogLine ('=== YumeBox Study strict APK build ===')
Write-LogLine ("Time: {0}" -f (Get-Date -Format o))
Write-LogLine ("ProjectRoot={0}" -f $ProjectRoot)
Write-LogLine ("JAVA_HOME={0}" -f $env:JAVA_HOME)
Write-LogLine ("GRADLE_USER_HOME={0}" -f $env:GRADLE_USER_HOME)
Write-LogLine ("Proxy={0}" -f $ProxyUrl)
Write-LogLine ("GradleJvmArgs={0}" -f $GradleJvmArgs)
Write-LogLine ("KotlinDaemonJvmArgs={0}" -f $KotlinDaemonJvmArgs)

$projectDriveFreeBytes = Get-DriveFreeBytes -Path $ProjectRoot
$gradleDriveFreeBytes = Get-DriveFreeBytes -Path $GradleUserHome
Write-LogLine ("ProjectDriveFree={0}" -f (Format-BytesToGb -Bytes $projectDriveFreeBytes))
Write-LogLine ("GradleDriveFree={0}" -f (Format-BytesToGb -Bytes $gradleDriveFreeBytes))
if ($projectDriveFreeBytes -lt ($MinProjectDriveFreeGb * 1GB)) {
    $message = "Project drive is too full for Android packaging. Free at least $MinProjectDriveFreeGb GB on the project drive or build from a workspace on another drive."
    Write-LogLine ("ERROR: {0}" -f $message)
    throw $message
}

cmd /c "java -version 2>&1" | Tee-Object -FilePath $logPath -Append
cmd /c "javac -version 2>&1" | Tee-Object -FilePath $logPath -Append

Write-LogLine '=== Stop Gradle daemons ==='
cmd /c ".\\gradlew.bat --stop 2>&1" | Tee-Object -FilePath $logPath -Append

Write-LogLine ("=== Build {0} ===" -f $GradleTask)
$buildCommand = ".\\gradlew.bat $gradlePropertyArgString $GradleTask --no-daemon --no-configuration-cache --stacktrace 2>&1"
Write-LogLine ("Command={0}" -f $buildCommand)
cmd /c $buildCommand | Tee-Object -FilePath $logPath -Append
$code = $LASTEXITCODE
Write-LogLine ("=== Gradle exit code: {0} ===" -f $code)

Write-LogLine '=== APK search ==='
Get-ChildItem (Join-Path $ProjectRoot 'app\build\outputs') -Recurse -Filter *.apk -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, LastWriteTime |
    Format-Table -AutoSize |
    Out-String |
    Tee-Object -FilePath $logPath -Append

exit $code
