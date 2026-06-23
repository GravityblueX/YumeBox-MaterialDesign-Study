param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Repo = 'GravityblueX/YumeBox-MaterialDesign-Study',
    [string]$Tag = '',
    [string]$AndroidSdkRoot = '',
    [string]$DownloadDir = '',
    [string]$MarkdownPath = '',
    [string]$JsonPath = ''
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

function Invoke-Cmd {
    param([string]$Command)
    $output = cmd /c $Command
    return @{
        ExitCode = $LASTEXITCODE
        Output = @($output)
    }
}

function Get-RegexValue {
    param(
        [string]$Text,
        [string]$Pattern
    )
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }
    $match = [regex]::Match($Text, $Pattern)
    if (-not $match.Success) {
        return ''
    }
    return $match.Groups[1].Value
}

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -ge 1MB) {
        return ('{0:N2} MB' -f ($Bytes / 1MB))
    }
    return ('{0:N0} bytes' -f $Bytes)
}

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
}

function Parse-Badging {
    param([string[]]$Output)
    $packageLine = $Output | Where-Object { $_ -match '^package:' } | Select-Object -First 1
    $sdkLine = $Output | Where-Object { $_ -match '^sdkVersion' } | Select-Object -First 1
    $targetSdkLine = $Output | Where-Object { $_ -match '^targetSdkVersion' } | Select-Object -First 1
    $labelLine = $Output | Where-Object { $_ -match '^application-label:' } | Select-Object -First 1
    $nativeLine = $Output | Where-Object { $_ -match '^native-code:' } | Select-Object -First 1
    $abis = @()
    foreach ($match in [regex]::Matches([string]$nativeLine, "'([^']+)'")) {
        $abis += $match.Groups[1].Value
    }

    return [ordered]@{
        packageLine = [string]$packageLine
        packageName = Get-RegexValue -Text ([string]$packageLine) -Pattern "name='([^']+)'"
        versionCode = Get-RegexValue -Text ([string]$packageLine) -Pattern "versionCode='([^']+)'"
        versionName = Get-RegexValue -Text ([string]$packageLine) -Pattern "versionName='([^']+)'"
        compileSdkVersion = Get-RegexValue -Text ([string]$packageLine) -Pattern "compileSdkVersion='([^']+)'"
        minSdkVersion = Get-RegexValue -Text ([string]$sdkLine) -Pattern "sdkVersion:'([^']+)'"
        targetSdkVersion = Get-RegexValue -Text ([string]$targetSdkLine) -Pattern "targetSdkVersion:'([^']+)'"
        applicationLabel = Get-RegexValue -Text ([string]$labelLine) -Pattern "application-label:'([^']+)'"
        nativeAbis = $abis
    }
}

function Parse-Signature {
    param(
        [int]$ExitCode,
        [string[]]$Output
    )
    $v2Line = $Output | Where-Object { $_ -match '^Verified using v2' } | Select-Object -First 1
    $v3Line = $Output | Where-Object { $_ -match '^Verified using v3 scheme' } | Select-Object -First 1
    $v31Line = $Output | Where-Object { $_ -match '^Verified using v3\.1' } | Select-Object -First 1
    $signerLine = $Output | Where-Object { $_ -match '^Signer #1 certificate DN:' } | Select-Object -First 1

    return [ordered]@{
        ok = ($ExitCode -eq 0)
        v2 = ([string]$v2Line -match ': true')
        v3 = ([string]$v3Line -match ': true')
        v31 = ([string]$v31Line -match ': true')
        signer = Get-RegexValue -Text ([string]$signerLine) -Pattern '^Signer #1 certificate DN:\s*(.+)$'
        highlights = @($Output | Where-Object { $_ -match '^(Verifies|Verified using v2|Verified using v3|Signer #1 certificate DN)' })
    }
}

