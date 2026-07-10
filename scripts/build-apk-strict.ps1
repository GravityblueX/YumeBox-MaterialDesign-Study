param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$JavaHome = 'C:\Program Files\Eclipse Adoptium\jdk-24.0.2.12-hotspot',
    [string]$GradleUserHome = 'D:\GradleCache-YumeBoxStudy',
    [string]$ProxyUrl = 'http://127.0.0.1:7897',
    [string]$GradleTask = ':app:assembleDebug',
    [string]$LogName = 'build-apk-strict.log',
    [string]$GradleJvmArgs = '-Xmx2g -XX:MaxMetaspaceSize=768m -XX:+UseG1GC -Dfile.encoding=UTF-8',
    [string]$KotlinDaemonJvmArgs = '-Xmx1024m -XX:+UseG1GC',
    [int]$MinProjectDriveFreeGb = 8,
    [int]$MinGradleDriveFreeGb = 8,
    [string]$AndroidSdkRoot = '',
    [switch]$SkipApkVerify,
    [switch]$DisableDebugSigningFallback
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}
Set-Location $ProjectRoot

$ambientJavaHome = $env:JAVA_HOME
if (-not $PSBoundParameters.ContainsKey('JavaHome') -and
    -not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe')) -and
    -not [string]::IsNullOrWhiteSpace($ambientJavaHome) -and
    (Test-Path -LiteralPath (Join-Path $ambientJavaHome 'bin\java.exe'))) {
    $JavaHome = $ambientJavaHome
}

$logPath = Join-Path $ProjectRoot $LogName
if (Test-Path $logPath) {
    Remove-Item $logPath -Force
}

