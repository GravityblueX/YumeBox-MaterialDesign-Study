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

function Escape-MarkdownTableCell {
    param([object]$Value)
    if ($null -eq $Value) {
        return ''
    }
    return ([string]$Value).
        Replace("`r`n", '<br>').Replace("`n", '<br>').Replace("`r", '<br>').
        Replace('|', '\|')
}

function Format-MarkdownCodeSpan {
    param([object]$Value)
    $text = Escape-MarkdownTableCell -Value $Value
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }
    $maxTicks = 0
    foreach ($match in [regex]::Matches($text, '`+')) {
        if ($match.Value.Length -gt $maxTicks) { $maxTicks = $match.Value.Length }
    }
    $fence = '`' * ($maxTicks + 1)
    $padded = if ($text.StartsWith('`') -or $text.EndsWith('`')) { " $text " } else { $text }
    return "$fence$padded$fence"
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
        return ''
    }
    return $buildToolsDir.FullName
}

function Get-ApkZipalignStatus {
    param(
        [string]$ApkFile,
        [string]$BuildToolsDir
    )
    if ([string]::IsNullOrWhiteSpace($BuildToolsDir)) {
        return 'WARN: zipalign not found'
    }

    $command = '"{0}" -c -p 4 "{1}" 2>&1' -f (Join-Path $BuildToolsDir 'zipalign.exe'), $ApkFile
    cmd /c $command | Out-Null
    if ($LASTEXITCODE -ne 0) {
        return 'FAIL: zipalign check failed'
    }
    return 'OK'
}