function New-MarkdownReport {
    param([hashtable]$Report)
    $lines = @(
        "# APK Installability Report - $($Report.tag)",
        '',
        "Generated: $($Report.generatedAt)",
        "Repository: ``$($Report.repo)``",
        "Release: $($Report.releaseUrl)",
        "Android SDK: ``$($Report.androidSdkRoot)``",
        "Build tools: ``$($Report.buildToolsDir)``",
        '',
        '## Result',
        '',
        $(if ($Report.ok) { 'Installability report passed.' } else { 'Installability report failed.' }),
        '',
        '## APK Assets',
        '',
        '| APK | Size | SHA-256 | GitHub digest | Digest match | zipalign | badging | signature |',
        '|---|---:|---|---|---|---|---|---|'
    )

    foreach ($apk in $Report.apks) {
        $digestMatch = if ($null -eq $apk.githubDigestMatches) { 'n/a' } elseif ($apk.githubDigestMatches) { 'OK' } else { 'FAIL' }
        $signature = if ($apk.signature.ok) { "OK (v2=$($apk.signature.v2), v3=$($apk.signature.v3))" } else { 'FAIL' }
        $lines += "| ``$($apk.name)`` | $(Format-Bytes -Bytes ([int64]$apk.size)) | ``$($apk.sha256)`` | ``$($apk.githubDigest)`` | $digestMatch | $($apk.zipalign.status) | $($apk.badging.status) | $signature |"
    }

    $lines += @(
        '',
        '## Metadata',
        '',
        '| APK | Package | Version | SDK | Label | Native ABI |',
        '|---|---|---|---|---|---|'
    )

    foreach ($apk in $Report.apks) {
        $metadata = $apk.badging.metadata
        $version = "$($metadata.versionName) / $($metadata.versionCode)"
        $sdk = "min $($metadata.minSdkVersion), target $($metadata.targetSdkVersion), compile $($metadata.compileSdkVersion)"
        $abis = ($metadata.nativeAbis -join ', ')
        $lines += "| ``$($apk.name)`` | ``$($metadata.packageName)`` | ``$version`` | $sdk | $($metadata.applicationLabel) | ``$abis`` |"
    }

    $lines += @(
        '',
        '## Failures'
    )
    if ($Report.failures.Count -eq 0) {
        $lines += ''
        $lines += '- none'
    } else {
        $lines += ''
        foreach ($failure in $Report.failures) {
            $lines += "- $failure"
        }
    }

    $lines += @(
        '',
        '## Notes',
        '',
        '- This report checks APK files downloaded from the GitHub Release.',
        '- It compares local SHA-256 values with GitHub Release asset digests when available.',
        '- It validates Android installability signals with zipalign, aapt badging, and apksigner.',
        '- It does not run `adb install`; use `verify-installable-apk.ps1 -Install` with a connected device for that final check.',
        ''
    )
    return $lines -join "`n"
}

$versionName = Read-GradleProperty 'project.version.name'
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "v$versionName"
}
if ([string]::IsNullOrWhiteSpace($DownloadDir)) {
    $DownloadDir = Join-Path $env:TEMP "YumeBox-Study-$Tag-report"
}
if ([string]::IsNullOrWhiteSpace($MarkdownPath)) {
    $MarkdownPath = Join-Path $ProjectRoot "docs\apk-installability-report-$Tag.md"
}
if ([string]::IsNullOrWhiteSpace($JsonPath)) {
    $JsonPath = Join-Path $ProjectRoot "docs\apk-installability-report-$Tag.json"
}

$sdkRoot = Resolve-AndroidSdkRoot
$buildToolsDir = Resolve-BuildToolsDir -SdkRoot $sdkRoot
$expectedApplicationId = Read-GradleProperty 'project.applicationId'
$expectedVersionName = Read-GradleProperty 'project.version.name'
$expectedVersionCode = Read-GradleProperty 'project.version.code'
$expectedAbiList = (Read-GradleProperty 'abi.app.list').Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }

Write-Host "Downloading APK assets from $Repo@$Tag"
Remove-Item -LiteralPath $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $DownloadDir | Out-Null

$releaseJson = gh release view $Tag --repo $Repo --json tagName,name,url,assets
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
$release = $releaseJson | ConvertFrom-Json

gh release download $Tag --repo $Repo --pattern '*.apk' --dir $DownloadDir
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$assetByName = @{}
foreach ($asset in $release.assets) {
    $assetByName[$asset.name] = $asset
}

$apkFiles = @(Get-ChildItem -LiteralPath $DownloadDir -Filter '*.apk' | Sort-Object Name)
$failures = @()
$apkReports = @()

if ($apkFiles.Count -eq 0) {
    $failures += 'No APK assets were downloaded from the release.'
}

