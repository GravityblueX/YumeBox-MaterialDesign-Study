param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Repo = 'GravityblueX/YumeBox-MaterialDesign-Study',
    [string]$Tag = '',
    [string]$ApkPath = '',
    [string]$OutputName = ''
)

$ErrorActionPreference = 'Stop'
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

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -ge 1MB) {
        return ('{0:N2} MB' -f ($Bytes / 1MB))
    }
    return ('{0:N0} bytes' -f $Bytes)
}

$versionName = Read-GradleProperty 'project.version.name'
$versionCode = Read-GradleProperty 'project.version.code'
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "v$versionName"
}
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $ProjectRoot 'app\build\outputs\apk\debug\YumeBox Study-arm64-v8a-debug.apk'
}
if ([string]::IsNullOrWhiteSpace($OutputName)) {
    $OutputName = "release-health-$Tag.md"
}

$apk = Get-Item -LiteralPath $ApkPath -ErrorAction SilentlyContinue
$apkSha256 = ''
$apkSize = ''
$apkLastWrite = ''
if ($apk) {
    $apkSha256 = (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $apkSize = Format-Bytes -Bytes $apk.Length
    $apkLastWrite = $apk.LastWriteTime.ToString('o')
}

$gitBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
$gitHead = (git rev-parse HEAD 2>$null)
$gitStatus = (git status --short 2>$null)
$gitClean = [string]::IsNullOrWhiteSpace(($gitStatus -join "`n"))

$release = $null
$releaseError = ''
try {
    $releaseJson = gh release view $Tag --repo $Repo --json tagName,name,url,assets 2>$null
    if ($LASTEXITCODE -eq 0 -and $releaseJson) {
        $release = $releaseJson | ConvertFrom-Json
    }
} catch {
    $releaseError = $_.Exception.Message
}

$assetRows = @()
if ($release -and $release.assets) {
    foreach ($asset in $release.assets) {
        $assetRows += "| $($asset.name) | $(Format-Bytes -Bytes ([int64]$asset.size)) | $($asset.digest) |"
    }
}

$checks = @(
    @{ Name = 'gradle version name'; Ok = -not [string]::IsNullOrWhiteSpace($versionName); Detail = $versionName },
    @{ Name = 'gradle version code'; Ok = -not [string]::IsNullOrWhiteSpace($versionCode); Detail = $versionCode },
    @{ Name = 'APK exists'; Ok = [bool]$apk; Detail = $(if ($apk) { $apk.FullName } else { $ApkPath }) },
    @{ Name = 'git working tree clean'; Ok = $gitClean; Detail = $(if ($gitClean) { 'clean' } else { 'dirty before final commit is expected during development' }) },
    @{ Name = 'GitHub release visible'; Ok = [bool]$release; Detail = $(if ($release) { $release.url } else { $releaseError }) }
)

$lines = @(
    "# YumeBox Study Release Health",
    '',
    "Generated: $(Get-Date -Format o)",
    "Repository: ``$Repo``",
    "Branch: ``$gitBranch``",
    "Commit: ``$gitHead``",
    "Version: ``$versionName`` / ``$versionCode``",
    "Tag: ``$Tag``",
    '',
    '## Checks',
    '',
    '| Check | Status | Detail |',
    '|---|---|---|'
)

foreach ($check in $checks) {
    $status = if ($check.Ok) { 'OK' } else { 'WARN' }
    $detail = [string]$check.Detail
    $lines += "| $($check.Name) | $status | $detail |"
}

$lines += @(
    '',
    '## APK',
    '',
    '| File | Size | SHA-256 | Last Modified |',
    '|---|---:|---|---|'
)
if ($apk) {
    $lines += "| $($apk.Name) | $apkSize | ``$apkSha256`` | $apkLastWrite |"
} else {
    $lines += "| missing | - | - | - |"
}

$lines += @(
    '',
    '## Release Assets',
    '',
    '| Asset | Size | Digest |',
    '|---|---:|---|'
)
if ($assetRows.Count -gt 0) {
    $lines += $assetRows
} else {
    $lines += '| none or release not created yet | - | - |'
}

$lines += @(
    '',
    '## Next Commands',
    '',
    '```powershell',
    "powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1",
    ".\scripts\upload-apk.bat $Tag",
    "powershell -ExecutionPolicy Bypass -File .\scripts\release-health.ps1 -Tag $Tag",
    '```',
    ''
)

$outputPath = Join-Path $ProjectRoot $OutputName
$lines -join "`n" | Set-Content -LiteralPath $outputPath -Encoding UTF8
Write-Host "Wrote $outputPath"
