param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Repo = 'GravityblueX/YumeBox-MaterialDesign-Study',
    [string]$Tag = '',
    [string[]]$ApkPath = @(),
    [string]$AndroidSdkRoot = '',
    [string]$DownloadDir = '',
    [switch]$FromRelease,
    [switch]$Install,
    [string]$DeviceSerial = ''
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}
Set-Location $ProjectRoot

function Read-GradleProperty {
    param([string]$Name)
    $line = Get-Content -LiteralPath (Join-Path $ProjectRoot 'gradle.properties') |
        Where-Object { $_ -match ('^{0}=' -f [regex]::Escape($Name)) } |
        Select-Object -First 1
    if (-not $line) {
        return ''
    }
    return ($line -split '=', 2)[1].Trim()
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

function Resolve-AdbPath {
    param([string]$SdkRoot)
    $adb = Join-Path $SdkRoot 'platform-tools\adb.exe'
    if (-not (Test-Path -LiteralPath $adb)) {
        throw "Cannot find adb.exe at $adb"
    }
    return $adb
}

function Invoke-Cmd {
    param([string]$Command)
    $output = cmd /c $Command
    return @{
        ExitCode = $LASTEXITCODE
        Output = @($output)
    }
}

function Get-BadgingValue {
    param(
        [string[]]$Badging,
        [string]$Name
    )
    $line = $Badging | Where-Object { $_ -match "^$([regex]::Escape($Name))" } | Select-Object -First 1
    if (-not $line) {
        return ''
    }
    return $line
}

function Get-ConnectedDevices {
    param([string]$Adb)
    $result = Invoke-Cmd ('"{0}" devices 2>&1' -f $Adb)
    if ($result.ExitCode -ne 0) {
        return @()
    }
    return @(
        $result.Output |
            Where-Object { $_ -match "`tdevice$" } |
            ForEach-Object { ($_ -split "`t", 2)[0] }
    )
}

$versionName = Read-GradleProperty 'project.version.name'
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "v$versionName"
}

if ($FromRelease) {
    if ([string]::IsNullOrWhiteSpace($DownloadDir)) {
        $DownloadDir = Join-Path $env:TEMP "YumeBox-Study-$Tag-installable"
    }
    Remove-Item -LiteralPath $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $DownloadDir | Out-Null
    gh release download $Tag --repo $Repo --pattern '*.apk' --dir $DownloadDir
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $ApkPath = @(Get-ChildItem -LiteralPath $DownloadDir -Filter '*.apk' | Sort-Object Name | ForEach-Object { $_.FullName })
}

if ($ApkPath.Count -eq 0) {
    $ApkPath = @(
        (Join-Path $ProjectRoot 'app\build\outputs\apk\debug\YumeBox Study-arm64-v8a-debug.apk'),
        (Join-Path $ProjectRoot 'app\build\outputs\apk\release\YumeBox Study-arm64-v8a-release.apk')
    )
}

$sdkRoot = Resolve-AndroidSdkRoot
$buildToolsDir = Resolve-BuildToolsDir -SdkRoot $sdkRoot
$adb = Resolve-AdbPath -SdkRoot $sdkRoot
$expectedApplicationId = Read-GradleProperty 'project.applicationId'
$expectedVersionName = Read-GradleProperty 'project.version.name'
$expectedVersionCode = Read-GradleProperty 'project.version.code'
$expectedAbiList = (Read-GradleProperty 'abi.app.list').Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$failures = @()

Write-Host '=== Installable APK verification ==='
Write-Host ("ProjectRoot={0}" -f $ProjectRoot)
Write-Host ("Repo={0}" -f $Repo)
Write-Host ("Tag={0}" -f $Tag)
Write-Host ("AndroidSdkRoot={0}" -f $sdkRoot)
Write-Host ("BuildToolsDir={0}" -f $buildToolsDir)

