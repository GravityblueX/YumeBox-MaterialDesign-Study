param(
    [string]$Tag = "",
    [switch]$Json,
    [string]$JsonOut = "",
    [string]$MarkdownOut = ""
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail
    )
    $script:Checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        detail = $Detail
    })
}

function Read-PropertiesFile {
    param([string]$Path)
    $props = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
            continue
        }
        $parts = $trimmed -split "=", 2
        if ($parts.Count -eq 2) {
            $props[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
    return $props
}

function Test-FileContains {
    param(
        [string]$Path,
        [string]$Needle
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $content = Get-Content -LiteralPath $Path -Raw
    return $content.Contains($Needle)
}

function Convert-ToMarkdown {
    param($Payload)
    $status = if ($Payload.ok) { "OK" } else { "FAIL" }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Study APK Contract - $($Payload.tag)")
    $lines.Add("")
    $lines.Add("Generated: $($Payload.generatedAt)")
    $lines.Add("ProjectRoot: ``$($Payload.projectRoot)``")
    $lines.Add("Status: ``$status``")
    $lines.Add("")
    $lines.Add("## Checks")
    $lines.Add("")
    $lines.Add("| Check | Result | Detail |")
    $lines.Add("|---|---|---|")
    foreach ($check in $Payload.checks) {
        $result = if ($check.ok) { "OK" } else { "FAIL" }
        $detail = [string]$check.detail
        $detail = $detail.Replace("|", "\|")
        $lines.Add("| $($check.name) | $result | $detail |")
    }
    $lines.Add("")
    return ($lines -join "`n")
}

$gradlePath = Join-Path $ProjectRoot "gradle.properties"
Add-Check "gradle.properties exists" (Test-Path -LiteralPath $gradlePath) $gradlePath
if (-not (Test-Path -LiteralPath $gradlePath)) {
    throw "gradle.properties not found"
}

$props = Read-PropertiesFile -Path $gradlePath
$versionName = [string]$props["project.version.name"]
$versionCode = [string]$props["project.version.code"]
$applicationId = [string]$props["project.applicationId"]
$abiList = [string]$props["abi.app.list"]

if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "v$versionName"
}

Add-Check "version name present" (-not [string]::IsNullOrWhiteSpace($versionName)) $versionName
Add-Check "version code present" (-not [string]::IsNullOrWhiteSpace($versionCode)) $versionCode
Add-Check "application id present" (-not [string]::IsNullOrWhiteSpace($applicationId)) $applicationId
$abiConfigured = (($abiList -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq "arm64-v8a" } | Measure-Object).Count -gt 0)
Add-Check "arm64 ABI configured" $abiConfigured $abiList

$requiredFiles = @(
    "README.md",
    "RELEASE_STUDY.md",
    "docs\apk-release-assurance.md",
    "docs\apk-installability-report-$Tag.md",
    "docs\apk-installability-report-$Tag.json",
    "docs\apk-permission-review-$Tag.md",
    "docs\apk-permission-review-$Tag.json",
    "docs\release-asset-manifest-$Tag.md",
    "docs\release-asset-manifest-$Tag.json",
    "docs\release-provenance-$Tag.md",
    "docs\release-provenance-$Tag.json",
    "docs\build-environment-$Tag.md",
    "docs\build-environment-$Tag.json",
    "scripts\build-apk-strict.ps1",
    "scripts\verify-installable-apk.ps1",
    "scripts\apk-installability-report.ps1",
    "scripts\apk-permission-review.ps1",
    "scripts\release-asset-manifest.ps1",
    "scripts\release-provenance.ps1",
    "scripts\build-environment-report.ps1",
    "scripts\publish-apk-assets.ps1"
)

foreach ($relative in $requiredFiles) {
    $path = Join-Path $ProjectRoot $relative
    Add-Check "required file $relative" (Test-Path -LiteralPath $path) $relative
}