foreach ($apk in $apkFiles) {
    $sha256 = (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $githubDigest = ''
    $githubDigestMatches = $null
    if ($assetByName.ContainsKey($apk.Name)) {
        $githubDigest = [string]$assetByName[$apk.Name].digest
        if (-not [string]::IsNullOrWhiteSpace($githubDigest)) {
            $githubDigestMatches = ($githubDigest.ToLowerInvariant() -eq "sha256:$sha256")
            if (-not $githubDigestMatches) {
                $failures += "GitHub digest mismatch: $($apk.Name)"
            }
        }
    } else {
        $failures += "Release asset metadata missing for $($apk.Name)"
    }

    $zipalign = Invoke-Cmd ('"{0}" -c -p 4 "{1}" 2>&1' -f (Join-Path $buildToolsDir 'zipalign.exe'), $apk.FullName)
    if ($zipalign.ExitCode -ne 0) {
        $failures += "zipalign failed: $($apk.Name)"
    }

    $badging = Invoke-Cmd ('"{0}" dump badging "{1}" 2>&1' -f (Join-Path $buildToolsDir 'aapt.exe'), $apk.FullName)
    $metadata = [ordered]@{}
    if ($badging.ExitCode -eq 0) {
        $metadata = Parse-Badging -Output $badging.Output
        if ($metadata.packageName -ne $expectedApplicationId) {
            $failures += "unexpected applicationId in $($apk.Name): $($metadata.packageName)"
        }
        if ($metadata.versionCode -ne $expectedVersionCode) {
            $failures += "unexpected versionCode in $($apk.Name): $($metadata.versionCode)"
        }
        if ($metadata.versionName -ne $expectedVersionName) {
            $failures += "unexpected versionName in $($apk.Name): $($metadata.versionName)"
        }
        foreach ($abi in $expectedAbiList) {
            if ($metadata.nativeAbis -notcontains $abi) {
                $failures += "missing native ABI $abi in $($apk.Name)"
            }
        }
    } else {
        $failures += "aapt badging failed: $($apk.Name)"
    }

    $signature = Invoke-Cmd ('"{0}" verify --verbose --print-certs "{1}" 2>&1' -f (Join-Path $buildToolsDir 'apksigner.bat'), $apk.FullName)
    $signatureInfo = Parse-Signature -ExitCode $signature.ExitCode -Output $signature.Output
    if ($signature.ExitCode -ne 0) {
        $failures += "signature verify failed: $($apk.Name)"
    }

    $apkReports += [ordered]@{
        name = $apk.Name
        path = $apk.FullName
        size = $apk.Length
        sha256 = $sha256
        githubDigest = $githubDigest
        githubDigestMatches = $githubDigestMatches
        zipalign = [ordered]@{
            ok = ($zipalign.ExitCode -eq 0)
            status = $(if ($zipalign.ExitCode -eq 0) { 'OK' } else { 'FAIL' })
            output = $zipalign.Output
        }
        badging = [ordered]@{
            ok = ($badging.ExitCode -eq 0)
            status = $(if ($badging.ExitCode -eq 0) { 'OK' } else { 'FAIL' })
            metadata = $metadata
            output = $badging.Output
        }
        signature = $signatureInfo
    }
}

$report = [ordered]@{
    reportType = 'apk_installability_release_report'
    generatedAt = (Get-Date -Format o)
    ok = ($failures.Count -eq 0)
    repo = $Repo
    tag = $Tag
    releaseUrl = $release.url
    projectRoot = $ProjectRoot
    downloadDir = $DownloadDir
    androidSdkRoot = $sdkRoot
    buildToolsDir = $buildToolsDir
    expectations = [ordered]@{
        applicationId = $expectedApplicationId
        versionName = $expectedVersionName
        versionCode = $expectedVersionCode
        nativeAbis = @($expectedAbiList)
    }
    apks = @($apkReports)
    failures = @($failures)
}

Ensure-ParentDirectory -Path $MarkdownPath
Ensure-ParentDirectory -Path $JsonPath
($report | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $JsonPath -Encoding UTF8
New-MarkdownReport -Report $report | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

Write-Host "JSON report: $JsonPath"
Write-Host "Markdown report: $MarkdownPath"

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host '=== FAILURES ==='
    $failures | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host 'APK installability release report passed.'