function Get-ApkBadgingStatus {
    param(
        [string]$ApkFile,
        [string]$BuildToolsDir
    )
    if ([string]::IsNullOrWhiteSpace($BuildToolsDir)) {
        return 'WARN: aapt not found'
    }

    $command = '"{0}" dump badging "{1}" 2>&1' -f (Join-Path $BuildToolsDir 'aapt.exe'), $ApkFile
    $badgingOutput = cmd /c $command
    if ($LASTEXITCODE -ne 0) {
        return 'FAIL: aapt badging failed'
    }

    $packageLine = $badgingOutput | Where-Object { $_ -match '^package:' } | Select-Object -First 1
    $nativeLine = $badgingOutput | Where-Object { $_ -match '^native-code:' } | Select-Object -First 1
    if (-not $packageLine) {
        return 'FAIL: package metadata missing'
    }
    if ($nativeLine) {
        return "OK ($nativeLine)"
    }
    return 'OK'
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
$apkZipalignStatuses = @{}
$apkBadgingStatuses = @{}
foreach ($apk in $apks) {
    $apkSignatureStatuses[$apk.FullName] = Get-ApkSignatureStatus -ApkFile $apk.FullName -BuildToolsDir $buildToolsDir
    $apkZipalignStatuses[$apk.FullName] = Get-ApkZipalignStatus -ApkFile $apk.FullName -BuildToolsDir $buildToolsDir
    $apkBadgingStatuses[$apk.FullName] = Get-ApkBadgingStatus -ApkFile $apk.FullName -BuildToolsDir $buildToolsDir
}
$apkSignaturesOk = $apks.Count -gt 0 -and @($apkSignatureStatuses.Values | Where-Object { $_ -notlike 'OK*' }).Count -eq 0
$apkZipalignOk = $apks.Count -gt 0 -and @($apkZipalignStatuses.Values | Where-Object { $_ -ne 'OK' }).Count -eq 0
$apkBadgingOk = $apks.Count -gt 0 -and @($apkBadgingStatuses.Values | Where-Object { $_ -notlike 'OK*' }).Count -eq 0

$release = $null
$releaseError = ''
try {
    $releaseOutput = @(gh release view $Tag --repo $Repo --json tagName,name,url,assets 2>&1)
    if ($LASTEXITCODE -eq 0 -and $releaseOutput.Count -gt 0) {
        $release = ($releaseOutput -join "`n") | ConvertFrom-Json
    } elseif ($releaseOutput.Count -gt 0) {
        $releaseError = (($releaseOutput | ForEach-Object { [string]$_ }) -join "`n").Trim()
    }
} catch {
    $releaseError = $_.Exception.Message
}
if (-not $release -and [string]::IsNullOrWhiteSpace($releaseError)) {
    $releaseError = 'gh release view failed or returned no output'
}

$assetRows = @()
if ($release -and $release.assets) {
    foreach ($asset in $release.assets) {
        if ($asset.name -eq $OutputName) {
            continue
        }
        $assetName = Escape-MarkdownTableCell -Value $asset.name
        $assetSize = Format-Bytes -Bytes ([int64]$asset.size)
        $assetDigest = Escape-MarkdownTableCell -Value $asset.digest
        $assetRows += "| $assetName | $assetSize | $assetDigest |"
    }
}

$checks = @(
    @{ Name = 'gradle version name'; Ok = -not [string]::IsNullOrWhiteSpace($versionName); Detail = $versionName },
    @{ Name = 'gradle version code'; Ok = -not [string]::IsNullOrWhiteSpace($versionCode); Detail = $versionCode },
    @{ Name = 'APK exists'; Ok = $apks.Count -gt 0; Detail = "$($apks.Count) APK file(s)" },
    @{ Name = 'APK signatures'; Ok = $apkSignaturesOk; Detail = $(if ($apkSignaturesOk) { 'apksigner verify passed' } else { 'one or more APK signatures failed' }) },
    @{ Name = 'APK zipalign'; Ok = $apkZipalignOk; Detail = $(if ($apkZipalignOk) { 'zipalign check passed' } else { 'one or more APK zipalign checks failed' }) },
    @{ Name = 'APK badging'; Ok = $apkBadgingOk; Detail = $(if ($apkBadgingOk) { 'aapt badging passed' } else { 'one or more APK badging checks failed' }) },
    @{ Name = 'tracked git files clean'; Ok = $gitClean; Detail = $(if ($gitClean) { 'clean' } else { 'tracked changes are present before final commit' }) },
    @{ Name = 'GitHub release visible'; Ok = [bool]$release; Detail = $(if ($release) { $release.url } else { $releaseError }) }
)

$repoCode = Format-MarkdownCodeSpan -Value $Repo
$branchCode = Format-MarkdownCodeSpan -Value (@($gitBranch) -join "`n")
$commitCode = Format-MarkdownCodeSpan -Value (@($gitHead) -join "`n")
$versionNameCode = Format-MarkdownCodeSpan -Value $versionName
$versionCodeSpan = Format-MarkdownCodeSpan -Value $versionCode
$tagCode = Format-MarkdownCodeSpan -Value $Tag

$lines = @(
    "# YumeBox Study Release Health",
    '',
    "Generated: $(Get-Date -Format o)",
    "Repository: $repoCode",
    "Branch: $branchCode",
    "Commit: $commitCode",
    "Version: $versionNameCode / $versionCodeSpan",
    "Tag: $tagCode",
    '',
    '## Checks',
    '',
    '| Check | Status | Detail |',
    '|---|---|---|'
)

foreach ($check in $checks) {
    $status = if ($check.Ok) { 'OK' } else { 'FAIL' }
    $checkName = Escape-MarkdownTableCell -Value $check.Name
    $detail = Escape-MarkdownTableCell -Value $check.Detail
    $lines += "| $checkName | $status | $detail |"
}

$lines += @(
    '',
    '## APK',
    '',
    '| File | Size | SHA-256 | Signature | Zipalign | Badging | Last Modified |',
    '|---|---:|---|---|---|---|---|'
)
if ($apks.Count -gt 0) {
    foreach ($apk in $apks) {
        $apkSha256 = Format-MarkdownCodeSpan -Value (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $apkSize = Format-Bytes -Bytes $apk.Length
        $apkLastWrite = $apk.LastWriteTime.ToString('o')
        $relative = Escape-MarkdownTableCell -Value (Resolve-Path -LiteralPath $apk.FullName -Relative)
        $apkSignatureStatus = Escape-MarkdownTableCell -Value $apkSignatureStatuses[$apk.FullName]
        $apkZipalignStatus = Escape-MarkdownTableCell -Value $apkZipalignStatuses[$apk.FullName]
        $apkBadgingStatus = Escape-MarkdownTableCell -Value $apkBadgingStatuses[$apk.FullName]
        $lines += "| $relative | $apkSize | $apkSha256 | $apkSignatureStatus | $apkZipalignStatus | $apkBadgingStatus | $apkLastWrite |"
    }
} else {
    $lines += "| missing | - | - | - | - | - | - |"
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

$failedChecks = @($checks | Where-Object { -not [bool]$_.Ok })
if ($failedChecks.Count -gt 0) {
    $failedCheckNames = (($failedChecks | ForEach-Object { [string]$_.Name }) -join ', ')
    [Console]::Error.WriteLine("Release health failed checks: $failedCheckNames")
    exit 1
}