Add-Check "README mentions tag" (Test-FileContains -Path (Join-Path $ProjectRoot "README.md") -Needle $Tag) $Tag
Add-Check "release flow mentions installability" (Test-FileContains -Path (Join-Path $ProjectRoot "RELEASE_STUDY.md") -Needle "verify-installable-apk.ps1") "verify-installable-apk.ps1"

$reportPath = Join-Path $ProjectRoot "docs\apk-installability-report-$Tag.json"
if (Test-Path -LiteralPath $reportPath) {
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $apks = @($report.apks)
    Add-Check "report ok flag" ([bool]$report.ok) "ok=$($report.ok)"
    Add-Check "report tag matches" ([string]$report.tag -eq $Tag) "tag=$($report.tag)"
    Add-Check "report package matches gradle" ([string]$report.expectations.applicationId -eq $applicationId) "$($report.expectations.applicationId)"
    Add-Check "report version name matches gradle" ([string]$report.expectations.versionName -eq $versionName) "$($report.expectations.versionName)"
    Add-Check "report version code matches gradle" ([string]$report.expectations.versionCode -eq $versionCode) "$($report.expectations.versionCode)"
    $debugApks = @($apks | Where-Object { [string]$_.name -like "*debug.apk" })
    $releaseApks = @($apks | Where-Object { [string]$_.name -like "*release.apk" })
    $hasDebugApk = ($debugApks.Count -ge 1)
    $hasReleaseApk = ($releaseApks.Count -ge 1)
    Add-Check "report has debug and release APKs" ($hasDebugApk -and $hasReleaseApk) "$($apks.Count) APKs"

    foreach ($apk in $apks) {
        $prefix = "APK $($apk.name)"
        Add-Check "$prefix digest matches" ([bool]$apk.githubDigestMatches) "$($apk.githubDigest)"
        Add-Check "$prefix zipalign" ([bool]$apk.zipalign.ok) "$($apk.zipalign.status)"
        Add-Check "$prefix badging" ([bool]$apk.badging.ok) "$($apk.badging.status)"
        Add-Check "$prefix signature" ([bool]$apk.signature.ok) "$($apk.signature.signer)"
        Add-Check "$prefix package metadata" ([string]$apk.badging.metadata.packageName -eq $applicationId) "$($apk.badging.metadata.packageName)"
        Add-Check "$prefix version metadata" ([string]$apk.badging.metadata.versionName -eq $versionName -and [string]$apk.badging.metadata.versionCode -eq $versionCode) "$($apk.badging.metadata.versionName)/$($apk.badging.metadata.versionCode)"
        Add-Check "$prefix ABI metadata" (@($apk.badging.metadata.nativeAbis) -contains "arm64-v8a") "$(@($apk.badging.metadata.nativeAbis) -join ',')"
    }
}

$permissionReviewPath = Join-Path $ProjectRoot "docs\apk-permission-review-$Tag.json"
if (Test-Path -LiteralPath $permissionReviewPath) {
    $permissionReview = Get-Content -LiteralPath $permissionReviewPath -Raw | ConvertFrom-Json
    Add-Check "permission review ok flag" ([bool]$permissionReview.ok) "ok=$($permissionReview.ok)"
    Add-Check "permission review tag matches" ([string]$permissionReview.tag -eq $Tag) "tag=$($permissionReview.tag)"
    Add-Check "permission review status recorded" (-not [string]::IsNullOrWhiteSpace([string]$permissionReview.status)) "status=$($permissionReview.status)"
    Add-Check "permission review covers APKs" (@($permissionReview.apks).Count -ge 1) "$(@($permissionReview.apks).Count) APKs"
}

$assetManifestPath = Join-Path $ProjectRoot "docs\release-asset-manifest-$Tag.json"
if (Test-Path -LiteralPath $assetManifestPath) {
    $assetManifest = Get-Content -LiteralPath $assetManifestPath -Raw | ConvertFrom-Json
    Add-Check "release asset manifest ok flag" ([bool]$assetManifest.ok) "ok=$($assetManifest.ok)"
    Add-Check "release asset manifest tag matches" ([string]$assetManifest.tag -eq $Tag) "tag=$($assetManifest.tag)"
    Add-Check "release asset manifest APK assets" ([int]$assetManifest.summary.debugApkCount -ge 1 -and [int]$assetManifest.summary.releaseApkCount -ge 1) "debug=$($assetManifest.summary.debugApkCount), release=$($assetManifest.summary.releaseApkCount)"
    Add-Check "release asset manifest gates recorded" (@($assetManifest.gates).Count -ge 10) "$(@($assetManifest.gates).Count) gates"
}