$env:JAVA_HOME = $JavaHome
$env:Path = "$JavaHome\bin;$env:Path"
if (-not (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    throw "Cannot find java.exe under JAVA_HOME=$env:JAVA_HOME. Pass -JavaHome or set JAVA_HOME to a JDK installation."
}

$env:GRADLE_USER_HOME = $GradleUserHome
$env:HTTP_PROXY = $ProxyUrl
$env:HTTPS_PROXY = $ProxyUrl
$env:ALL_PROXY = $ProxyUrl
$env:NO_PROXY = 'localhost,127.0.0.1'
$env:GRADLE_OPTS = '-Dorg.gradle.daemon=false -Dorg.gradle.vfs.watch=false -Dfile.encoding=UTF-8'
$env:JAVA_TOOL_OPTIONS = '-Dfile.encoding=UTF-8'
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
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

function Read-LocalProperty {
    param([string]$Name)
    $localProperties = Join-Path $ProjectRoot 'local.properties'
    if (-not (Test-Path -LiteralPath $localProperties)) {
        return ''
    }

    $line = Get-Content -LiteralPath $localProperties |
        Where-Object { $_ -match ('^{0}=' -f [regex]::Escape($Name)) } |
        Select-Object -First 1
    if (-not $line) {
        return ''
    }

    return (($line -split '=', 2)[1].Trim() -replace '\\\\', '\')
}

function Resolve-AndroidSdkRoot {
    if (-not [string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
        return $AndroidSdkRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
        return $env:ANDROID_HOME
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) {
        return $env:ANDROID_SDK_ROOT
    }

    $localSdk = Read-LocalProperty 'sdk.dir'
    if (-not [string]::IsNullOrWhiteSpace($localSdk)) {
        return $localSdk
    }

    return (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
}

function Resolve-BuildToolsDir {
    param([string]$SdkRoot)
    $buildToolsRoot = Join-Path $SdkRoot 'build-tools'
    $buildToolsDir = Get-ChildItem -LiteralPath $buildToolsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            (Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat')) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName 'zipalign.exe')) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName 'aapt.exe'))
        } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $buildToolsDir) {
        throw "Cannot find apksigner.bat, zipalign.exe, and aapt.exe under $buildToolsRoot"
    }
    return $buildToolsDir.FullName
}

function Test-ApkZipalign {
    param(
        [string]$ApkPath,
        [string]$BuildToolsDir
    )
    Write-LogLine ("=== Verify APK zipalign: {0} ===" -f $ApkPath) | Out-Null
    $command = '"{0}" -c -p 4 "{1}" 2>&1' -f (Join-Path $BuildToolsDir 'zipalign.exe'), $ApkPath
    $zipalignOutput = cmd /c $command
    $zipalignExitCode = $LASTEXITCODE
    $zipalignOutput | Tee-Object -FilePath $logPath -Append | Out-Null
    if ($zipalignExitCode -eq 0) {
        Write-LogLine 'zipalign=OK' | Out-Null
    }
    return [bool]($zipalignExitCode -eq 0)
}

function Test-ApkBadging {
    param(
        [string]$ApkPath,
        [string]$BuildToolsDir
    )
    Write-LogLine ("=== Verify APK badging: {0} ===" -f $ApkPath) | Out-Null
    $command = '"{0}" dump badging "{1}" 2>&1' -f (Join-Path $BuildToolsDir 'aapt.exe'), $ApkPath
    $badgingOutput = cmd /c $command
    $badgingExitCode = $LASTEXITCODE
    $badgingOutput |
        Where-Object { $_ -match '^(package:|sdkVersion|targetSdkVersion|application-label:|launchable-activity|native-code)' } |
        ForEach-Object { Write-LogLine $_ | Out-Null }
    return [bool]($badgingExitCode -eq 0)
}

function Test-ApkSignature {
    param(
        [string]$ApkPath,
        [string]$BuildToolsDir
    )
    Write-LogLine ("=== Verify APK signature: {0} ===" -f $ApkPath) | Out-Null
    $command = '"{0}" verify --verbose --print-certs "{1}" 2>&1' -f (Join-Path $BuildToolsDir 'apksigner.bat'), $ApkPath
    $verifyOutput = cmd /c $command
    $verifyExitCode = $LASTEXITCODE
    $verifyOutput | Tee-Object -FilePath $logPath -Append | Out-Null
    return [bool]($verifyExitCode -eq 0)
}

function Ensure-DebugKeystore {
    $debugKeystore = Join-Path $env:USERPROFILE '.android\debug.keystore'
    if (Test-Path -LiteralPath $debugKeystore) {
        return $debugKeystore
    }

    $debugKeystoreDir = Split-Path -Parent $debugKeystore
    New-Item -ItemType Directory -Force -Path $debugKeystoreDir | Out-Null
    $keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
    if (-not (Test-Path -LiteralPath $keytool)) {
        throw "Cannot find keytool.exe under JAVA_HOME=$env:JAVA_HOME"
    }

    Write-LogLine ("=== Create Android debug keystore: {0} ===" -f $debugKeystore) | Out-Null
    & $keytool -genkeypair `
        -alias androiddebugkey `
        -keypass android `
        -keystore $debugKeystore `
        -storepass android `
        -dname 'CN=Android Debug,O=Android,C=US' `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 2>&1 |
        Tee-Object -FilePath $logPath -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create Android debug keystore.'
    }

    return $debugKeystore
}

function Sign-ApkWithDebugKeystore {
    param(
        [string]$ApkPath,
        [string]$BuildToolsDir
    )
    $debugKeystore = Ensure-DebugKeystore
    Write-LogLine ("=== Sign release APK with Android debug keystore fallback: {0} ===" -f $ApkPath) | Out-Null
    $command = '"{0}" sign --ks "{1}" --ks-pass pass:android --key-pass pass:android --ks-key-alias androiddebugkey "{2}" 2>&1' -f `
        (Join-Path $BuildToolsDir 'apksigner.bat'), $debugKeystore, $ApkPath
    $signOutput = cmd /c $command
    $signExitCode = $LASTEXITCODE
    $signOutput | Tee-Object -FilePath $logPath -Append | Out-Null
    if ($signExitCode -ne 0) {
        throw "Failed to sign $ApkPath with Android debug keystore fallback."
    }
}

function Get-ApkNamePatternForGradleTask {
    param([string]$Task)
    $normalized = $Task.ToLowerInvariant()
    if ($normalized.Contains('release')) {
        return '*-release.apk'
    }
    if ($normalized.Contains('debug')) {
        return '*-debug.apk'
    }
    return '*.apk'
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
if ($gradleDriveFreeBytes -lt ($MinGradleDriveFreeGb * 1GB)) {
    $message = "Gradle cache drive is too full for Android packaging. Free at least $MinGradleDriveFreeGb GB on the Gradle cache drive or pass -GradleUserHome on a drive with more space."
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
$apkNamePattern = Get-ApkNamePatternForGradleTask -Task $GradleTask
Write-LogLine ("ApkNamePattern={0}" -f $apkNamePattern)
$builtApks = @(Get-ChildItem (Join-Path $ProjectRoot 'app\build\outputs') -Recurse -Filter *.apk -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like $apkNamePattern } |
        Sort-Object FullName)
foreach ($apk in $builtApks) {
    Write-LogLine ("APK={0}" -f $apk.FullName)
    Write-LogLine ("Length={0}" -f $apk.Length)
    Write-LogLine ("LastWriteTime={0}" -f $apk.LastWriteTime.ToString('o'))
}

if ($code -ne 0) {
    exit $code
}
if ($builtApks.Count -eq 0) {
    Write-LogLine ("ERROR: No APK matched pattern {0} under app\build\outputs after {1}." -f $apkNamePattern, $GradleTask)
    exit 1
}

if (-not $SkipApkVerify) {
    $resolvedSdkRoot = Resolve-AndroidSdkRoot
    $buildToolsDir = Resolve-BuildToolsDir -SdkRoot $resolvedSdkRoot
    Write-LogLine ("AndroidSdkRoot={0}" -f $resolvedSdkRoot)
    Write-LogLine ("BuildToolsDir={0}" -f $buildToolsDir)

    foreach ($apk in $builtApks) {
        $zipAligned = Test-ApkZipalign -ApkPath $apk.FullName -BuildToolsDir $buildToolsDir
        if (-not $zipAligned) {
            Write-LogLine ("ERROR: APK zipalign verification failed: {0}" -f $apk.FullName)
            exit 1
        }

        $badgingOk = Test-ApkBadging -ApkPath $apk.FullName -BuildToolsDir $buildToolsDir
        if (-not $badgingOk) {
            Write-LogLine ("ERROR: APK manifest/badging verification failed: {0}" -f $apk.FullName)
            exit 1
        }

        $verified = Test-ApkSignature -ApkPath $apk.FullName -BuildToolsDir $buildToolsDir
        $isReleaseApk = $apk.Name -like '*-release.apk'
        if (-not $verified -and $isReleaseApk -and -not $DisableDebugSigningFallback) {
            Sign-ApkWithDebugKeystore -ApkPath $apk.FullName -BuildToolsDir $buildToolsDir
            $verified = Test-ApkSignature -ApkPath $apk.FullName -BuildToolsDir $buildToolsDir
        }

        if (-not $verified) {
            Write-LogLine ("ERROR: APK signature verification failed: {0}" -f $apk.FullName)
            exit 1
        }
    }
}

exit $code
