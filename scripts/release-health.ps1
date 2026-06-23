param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Repo = 'GravityblueX/YumeBox-MaterialDesign-Study',
    [string]$Tag = '',
    [string]$ApkPath = '',
    [string]$OutputName = '',
    [string]$AndroidSdkRoot = ''
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
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat') } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $buildToolsDir) {
        return ''
    }
    return $buildToolsDir.FullName
}

function Get-ApkSignatureStatus {
    param(
        [string]$ApkFile,
        [string]$BuildToolsDir
    )
    if ([string]::IsNullOrWhiteSpace($BuildToolsDir)) {
        return 'WARN: apksigner not found'
    }

    $command = '"{0}" verify --verbose --print-certs "{1}" 2>&1' -f (Join-Path $BuildToolsDir 'apksigner.bat'), $ApkFile
    $verifyOutput = cmd /c $command
    if ($LASTEXITCODE -ne 0) {
        $errorLine = $verifyOutput | Where-Object { $_ -match '^(ERROR|DOES NOT VERIFY)' } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($errorLine)) {
            $errorLine = 'apksigner verify failed'
        }
        return "FAIL: $errorLine"
    }

    $signerLine = $verifyOutput | Where-Object { $_ -match '^Signer #1 certificate DN:' } | Select-Object -First 1
    if ($signerLine) {
        return ('OK ({0})' -f (($signerLine -split ': ', 2)[1]))
    }
    return 'OK'
}

$versionName = Read-GradleProperty 'project.version.name'
$versionCode = Read-GradleProperty 'project.version.code'
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "v$versionName"
}
if ([string]::IsNullOrWhiteSpace($OutputName)) {
    $OutputName = "release-health-$Tag.md"
}

$apks = @()
if (-not [string]::IsNullOrWhiteSpace($ApkPath)) {
    $item = Get-Item -LiteralPath $ApkPath -ErrorAction SilentlyContinue
    if ($item) {
        $apks += $item
    }
} else {
    $apkRoot = Join-Path $ProjectRoot 'app\build\outputs\apk'
    $apks = @(Get-ChildItem -LiteralPath $apkRoot -Recurse -Filter '*.apk' -ErrorAction SilentlyContinue | Sort-Object FullName)
}

$gitBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
$gitHead = (git rev-parse HEAD 2>$null)
$gitStatus = (git status --short --untracked-files=no 2>$null)
$gitClean = [string]::IsNullOrWhiteSpace(($gitStatus -join "`n"))
$resolvedSdkRoot = Resolve-AndroidSdkRoot
$buildToolsDir = Resolve-BuildToolsDir -SdkRoot $resolvedSdkRoot
$apkSignatureStatuses = @{}
foreach ($apk in $apks) {
    $apkSignatureStatuses[$apk.FullName] = Get-ApkSignatureStatus -ApkFile $apk.FullName -BuildToolsDir $buildToolsDir
}
$apkSignaturesOk = $apks.Count -gt 0 -and @($apkSignatureStatuses.Values | Where-Object { $_ -notlike 'OK*' }).Count -eq 0

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
        if ($asset.name -eq $OutputName) {
            continue
        }
        $assetRows += "| $($asset.name) | $(Format-Bytes -Bytes ([int64]$asset.size)) | $($asset.digest) |"
    }
}

$checks = @(
    @{ Name = 'gradle version name'; Ok = -not [string]::IsNullOrWhiteSpace($versionName); Detail = $versionName },
    @{ Name = 'gradle version code'; Ok = -not [string]::IsNullOrWhiteSpace($versionCode); Detail = $versionCode },
    @{ Name = 'APK exists'; Ok = $apks.Count -gt 0; Detail = "$($apks.Count) APK file(s)" },
    @{ Name = 'APK signatures'; Ok = $apkSignaturesOk; Detail = $(if ($apkSignaturesOk) { 'apksigner verify passed' } else { 'one or more APK signatures failed' }) },
    @{ Name = 'tracked git files clean'; Ok = $gitClean; Detail = $(if ($gitClean) { 'clean' } else { 'tracked changes are present before final commit' }) },
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
    '| File | Size | SHA-256 | Signature | Last Modified |',
    '|---|---:|---|---|---|'
)
if ($apks.Count -gt 0) {
    foreach ($apk in $apks) {
        $apkSha256 = (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $apkSize = Format-Bytes -Bytes $apk.Length
        $apkLastWrite = $apk.LastWriteTime.ToString('o')
        $relative = Resolve-Path -LiteralPath $apk.FullName -Relative
        $apkSignatureStatus = $apkSignatureStatuses[$apk.FullName]
        $lines += "| $relative | $apkSize | ``$apkSha256`` | $apkSignatureStatus | $apkLastWrite |"
    }
} else {
    $lines += "| missing | - | - | - | - |"
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
    "powershell -ExecutionPolicy Bypass -File .\scripts\build-apk-strict.ps1 -GradleTask ':app:assembleRelease' -LogName 'build-apk-release-strict.log'",
    "powershell -ExecutionPolicy Bypass -File .\scripts\publish-apk-assets.ps1 -Tag $Tag",
    "powershell -ExecutionPolicy Bypass -File .\scripts\release-health.ps1 -Tag $Tag",
    '```',
    ''
)

$outputPath = Join-Path $ProjectRoot $OutputName
$lines -join "`n" | Set-Content -LiteralPath $outputPath -Encoding UTF8
Write-Host "Wrote $outputPath"