$provenancePath = Join-Path $ProjectRoot "docs\release-provenance-$Tag.json"
if (Test-Path -LiteralPath $provenancePath) {
    $provenance = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json
    Add-Check "release provenance ok flag" ([bool]$provenance.ok) "ok=$($provenance.ok)"
    Add-Check "release provenance tag matches" ([string]$provenance.tag -eq $Tag) "tag=$($provenance.tag)"
    Add-Check "release provenance predicate recorded" ([string]$provenance.predicateType -eq "https://slsa.dev/provenance/v1") "$($provenance.predicateType)"
    Add-Check "release provenance APK subjects" (@($provenance.subject).Count -ge 2) "$(@($provenance.subject).Count) subject(s)"
}

$buildEnvironmentPath = Join-Path $ProjectRoot "docs\build-environment-$Tag.json"
if (Test-Path -LiteralPath $buildEnvironmentPath) {
    $buildEnvironment = Get-Content -LiteralPath $buildEnvironmentPath -Raw | ConvertFrom-Json
    Add-Check "build environment ok flag" ([bool]$buildEnvironment.ok) "ok=$($buildEnvironment.ok)"
    Add-Check "build environment tag matches" ([string]$buildEnvironment.tag -eq $Tag) "tag=$($buildEnvironment.tag)"
    Add-Check "build environment version matches gradle" ([string]$buildEnvironment.project.versionName -eq $versionName -and [string]$buildEnvironment.project.versionCode -eq $versionCode) "$($buildEnvironment.project.versionName)/$($buildEnvironment.project.versionCode)"
    Add-Check "build environment build-tools recorded" (-not [string]::IsNullOrWhiteSpace([string]$buildEnvironment.android.selectedBuildTools)) "$($buildEnvironment.android.selectedBuildTools)"
}

$checkArray = @()
foreach ($check in $Checks) {
    $checkArray += $check
}
$failed = @($checkArray | Where-Object { -not [bool]$_.ok })
$payload = New-Object psobject -Property ([ordered]@{
    reportType = "study_apk_contract"
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $ProjectRoot
    tag = $Tag
    ok = ($failed.Count -eq 0)
    checks = $checkArray
    failures = @($failed)
})

if ([string]::IsNullOrWhiteSpace($JsonOut)) {
    $JsonOut = Join-Path $ProjectRoot "docs\study-apk-contract-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($MarkdownOut)) {
    $MarkdownOut = Join-Path $ProjectRoot "docs\study-apk-contract-$Tag.md"
}

if ($JsonOut) {
    $jsonParent = Split-Path -Parent $JsonOut
    if ($jsonParent) { New-Item -ItemType Directory -Force -Path $jsonParent | Out-Null }
    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $JsonOut -Encoding UTF8
}
if ($MarkdownOut) {
    $markdownParent = Split-Path -Parent $MarkdownOut
    if ($markdownParent) { New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null }
    Convert-ToMarkdown -Payload $payload | Set-Content -LiteralPath $MarkdownOut -Encoding UTF8
}

if ($Json) {
    $payload | ConvertTo-Json -Depth 8
} else {
    Write-Host "=== Study APK contract ==="
    Write-Host "ProjectRoot=$ProjectRoot"
    Write-Host "Tag=$Tag"
    foreach ($check in $Checks) {
        $status = if ($check.ok) { "OK" } else { "FAIL" }
        Write-Host ("{0} {1} - {2}" -f $status, $check.name, $check.detail)
    }
    Write-Host "JsonOut=$JsonOut"
    Write-Host "MarkdownOut=$MarkdownOut"
}

if ($failed.Count -gt 0) {
    exit 1
}
