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

function Escape-MarkdownInline {
    param([object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return ([string]$Value).
        Replace("`r`n", " ").Replace("`n", " ").Replace("`r", " ")
}

function Format-MarkdownCodeSpan {
    param([object]$Value)
    $text = Escape-MarkdownInline -Value $Value
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $maxTicks = 0
    foreach ($match in [regex]::Matches($text, '`+')) {
        if ($match.Value.Length -gt $maxTicks) { $maxTicks = $match.Value.Length }
    }
    $fence = '`' * ($maxTicks + 1)
    $padded = if ($text.StartsWith('`') -or $text.EndsWith('`')) { " $text " } else { $text }
    return "$fence$padded$fence"
}

function Invoke-NativeText {
    param(
        [string]$Command,
        [string[]]$CommandArgs = @()
    )
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $script:ErrorActionPreference = "Continue"
        $output = & $Command @CommandArgs 2>&1
        return [pscustomobject]@{
            exitCode = $LASTEXITCODE
            output = @($output | ForEach-Object { [string]$_ })
        }
    } catch {
        return [pscustomobject]@{
            exitCode = 1
            output = @([string]$_.Exception.Message)
        }
    } finally {
        $script:ErrorActionPreference = $previousErrorActionPreference
    }
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
    $adbDevices = Invoke-NativeText -Command $adb -CommandArgs @("devices")
    if ($adbDevices.exitCode -eq 0) {
        foreach ($line in @($adbDevices.output)) {
            if ($line -match "^([^\s]+)\s+device$") {
                $devices += $matches[1]
            }
        }
    } else {
        $failures += "adb devices failed: $(@($adbDevices.output) -join '; ')"
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
        $install = Invoke-NativeText -Command $adb -CommandArgs @("-s", $device, "install", "-r", "-t", $ApkPath)
        $ok = ($install.exitCode -eq 0) -and ((@($install.output) -join "`n") -match "Success")
        if (-not $ok) { $failures += "install failed on $device" }
        $results += [pscustomobject]@{
            serial = $device
            ok = $ok
            command = "adb -s $device install -r -t <apk>"
            output = (@($install.output) -join "`n")
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
$safeStatus = Escape-MarkdownInline -Value $payload.status
$safeApkPath = Escape-MarkdownInline -Value $ApkPath
$safeApplicationId = Escape-MarkdownInline -Value $applicationId
$safeVersion = Escape-MarkdownInline -Value "$versionName / $versionCode"
$statusCode = Format-MarkdownCodeSpan -Value $safeStatus
$apkPathCode = Format-MarkdownCodeSpan -Value $safeApkPath
$applicationIdCode = Format-MarkdownCodeSpan -Value $safeApplicationId
$versionCodeSpan = Format-MarkdownCodeSpan -Value $safeVersion
$lines.Add("# Device Install Matrix - $Tag")
$lines.Add("")
$lines.Add("Generated: $($payload.generatedAt)")
$lines.Add("Status: $statusCode")
$lines.Add("APK: $apkPathCode")
$lines.Add("ApplicationId: $applicationIdCode")
$lines.Add("Version: $versionCodeSpan")
$lines.Add("")
$lines.Add("## Devices")
$lines.Add("")
if ($devices.Count -eq 0) {
    $lines.Add("- No connected Android device or emulator was detected.")
} else {
    foreach ($result in $results) {
        $resultStatus = if ($result.ok) { "OK" } else { "FAIL" }
        $safeSerial = Escape-MarkdownInline -Value $result.serial
        $serialCode = Format-MarkdownCodeSpan -Value $safeSerial
        $lines.Add("- $($serialCode): $resultStatus")
    }
}
$lines.Add("")
$lines.Add("## Notes")
$lines.Add("")
$lines.Add("- This report is the real-device layer above zipalign, badging, signature, and digest checks.")
$lines.Add('- Use `-RequireDevice` in a release gate when a connected owned or authorized device is expected.')
$lines.Add("- No APK file is committed by this report.")
($lines -join "`n") | Set-Content -LiteralPath $MarkdownOut -Encoding UTF8

Write-Host "Status=$status"
Write-Host "JsonOut=$JsonOut"
Write-Host "MarkdownOut=$MarkdownOut"
if ($failures.Count -gt 0) { exit 1 }
