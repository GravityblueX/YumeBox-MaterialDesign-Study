param(
    [string]$Tag = "",
    [string]$ApkPath = "",
    [switch]$RequireDevice,
    [string]$JsonOut = "",
    [string]$MarkdownOut = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Read-PropertiesFile {
    param([string]$Path)
    $props = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) { continue }
        $parts = $trimmed -split "=", 2
        if ($parts.Count -eq 2) { $props[$parts[0].Trim()] = $parts[1].Trim() }
    }
    return $props
}

function Find-Adb {
    $candidates = @()
    if ($env:ANDROID_HOME) { $candidates += (Join-Path $env:ANDROID_HOME "platform-tools\adb.exe") }
    if ($env:ANDROID_SDK_ROOT) { $candidates += (Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe") }
    $localProperties = Join-Path $ProjectRoot "local.properties"
    if (Test-Path -LiteralPath $localProperties) {
        foreach ($line in Get-Content -LiteralPath $localProperties) {
            if ($line -match "^sdk\.dir=(.+)$") {
                $sdk = $matches[1].Replace("\\:", ":").Replace("\\", "\")
                $candidates += (Join-Path $sdk "platform-tools\adb.exe")
            }
        }
    }
    $candidates += "adb"
    foreach ($candidate in $candidates) {
        try {
            $cmd = Get-Command $candidate -ErrorAction Stop
            return $cmd.Source
        } catch {
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return ""
}

$props = Read-PropertiesFile (Join-Path $ProjectRoot "gradle.properties")
$versionName = [string]$props["project.version.name"]
$versionCode = [string]$props["project.version.code"]
$applicationId = [string]$props["project.applicationId"]
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "v$versionName" }
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $ProjectRoot "app\build\outputs\apk\release\YumeBox Study-arm64-v8a-release.apk"
}
if ([string]::IsNullOrWhiteSpace($JsonOut)) { $JsonOut = Join-Path $ProjectRoot "docs\device-install-matrix-$Tag.json" }
if ([string]::IsNullOrWhiteSpace($MarkdownOut)) { $MarkdownOut = Join-Path $ProjectRoot "docs\device-install-matrix-$Tag.md" }

$adb = Find-Adb
$apkExists = Test-Path -LiteralPath $ApkPath
$devices = @()
$results = @()
$failures = @()

if (-not [string]::IsNullOrWhiteSpace($adb)) {
    $rawDevices = & $adb devices 2>&1
    foreach ($line in $rawDevices) {
        if ($line -match "^([^\s]+)\s+device$") {
            $devices += $matches[1]
        }
    }
}

if (-not $apkExists) {
    $failures += "APK not found: $ApkPath"
}
if ([string]::IsNullOrWhiteSpace($adb)) {
    $failures += "adb not found"
}
if ($RequireDevice -and $devices.Count -eq 0) {
    $failures += "no connected Android device or emulator"
}

if ($apkExists -and -not [string]::IsNullOrWhiteSpace($adb)) {
    foreach ($device in $devices) {
        $installOutput = & $adb -s $device install -r -t $ApkPath 2>&1
        $ok = ($LASTEXITCODE -eq 0) -and (($installOutput -join "`n") -match "Success")
        if (-not $ok) { $failures += "install failed on $device" }
        $results += [pscustomobject]@{
            serial = $device
            ok = $ok
            command = "adb -s $device install -r -t <apk>"
            output = ($installOutput -join "`n")
        }
    }
}

$status = if ($failures.Count -gt 0) { "failed" } elseif ($devices.Count -eq 0) { "no_devices" } else { "installed" }
$payload = [pscustomobject]@{
    reportType = "yumebox_device_install_matrix"
    generatedAt = (Get-Date).ToString("o")
    tag = $Tag
    projectRoot = $ProjectRoot
    applicationId = $applicationId
    versionName = $versionName
    versionCode = $versionCode
    apkPath = $ApkPath
    apkExists = $apkExists
    adb = $adb
    status = $status
    ok = ($failures.Count -eq 0)
    requireDevice = [bool]$RequireDevice
    devices = @($devices)
    results = @($results)
    failures = @($failures)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOut) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarkdownOut) | Out-Null
$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $JsonOut -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Device Install Matrix - $Tag")
$lines.Add("")
$lines.Add("Generated: $($payload.generatedAt)")
$lines.Add("Status: ``$($payload.status)``")
$lines.Add("APK: ``$ApkPath``")
$lines.Add("ApplicationId: ``$applicationId``")
$lines.Add("Version: ``$versionName / $versionCode``")
$lines.Add("")
$lines.Add("## Devices")
$lines.Add("")
if ($devices.Count -eq 0) {
    $lines.Add("- No connected Android device or emulator was detected.")
} else {
    foreach ($result in $results) {
        $resultStatus = if ($result.ok) { "OK" } else { "FAIL" }
        $lines.Add("- ``$($result.serial)``: $resultStatus")
    }
}
$lines.Add("")
$lines.Add("## Notes")
$lines.Add("")
$lines.Add("- This report is the real-device layer above zipalign, badging, signature, and digest checks.")
$lines.Add("- Use `-RequireDevice` in a release gate when a connected owned or authorized device is expected.")
$lines.Add("- No APK file is committed by this report.")
($lines -join "`n") | Set-Content -LiteralPath $MarkdownOut -Encoding UTF8

Write-Host "Status=$status"
Write-Host "JsonOut=$JsonOut"
Write-Host "MarkdownOut=$MarkdownOut"
if ($failures.Count -gt 0) { exit 1 }