foreach ($path in $ApkPath) {
    $apk = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    if (-not $apk) {
        $failures += "APK missing: $path"
        continue
    }

    Write-Host ''
    Write-Host ("APK={0}" -f $apk.FullName)
    Write-Host ("Size={0}" -f $apk.Length)
    Write-Host ("SHA256={0}" -f (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant())

    $zipalign = Invoke-Cmd ('"{0}" -c -p 4 "{1}" 2>&1' -f (Join-Path $buildToolsDir 'zipalign.exe'), $apk.FullName)
    if ($zipalign.ExitCode -eq 0) {
        Write-Host 'zipalign=OK'
    } else {
        Write-Host 'zipalign=FAIL'
        $zipalign.Output | ForEach-Object { Write-Host $_ }
        $failures += "zipalign failed: $($apk.Name)"
    }

    $badging = Invoke-Cmd ('"{0}" dump badging "{1}" 2>&1' -f (Join-Path $buildToolsDir 'aapt.exe'), $apk.FullName)
    if ($badging.ExitCode -ne 0) {
        Write-Host 'badging=FAIL'
        $badging.Output | ForEach-Object { Write-Host $_ }
        $failures += "aapt badging failed: $($apk.Name)"
    } else {
        $packageLine = Get-BadgingValue -Badging $badging.Output -Name 'package:'
        $sdkLine = Get-BadgingValue -Badging $badging.Output -Name 'sdkVersion'
        $targetSdkLine = Get-BadgingValue -Badging $badging.Output -Name 'targetSdkVersion'
        $labelLine = Get-BadgingValue -Badging $badging.Output -Name 'application-label:'
        $nativeLine = Get-BadgingValue -Badging $badging.Output -Name 'native-code:'
        Write-Host ("badging=OK {0}" -f $packageLine)
        Write-Host $sdkLine
        Write-Host $targetSdkLine
        Write-Host $labelLine
        Write-Host $nativeLine

        if ($packageLine -notmatch "name='$([regex]::Escape($expectedApplicationId))'") {
            $failures += "unexpected applicationId in $($apk.Name)"
        }
        if ($packageLine -notmatch "versionCode='$([regex]::Escape($expectedVersionCode))'") {
            $failures += "unexpected versionCode in $($apk.Name)"
        }
        if ($packageLine -notmatch "versionName='$([regex]::Escape($expectedVersionName))'") {
            $failures += "unexpected versionName in $($apk.Name)"
        }
        foreach ($abi in $expectedAbiList) {
            if ($nativeLine -notmatch "'$([regex]::Escape($abi))'") {
                $failures += "missing native ABI $abi in $($apk.Name)"
            }
        }
    }

    $signature = Invoke-Cmd ('"{0}" verify --verbose --print-certs "{1}" 2>&1' -f (Join-Path $buildToolsDir 'apksigner.bat'), $apk.FullName)
    if ($signature.ExitCode -eq 0) {
        Write-Host 'signature=OK'
        $signature.Output |
            Where-Object { $_ -match '^(Verifies|Verified using v2|Verified using v3|Signer #1 certificate DN)' } |
            ForEach-Object { Write-Host $_ }
    } else {
        Write-Host 'signature=FAIL'
        $signature.Output | ForEach-Object { Write-Host $_ }
        $failures += "signature verify failed: $($apk.Name)"
    }

    if ($Install) {
        $devices = Get-ConnectedDevices -Adb $adb
        if ($devices.Count -eq 0) {
            $failures += 'adb install requested, but no connected device is available'
        } else {
            $device = if ([string]::IsNullOrWhiteSpace($DeviceSerial)) { $devices[0] } else { $DeviceSerial }
            Write-Host ("adb_install_device={0}" -f $device)
            $install = Invoke-Cmd ('"{0}" -s "{1}" install -r -d "{2}" 2>&1' -f $adb, $device, $apk.FullName)
            $install.Output | ForEach-Object { Write-Host $_ }
            if ($install.ExitCode -ne 0) {
                $failures += "adb install failed: $($apk.Name)"
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host '=== FAILURES ==='
    $failures | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host ''
Write-Host 'Installable APK verification passed.'
