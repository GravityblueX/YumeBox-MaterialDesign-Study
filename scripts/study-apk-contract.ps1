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

function Test-CodeSpanPadsBoundaryBackticks {
    param([string]$Path)
    return (Test-FileContains -Path $Path -Needle '$padded = if ($text.StartsWith(''`'') -or $text.EndsWith(''`''))')
}

function Escape-MarkdownCell {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    return $text.Replace("`r`n", " ").Replace("`n", " ").Replace("`r", " ").Replace("|", "\|")
}

function Format-MarkdownCodeSpan {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    $text = ([string]$Value).Replace("`r`n", " ").Replace("`n", " ").Replace("`r", " ")
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $maxTicks = 0
    foreach ($match in [regex]::Matches($text, '`+')) {
        if ($match.Value.Length -gt $maxTicks) { $maxTicks = $match.Value.Length }
    }
    $fence = '`' * ($maxTicks + 1)
    $padded = if ($text.StartsWith('`') -or $text.EndsWith('`')) { " $text " } else { $text }
    return "$fence$padded$fence"
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $normalized = $Content -replace "`r`n?", "`n"
    if (-not $normalized.EndsWith("`n")) {
        $normalized += "`n"
    }
    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($Path, $normalized, $encoding)
}

function Normalize-Sha256Digest {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    return ($text -replace "^sha256:", "").ToLowerInvariant()
}

function Get-FileSha256 {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    $content = [System.IO.File]::ReadAllText($Path)
    $normalized = $content -replace "`r`n?", "`n"
    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $bytes = $encoding.GetBytes($normalized)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
}

function Convert-ToMarkdown {
    param($Payload)
    $status = if ($Payload.ok) { "OK" } else { "FAIL" }
    $projectRootCode = Format-MarkdownCodeSpan -Value $Payload.projectRoot
    $statusCode = Format-MarkdownCodeSpan -Value $status
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Study APK Contract - $($Payload.tag)")
    $lines.Add("")
    $lines.Add("Generated: $($Payload.generatedAt)")
    $lines.Add("ProjectRoot: $projectRootCode")
    $lines.Add("Status: $statusCode")
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add("| Field | Value |")
    $lines.Add("|---|---|")
    $lines.Add("| Check count | $($Payload.summary.checkCount) |")
    $lines.Add("| Failure count | $($Payload.summary.failureCount) |")
    $lines.Add("| Required files | $($Payload.summary.requiredFileCount) |")
    $lines.Add("| APK evidence count | $($Payload.summary.apkEvidenceCount) |")
    $lines.Add("| Release APK asset count | $($Payload.summary.releaseAssetApkCount) |")
    $lines.Add("| Provenance subject count | $($Payload.summary.provenanceSubjectCount) |")
    $lines.Add("| Device matrix status | $(Format-MarkdownCodeSpan -Value $Payload.summary.deviceMatrixStatus) |")
    $lines.Add("| Permission review status | $(Format-MarkdownCodeSpan -Value $Payload.summary.permissionReviewStatus) |")
    $lines.Add("")
    $lines.Add("## Checks")
    $lines.Add("")
    $lines.Add("| Check | Result | Detail |")
    $lines.Add("|---|---|---|")
    foreach ($check in $Payload.checks) {
        $result = if ($check.ok) { "OK" } else { "FAIL" }
        $name = Escape-MarkdownCell -Value $check.name
        $detail = Escape-MarkdownCell -Value $check.detail
        $lines.Add("| $name | $result | $detail |")
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
    "docs\device-install-matrix-$Tag.md",
    "docs\device-install-matrix-$Tag.json",
    "docs\apk-permission-review-$Tag.md",
    "docs\apk-permission-review-$Tag.json",
    "docs\apk-permission-justification-$Tag.md",
    "docs\apk-permission-justification-$Tag.json",
    "docs\release-asset-manifest-$Tag.md",
    "docs\release-asset-manifest-$Tag.json",
    "docs\release-provenance-$Tag.md",
    "docs\release-provenance-$Tag.json",
    "docs\build-environment-$Tag.md",
    "docs\build-environment-$Tag.json",
    "scripts\build-apk-strict.ps1",
    "scripts\verify-installable-apk.ps1",
    "scripts\release-health.ps1",
    "scripts\apk-installability-report.ps1",
    "scripts\device-install-matrix.ps1",
    "scripts\apk-permission-review.ps1",
    "scripts\apk-permission-justification.ps1",
    "scripts\release-asset-manifest.ps1",
    "scripts\release-provenance.ps1",
    "scripts\build-environment-report.ps1",
    "scripts\publish-apk-assets.ps1"
)

foreach ($relative in $requiredFiles) {
    $path = Join-Path $ProjectRoot $relative
    Add-Check "required file $relative" (Test-Path -LiteralPath $path) $relative
}
Add-Check "study contract pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $PSCommandPath) "boundary backtick padding"
Add-Check "study contract emits summary section" (Test-FileContains -Path $PSCommandPath -Needle '## Summary') "summary section"
Add-Check "study contract records failure count" (Test-FileContains -Path $PSCommandPath -Needle 'failureCount = $failed.Count') "summary failure count"
Add-Check "study contract writes UTF-8 without BOM" (Test-FileContains -Path $PSCommandPath -Needle 'Write-Utf8NoBom') "UTF-8 no BOM writer"
Add-Check "study contract normalizes SHA-256 digests" (Test-FileContains -Path $PSCommandPath -Needle 'function Normalize-Sha256Digest') "digest normalization"
Add-Check "study contract cross-checks provenance APK names" (Test-FileContains -Path $PSCommandPath -Needle 'provenance APK subjects match release asset names') "provenance asset name parity"
Add-Check "study contract cross-checks provenance APK digests" (Test-FileContains -Path $PSCommandPath -Needle 'provenance APK digests match release assets') "provenance asset digest parity"
Add-Check "study contract cross-checks provenance material digests" (Test-FileContains -Path $PSCommandPath -Needle 'release provenance material digest matches release asset manifest') "provenance material digest parity"
Add-Check "study contract checks release health markdown" (Test-FileContains -Path $PSCommandPath -Needle 'release health markdown tag matches') "release health markdown"
Add-Check "study contract cross-checks release health APK digests" (Test-FileContains -Path $PSCommandPath -Needle 'release health markdown lists APK digests') "release health APK digests"

$strictBuildPath = Join-Path $ProjectRoot "scripts\build-apk-strict.ps1"
Add-Check "strict build filters APKs by Gradle task" (Test-FileContains -Path $strictBuildPath -Needle "Get-ApkNamePatternForGradleTask") "Get-ApkNamePatternForGradleTask"
Add-Check "strict build logs APK name pattern" (Test-FileContains -Path $strictBuildPath -Needle "ApkNamePattern={0}") "ApkNamePattern log"
Add-Check "strict build preserves Gradle exit code" (Test-FileContains -Path $strictBuildPath -Needle "exit `$code") "exit `$code"
Add-Check "strict build creates Gradle cache dir" (Test-FileContains -Path $strictBuildPath -Needle 'New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME') "GRADLE_USER_HOME mkdir"
Add-Check "strict build supports ambient JAVA_HOME fallback" (Test-FileContains -Path $strictBuildPath -Needle '$ambientJavaHome = $env:JAVA_HOME') "ambient JAVA_HOME"
Add-Check "strict build exposes Gradle cache relocation" (Test-FileContains -Path $strictBuildPath -Needle '[string]$GradleUserHome') "GradleUserHome parameter"
Add-Check "strict build logs Gradle cache home" (Test-FileContains -Path $strictBuildPath -Needle 'GRADLE_USER_HOME={0}') "GRADLE_USER_HOME log"
Add-Check "strict build enforces Gradle cache free space" (Test-FileContains -Path $strictBuildPath -Needle 'MinGradleDriveFreeGb') "MinGradleDriveFreeGb"

$releaseHealthScriptPath = Join-Path $ProjectRoot "scripts\release-health.ps1"
Add-Check "release health requests release assets" (Test-FileContains -Path $releaseHealthScriptPath -Needle '--json tagName,name,url,assets') "gh release assets"
Add-Check "release health records asset digests" (Test-FileContains -Path $releaseHealthScriptPath -Needle '$asset.digest') "asset digest"
Add-Check "release health records APK SHA-256" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256') "APK SHA-256"
Add-Check "release health omits itself from asset table" (Test-FileContains -Path $releaseHealthScriptPath -Needle '$asset.name -eq $OutputName') "skip OutputName"
Add-Check "release health marks failed checks as FAIL" (Test-FileContains -Path $releaseHealthScriptPath -Needle "`$status = if (`$check.Ok) { 'OK' } else { 'FAIL' }") "FAIL status"
Add-Check "release health collects failed checks" (Test-FileContains -Path $releaseHealthScriptPath -Needle '$failedChecks = @($checks | Where-Object { -not [bool]$_.Ok })') "failedChecks"
Add-Check "release health exits nonzero on failure" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'if ($failedChecks.Count -gt 0)') "exit 1 on failures"
Add-Check "release health captures GitHub release errors" (Test-FileContains -Path $releaseHealthScriptPath -Needle '$releaseOutput = @(gh release view') "gh release stderr"
Add-Check "release health has release error fallback" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'gh release view failed or returned no output') "release error fallback"
Add-Check "release health only falls back when release is missing" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'if (-not $release -and [string]::IsNullOrWhiteSpace($releaseError))') "fallback requires missing release"
Add-Check "release health prints failed check names" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'Release health failed checks:') "failed check summary"
Add-Check "release health failure summary preserves explicit exit" (Test-FileContains -Path $releaseHealthScriptPath -Needle '[Console]::Error.WriteLine') "stderr without Write-Error termination"
Add-Check "release health escapes markdown table cells" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'function Escape-MarkdownTableCell') "table cell escaping"
Add-Check "release health escapes check details" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'Escape-MarkdownTableCell -Value $check.Detail') "check detail escaping"
Add-Check "release health escapes APK status fields" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'Escape-MarkdownTableCell -Value $apkSignatureStatuses[$apk.FullName]') "APK status escaping"
Add-Check "release health formats markdown code spans" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'function Format-MarkdownCodeSpan') "code span fencing"
Add-Check "release health code-spans APK SHA-256" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'Format-MarkdownCodeSpan -Value (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()') "APK SHA-256 code span"
Add-Check "release health pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $releaseHealthScriptPath) "boundary backtick padding"
Add-Check "release health code-spans repository header" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'Format-MarkdownCodeSpan -Value $Repo') "repository header code span"
Add-Check "release health code-spans version header" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'Format-MarkdownCodeSpan -Value $versionName') "version header code span"
Add-Check "release health code-spans tag header" (Test-FileContains -Path $releaseHealthScriptPath -Needle 'Format-MarkdownCodeSpan -Value $Tag') "tag header code span"

$installabilityReportScriptPath = Join-Path $ProjectRoot "scripts\apk-installability-report.ps1"
Add-Check "installability report escapes markdown table cells" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'function Escape-MarkdownTableCell') "table cell escaping"
Add-Check "installability report escapes APK status cells" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Escape-MarkdownTableCell -Value $apk.zipalign.status') "status escaping"
Add-Check "installability report escapes metadata labels" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Escape-MarkdownTableCell -Value $metadata.applicationLabel') "label escaping"
Add-Check "installability report formats markdown code spans" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'function Format-MarkdownCodeSpan') "code span fencing"
Add-Check "installability report code-spans APK names" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $apk.name') "APK name code span"
Add-Check "installability report pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $installabilityReportScriptPath) "boundary backtick padding"
Add-Check "installability report code-spans repository header" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $Report.repo') "repository header code span"
Add-Check "installability report code-spans Android SDK header" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $Report.androidSdkRoot') "Android SDK header code span"
Add-Check "installability report code-spans build tools header" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $Report.buildToolsDir') "build tools header code span"
Add-Check "installability report code-spans SHA-256 values" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $apk.sha256') "SHA-256 code span"
Add-Check "installability report code-spans GitHub digests" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $apk.githubDigest') "GitHub digest code span"
Add-Check "installability report code-spans package names" (Test-FileContains -Path $installabilityReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $metadata.packageName') "package name code span"

$releaseProvenanceScriptPath = Join-Path $ProjectRoot "scripts\release-provenance.ps1"
Add-Check "release provenance escapes markdown table cells" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'function Escape-MarkdownTableCell') "table cell escaping"
Add-Check "release provenance formats subject names as code spans" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Format-MarkdownCodeSpan -Value $subject.name') "subject name code span"
Add-Check "release provenance escapes gate details" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Escape-MarkdownTableCell -Value $gate.detail') "gate detail escaping"
Add-Check "release provenance formats markdown code spans" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'function Format-MarkdownCodeSpan') "code span fencing"
Add-Check "release provenance code-spans APK digests" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Format-MarkdownCodeSpan -Value $subject.digest.sha256') "digest code span"
Add-Check "release provenance code-spans predicate header" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Format-MarkdownCodeSpan -Value $payload.predicateType') "predicate header code span"
Add-Check "release provenance pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $releaseProvenanceScriptPath) "boundary backtick padding"
Add-Check "release provenance code-spans repository header" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Format-MarkdownCodeSpan -Value $Repo') "repository header code span"
Add-Check "release provenance code-spans status header" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Format-MarkdownCodeSpan -Value $status') "status header code span"
Add-Check "release provenance code-spans source commit header" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Format-MarkdownCodeSpan -Value $head') "source commit header code span"
Add-Check "release provenance code-spans package names" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Format-MarkdownCodeSpan -Value $subject.annotations.packageName') "package code span"
Add-Check "release provenance records dirty count" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'dirtyCountWhenGenerated') "dirty count evidence"
Add-Check "release provenance writes UTF-8 without BOM" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'Write-Utf8NoBom') "UTF-8 no BOM writer"
Add-Check "release provenance gates non-empty material URIs" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all materials have URIs') "material URI presence"
Add-Check "release provenance gates unique material URIs" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'material URIs are unique') "material URI uniqueness"
Add-Check "release provenance gates material digest evidence" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all materials have digest evidence') "material digest evidence"
Add-Check "release provenance gates canonical file material SHA-256" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all file materials have canonical sha256') "file material digest format"
Add-Check "release provenance gates expected file material URIs" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all file materials reference expected docs JSON') "file material evidence set"
Add-Check "release provenance gates canonical repo material commit" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'repo material has canonical git commit') "repo material commit format"
Add-Check "release provenance gates non-empty subject names" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all subjects have names') "subject name presence"
Add-Check "release provenance gates unique subject names" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'subject names are unique') "subject name uniqueness"
Add-Check "release provenance gates non-empty subject URIs" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all subjects have URIs') "subject URI presence"
Add-Check "release provenance gates unique subject URIs" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'subject URIs are unique') "subject URI uniqueness"
Add-Check "release provenance gates release-tag subject URIs" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all subjects match release tag asset URIs') "subject URI release tag"
Add-Check "release provenance gates GitHub HTTPS subject URIs" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all subjects use GitHub HTTPS release downloads') "subject URI GitHub HTTPS"
Add-Check "release provenance gates decoded subject URI filenames" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all subject URI filenames match names') "subject URI filename match"
Add-Check "release provenance gates positive subject sizes" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all subjects have positive sizes') "subject size gate"
Add-Check "release provenance gates canonical subject SHA-256" (Test-FileContains -Path $releaseProvenanceScriptPath -Needle 'all subjects have canonical sha256') "subject digest format"

$releaseAssetManifestScriptPath = Join-Path $ProjectRoot "scripts\release-asset-manifest.ps1"
Add-Check "release asset manifest escapes markdown table cells" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'function Escape-Md') "table cell escaping"
Add-Check "release asset manifest escapes newlines" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Replace("`r`n", "<br>")') "newline escaping"
Add-Check "release asset manifest escapes APK asset kind" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Escape-Md -Value $asset.kind') "asset kind escaping"
Add-Check "release asset manifest formats markdown code spans" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'function Format-MdCodeSpan') "code span fencing"
Add-Check "release asset manifest code-spans APK asset names" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Format-MdCodeSpan -Value $asset.name') "asset name code span"
Add-Check "release asset manifest code-spans repository header" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Format-MdCodeSpan -Value $Repo') "repository header code span"
Add-Check "release asset manifest pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $releaseAssetManifestScriptPath) "boundary backtick padding"
Add-Check "release asset manifest code-spans release header" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Format-MdCodeSpan -Value $payload.release.name') "release header code span"
Add-Check "release asset manifest code-spans status header" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Format-MdCodeSpan -Value $status') "status header code span"
Add-Check "release asset manifest code-spans APK asset digests" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Format-MdCodeSpan -Value (Normalize-Digest $asset.digest)') "APK digest code span"
Add-Check "release asset manifest code-spans supporting asset digests" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Format-MdCodeSpan -Value $asset.digest') "supporting digest code span"
Add-Check "release asset manifest gates non-empty asset names" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'all release assets have names') "asset name presence"
Add-Check "release asset manifest gates unique asset names" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'release asset names are unique') "asset name uniqueness"
Add-Check "release asset manifest gates non-empty asset URLs" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'all release assets have URLs') "asset URL presence"
Add-Check "release asset manifest gates unique asset URLs" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'release asset URLs are unique') "asset URL uniqueness"
Add-Check "release asset manifest gates positive asset sizes" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'all release assets have positive sizes') "asset size gate"
Add-Check "release asset manifest gates uploaded assets" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'all release assets are uploaded') "asset upload state gate"
Add-Check "release asset manifest gates canonical asset digests" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'all release asset digests are canonical SHA-256') "asset digest gate"
Add-Check "release asset manifest gates release-tag asset URLs" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'all release asset URLs match release tag') "asset URL tag gate"
Add-Check "release asset manifest gates GitHub HTTPS asset URLs" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'all release asset URLs use GitHub HTTPS downloads') "GitHub HTTPS asset URL gate"
Add-Check "release asset manifest gates decoded asset URL filenames" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'all release asset URL filenames match asset names') "asset URL filename match"
Add-Check "release asset manifest gates canonical APK digests" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'APK asset digests are canonical SHA-256') "canonical digest gate"
Add-Check "release asset manifest gates release-tag APK URLs" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'APK asset URLs match release tag') "release URL gate"
Add-Check "release asset manifest gates GitHub HTTPS APK URLs" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'APK asset URLs use GitHub HTTPS downloads') "GitHub HTTPS APK URL gate"
Add-Check "release asset manifest gates decoded APK URL filenames" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'APK asset URL filenames match names') "APK URL filename match"
Add-Check "release asset manifest writes UTF-8 without BOM" (Test-FileContains -Path $releaseAssetManifestScriptPath -Needle 'Write-Utf8NoBom') "UTF-8 no BOM writer"

$buildEnvironmentReportScriptPath = Join-Path $ProjectRoot "scripts\build-environment-report.ps1"
Add-Check "build environment report escapes markdown table cells" (Test-FileContains -Path $buildEnvironmentReportScriptPath -Needle 'function Escape-MarkdownTableCell') "table cell escaping"
Add-Check "build environment report escapes newlines" (Test-FileContains -Path $buildEnvironmentReportScriptPath -Needle 'Replace("`r`n", "<br>")') "newline escaping"
Add-Check "build environment report escapes gate details" (Test-FileContains -Path $buildEnvironmentReportScriptPath -Needle 'Escape-MarkdownTableCell -Value $gate.detail') "gate detail escaping"
Add-Check "build environment report formats markdown code spans" (Test-FileContains -Path $buildEnvironmentReportScriptPath -Needle 'function Format-MarkdownCodeSpan') "code span fencing"
Add-Check "build environment report code-spans SDK root" (Test-FileContains -Path $buildEnvironmentReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $sdkRoot') "SDK root code span"
Add-Check "build environment report pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $buildEnvironmentReportScriptPath) "boundary backtick padding"
Add-Check "build environment report code-spans command output" (Test-FileContains -Path $buildEnvironmentReportScriptPath -Needle 'Format-MarkdownCodeSpan -Value $line') "command output code span"

$permissionReviewScriptPath = Join-Path $ProjectRoot "scripts\apk-permission-review.ps1"
Add-Check "permission review escapes markdown table cells" (Test-FileContains -Path $permissionReviewScriptPath -Needle 'function Escape-MarkdownTableCell') "table cell escaping"
Add-Check "permission review escapes markdown text" (Test-FileContains -Path $permissionReviewScriptPath -Needle 'function Escape-MarkdownText') "inline text escaping"
Add-Check "permission review escapes attention reasons" (Test-FileContains -Path $permissionReviewScriptPath -Needle 'Escape-MarkdownText -Value $item.reason') "attention reason escaping"
Add-Check "permission review formats markdown code spans" (Test-FileContains -Path $permissionReviewScriptPath -Needle 'function Format-MarkdownCodeSpan') "code span fencing"
Add-Check "permission review code-spans APK summary names" (Test-FileContains -Path $permissionReviewScriptPath -Needle 'Format-MarkdownCodeSpan -Value $review.name') "APK summary code span"
Add-Check "permission review code-spans attention permissions" (Test-FileContains -Path $permissionReviewScriptPath -Needle 'Format-MarkdownCodeSpan -Value $item.permission') "attention permission code span"
Add-Check "permission review pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $permissionReviewScriptPath) "boundary backtick padding"
Add-Check "permission review code-spans status header" (Test-FileContains -Path $permissionReviewScriptPath -Needle 'Format-MarkdownCodeSpan -Value $payload.status') "status header code span"
Add-Check "permission review code-spans installability report path" (Test-FileContains -Path $permissionReviewScriptPath -Needle 'Format-MarkdownCodeSpan -Value $InstallabilityJson') "installability path code span"
Add-Check "permission review removes fixed attention code spans" (-not (Test-FileContains -Path $permissionReviewScriptPath -Needle '``$permissionName``')) "no fixed attention code span"
Add-Check "permission review removes fixed summary code spans" (-not (Test-FileContains -Path $permissionReviewScriptPath -Needle '``$reviewName``')) "no fixed summary code span"

$permissionJustificationScriptPath = Join-Path $ProjectRoot "scripts\apk-permission-justification.ps1"
Add-Check "permission justification escapes markdown table cells" (Test-FileContains -Path $permissionJustificationScriptPath -Needle 'function Escape-MarkdownCell') "table cell escaping"
Add-Check "permission justification accepts object table cells" (Test-FileContains -Path $permissionJustificationScriptPath -Needle '[object]$Value') "object-to-string normalization"
Add-Check "permission justification formats markdown code spans" (Test-FileContains -Path $permissionJustificationScriptPath -Needle 'function Format-MarkdownCodeSpan') "code span fencing"
Add-Check "permission justification code-spans status header" (Test-FileContains -Path $permissionJustificationScriptPath -Needle 'Format-MarkdownCodeSpan -Value $status') "status header code span"
Add-Check "permission justification code-spans review path" (Test-FileContains -Path $permissionJustificationScriptPath -Needle 'Format-MarkdownCodeSpan -Value $PermissionReviewJson') "review path code span"
Add-Check "permission justification pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $permissionJustificationScriptPath) "boundary backtick padding"
Add-Check "permission justification escapes gate names" (Test-FileContains -Path $permissionJustificationScriptPath -Needle 'Escape-MarkdownCell -Value $gate.name') "gate name escaping"
Add-Check "permission justification escapes gate details" (Test-FileContains -Path $permissionJustificationScriptPath -Needle 'Escape-MarkdownCell -Value $gate.detail') "gate detail escaping"
Add-Check "permission justification escapes permission names" (Test-FileContains -Path $permissionJustificationScriptPath -Needle 'Escape-MarkdownCell -Value $row.permission') "permission name escaping"

$deviceInstallMatrixScriptPath = Join-Path $ProjectRoot "scripts\device-install-matrix.ps1"
Add-Check "device install matrix escapes markdown inline values" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'function Escape-MarkdownInline') "inline escaping"
Add-Check "device install matrix escapes APK path" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'Escape-MarkdownInline -Value $ApkPath') "APK path escaping"
Add-Check "device install matrix escapes application id" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'Escape-MarkdownInline -Value $applicationId') "application id escaping"
Add-Check "device install matrix escapes version text" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'Escape-MarkdownInline -Value "$versionName / $versionCode"') "version escaping"
Add-Check "device install matrix escapes device serials" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'Escape-MarkdownInline -Value $result.serial') "serial escaping"
Add-Check "device install matrix captures native command output" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'function Invoke-NativeText') "native command capture"
Add-Check "device install matrix captures adb devices stderr" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'Invoke-NativeText -Command $adb -CommandArgs @("devices")') "adb devices capture"
Add-Check "device install matrix captures adb install stderr" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'Invoke-NativeText -Command $adb -CommandArgs @("-s", $device, "install", "-r", "-t", $ApkPath)') "adb install capture"
Add-Check "device install matrix formats markdown code spans" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'function Format-MarkdownCodeSpan') "code span fencing"
Add-Check "device install matrix code-spans APK path" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'Format-MarkdownCodeSpan -Value $safeApkPath') "APK path code span"
Add-Check "device install matrix pads boundary code span backticks" (Test-CodeSpanPadsBoundaryBackticks -Path $deviceInstallMatrixScriptPath) "boundary backtick padding"
Add-Check "device install matrix code-spans device serials" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle 'Format-MarkdownCodeSpan -Value $safeSerial') "device serial code span"
Add-Check "device install matrix preserves RequireDevice code span" (Test-FileContains -Path $deviceInstallMatrixScriptPath -Needle "'- Use ``-RequireDevice`` in a release gate") "RequireDevice code span"

Add-Check "README mentions tag" (Test-FileContains -Path (Join-Path $ProjectRoot "README.md") -Needle $Tag) $Tag
Add-Check "release flow mentions installability" (Test-FileContains -Path (Join-Path $ProjectRoot "RELEASE_STUDY.md") -Needle "verify-installable-apk.ps1") "verify-installable-apk.ps1"
Add-Check "README documents Gradle cache relocation" (Test-FileContains -Path (Join-Path $ProjectRoot "README.md") -Needle "GradleUserHome") "GradleUserHome"
Add-Check "README documents Gradle cache threshold" (Test-FileContains -Path (Join-Path $ProjectRoot "README.md") -Needle "MinGradleDriveFreeGb") "MinGradleDriveFreeGb"
Add-Check "release flow documents Gradle cache relocation" (Test-FileContains -Path (Join-Path $ProjectRoot "RELEASE_STUDY.md") -Needle "GradleUserHome") "GradleUserHome"
Add-Check "release flow documents Gradle cache threshold" (Test-FileContains -Path (Join-Path $ProjectRoot "RELEASE_STUDY.md") -Needle "MinGradleDriveFreeGb") "MinGradleDriveFreeGb"
Add-Check "release flow documents release health failure summary" (Test-FileContains -Path (Join-Path $ProjectRoot "RELEASE_STUDY.md") -Needle "失败检查名") "release-health stderr summary"

$ciChannelWorkflowPath = Join-Path $ProjectRoot ".github\workflows\ci-channel.yml"
$pullRequestWorkflowPath = Join-Path $ProjectRoot ".github\workflows\pull-request.yml"
$releaseEvidenceWorkflowPath = Join-Path $ProjectRoot ".github\workflows\release-evidence-contract.yml"
Add-Check "CI channel skips study contract script" (Test-FileContains -Path $ciChannelWorkflowPath -Needle "scripts/study-apk-contract.ps1") "paths-ignore"
Add-Check "PR CI skips study contract script" (Test-FileContains -Path $pullRequestWorkflowPath -Needle "scripts/study-apk-contract.ps1") "paths-ignore"
Add-Check "release evidence contract covers PowerShell scripts" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle "scripts/*.ps1") "release evidence paths"
Add-Check "release evidence contract accumulates script parse failures" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle 'parseFailures.Add') "parse failure collection"
Add-Check "release evidence contract reports parse error locations" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle 'startLineNumber') "parse error location"
Add-Check "release evidence contract asserts markdown report exists" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle "study APK contract Markdown was not generated") "markdown report existence"
Add-Check "release evidence contract asserts JSON report type" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle 'report.reportType') "JSON reportType"
Add-Check "release evidence contract asserts summary check count" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle 'report.summary.checkCount') "summary check count parity"
Add-Check "release evidence contract asserts zero failure summary" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle 'report.summary.failureCount') "summary failure count"
Add-Check "release evidence contract asserts markdown title tag" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle '$expectedTitle = "# Study APK Contract - $($report.tag)"') "markdown title/tag parity"
Add-Check "release evidence contract asserts markdown OK status" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle 'Status:\s+`OK`') "markdown OK status"
Add-Check "release evidence contract asserts markdown check count" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle '$expectedCheckCountRow = "| Check count | $checkCount |"') "markdown check count parity"
Add-Check "release evidence contract asserts markdown failure count" (Test-FileContains -Path $releaseEvidenceWorkflowPath -Needle '$expectedFailureCountRow = "| Failure count | 0 |"') "markdown failure count parity"

$apks = @()
$apkEvidenceCount = 0
$deviceMatrixStatus = "missing"
$permissionReviewStatus = "missing"
$releaseAssetApkCount = 0
$provenanceSubjectCount = 0
$releaseApkAssetDigests = @{}
$provenanceApkSubjectDigests = @{}
$reportPath = Join-Path $ProjectRoot "docs\apk-installability-report-$Tag.json"
if (Test-Path -LiteralPath $reportPath) {
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $apks = @($report.apks)
    $apkEvidenceCount = $apks.Count
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

$deviceMatrixPath = Join-Path $ProjectRoot "docs\device-install-matrix-$Tag.json"
if (Test-Path -LiteralPath $deviceMatrixPath) {
    $deviceMatrix = Get-Content -LiteralPath $deviceMatrixPath -Raw | ConvertFrom-Json
    $deviceStatus = [string]$deviceMatrix.status
    $deviceMatrixStatus = $deviceStatus
    $deviceCount = @($deviceMatrix.devices).Count
    $deviceResults = @($deviceMatrix.results)
    Add-Check "device install matrix ok flag" ([bool]$deviceMatrix.ok) "ok=$($deviceMatrix.ok)"
    Add-Check "device install matrix tag matches" ([string]$deviceMatrix.tag -eq $Tag) "tag=$($deviceMatrix.tag)"
    Add-Check "device install matrix package matches gradle" ([string]$deviceMatrix.applicationId -eq $applicationId) "$($deviceMatrix.applicationId)"
    Add-Check "device install matrix version matches gradle" ([string]$deviceMatrix.versionName -eq $versionName -and [string]$deviceMatrix.versionCode -eq $versionCode) "$($deviceMatrix.versionName)/$($deviceMatrix.versionCode)"
    Add-Check "device install matrix status recorded" (@("installed", "no_devices") -contains $deviceStatus) "status=$deviceStatus"
    $hasExplicitNoDeviceBoundary = ($deviceStatus -eq "no_devices" -and $deviceCount -eq 0 -and -not [bool]$deviceMatrix.requireDevice)
    $hasInstalledEvidence = ($deviceStatus -eq "installed" -and $deviceResults.Count -ge 1 -and @($deviceResults | Where-Object { -not [bool]$_.ok }).Count -eq 0)
    Add-Check "device install matrix result boundary" ($hasExplicitNoDeviceBoundary -or $hasInstalledEvidence) "status=$deviceStatus, devices=$deviceCount, results=$($deviceResults.Count)"
}

$permissionReviewPath = Join-Path $ProjectRoot "docs\apk-permission-review-$Tag.json"
if (Test-Path -LiteralPath $permissionReviewPath) {
    $permissionReview = Get-Content -LiteralPath $permissionReviewPath -Raw | ConvertFrom-Json
    $permissionReviewStatus = [string]$permissionReview.status
    Add-Check "permission review ok flag" ([bool]$permissionReview.ok) "ok=$($permissionReview.ok)"
    Add-Check "permission review tag matches" ([string]$permissionReview.tag -eq $Tag) "tag=$($permissionReview.tag)"
    Add-Check "permission review status recorded" (-not [string]::IsNullOrWhiteSpace([string]$permissionReview.status)) "status=$($permissionReview.status)"
    Add-Check "permission review covers APKs" (@($permissionReview.apks).Count -ge 1) "$(@($permissionReview.apks).Count) APKs"
}

$permissionJustificationPath = Join-Path $ProjectRoot "docs\apk-permission-justification-$Tag.json"
if (Test-Path -LiteralPath $permissionJustificationPath) {
    $permissionJustification = Get-Content -LiteralPath $permissionJustificationPath -Raw | ConvertFrom-Json
    Add-Check "permission justification ok flag" ([bool]$permissionJustification.ok) "ok=$($permissionJustification.ok)"
    Add-Check "permission justification tag matches" ([string]$permissionJustification.tag -eq $Tag) "tag=$($permissionJustification.tag)"
    Add-Check "permission justification covers permissions" ([int]$permissionJustification.summary.permissionCount -ge 10) "$($permissionJustification.summary.permissionCount) permission(s)"
    Add-Check "permission justification has gates" (@($permissionJustification.gates).Count -ge 5) "$(@($permissionJustification.gates).Count) gates"
}

$assetManifestPath = Join-Path $ProjectRoot "docs\release-asset-manifest-$Tag.json"
if (Test-Path -LiteralPath $assetManifestPath) {
    $assetManifest = Get-Content -LiteralPath $assetManifestPath -Raw | ConvertFrom-Json
    $releaseAssetApkCount = [int]$assetManifest.summary.apkAssetCount
    Add-Check "release asset manifest ok flag" ([bool]$assetManifest.ok) "ok=$($assetManifest.ok)"
    Add-Check "release asset manifest tag matches" ([string]$assetManifest.tag -eq $Tag) "tag=$($assetManifest.tag)"
    Add-Check "release asset manifest APK assets" ([int]$assetManifest.summary.debugApkCount -ge 1 -and [int]$assetManifest.summary.releaseApkCount -ge 1) "debug=$($assetManifest.summary.debugApkCount), release=$($assetManifest.summary.releaseApkCount)"
    Add-Check "release asset manifest gates recorded" (@($assetManifest.gates).Count -ge 10) "$(@($assetManifest.gates).Count) gates"
    $assetManifestGateByName = @{}
    foreach ($gate in @($assetManifest.gates)) {
        $gateName = [string]$gate.name
        if (-not [string]::IsNullOrWhiteSpace($gateName)) {
            $assetManifestGateByName[$gateName] = $gate
        }
    }
    foreach ($requiredGateName in @(
        "all release assets have names",
        "release asset names are unique",
        "all release assets have URLs",
        "release asset URLs are unique",
        "all release assets have positive sizes",
        "all release assets are uploaded",
        "all release asset digests are canonical SHA-256",
        "all release asset URLs match release tag",
        "all release asset URLs use GitHub HTTPS downloads",
        "APK asset digests are canonical SHA-256",
        "APK asset URLs match release tag",
        "APK asset URLs use GitHub HTTPS downloads"
    )) {
        $gate = $assetManifestGateByName[$requiredGateName]
        $gateDetail = if ($null -eq $gate) { "missing gate" } else { [string]$gate.detail }
        Add-Check "release asset manifest gate passes: $requiredGateName" ($null -ne $gate -and [bool]$gate.ok) $gateDetail
    }
    foreach ($asset in @($assetManifest.assets | Where-Object { [string]$_.kind -in @("debug-apk", "release-apk") })) {
        $assetName = [string]$asset.name
        if (-not [string]::IsNullOrWhiteSpace($assetName)) {
            $releaseApkAssetDigests[$assetName] = Normalize-Sha256Digest $asset.digest
        }
    }
    $releaseHealthAsset = @($assetManifest.assets | Where-Object { [string]$_.kind -eq "release-health" -and [string]$_.name -eq "release-health-$Tag.md" } | Select-Object -First 1)
    Add-Check "release asset manifest includes release health report" ($releaseHealthAsset.Count -eq 1) "release-health-$Tag.md"
    if ($releaseHealthAsset.Count -eq 1) {
        $asset = $releaseHealthAsset[0]
        Add-Check "release health asset digest recorded" ([string]$asset.digest -match '^sha256:[0-9a-f]{64}$') "$($asset.digest)"
        Add-Check "release health asset URL matches tag" ([string]$asset.url -like "*/releases/download/$Tag/release-health-$Tag.md") "$($asset.url)"
        Add-Check "release health asset has stable size" ([int64]$asset.size -gt 0) "$($asset.size) bytes"
    }

    $releaseHealthMarkdownPath = Join-Path $ProjectRoot "release-health-$Tag.md"
    $releaseHealthMarkdownExists = Test-Path -LiteralPath $releaseHealthMarkdownPath
    Add-Check "release health markdown exists" $releaseHealthMarkdownExists "release-health-$Tag.md"
    if ($releaseHealthMarkdownExists) {
        $releaseHealthMarkdown = Get-Content -LiteralPath $releaseHealthMarkdownPath -Raw
        Add-Check "release health markdown tag matches" ($releaseHealthMarkdown.Contains("Tag: ``$Tag``")) "tag=$Tag"
        Add-Check "release health markdown has checks section" ($releaseHealthMarkdown.Contains("## Checks")) "## Checks"
        Add-Check "release health markdown records no failed checks" (-not ($releaseHealthMarkdown -match '(?m)^\| [^|]+ \| FAIL \|')) "no FAIL rows"
        foreach ($assetName in @($releaseApkAssetDigests.Keys | Sort-Object)) {
            $digest = Normalize-Sha256Digest $releaseApkAssetDigests[$assetName]
            Add-Check "release health markdown lists APK digest $assetName" ($digest -ne "" -and $releaseHealthMarkdown.Contains($digest)) $digest
        }
    }
}

$buildEnvironmentPath = Join-Path $ProjectRoot "docs\build-environment-$Tag.json"
$provenancePath = Join-Path $ProjectRoot "docs\release-provenance-$Tag.json"
if (Test-Path -LiteralPath $provenancePath) {
    $provenance = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json
    $provenanceSubjectCount = @($provenance.subject).Count
    Add-Check "release provenance ok flag" ([bool]$provenance.ok) "ok=$($provenance.ok)"
    Add-Check "release provenance tag matches" ([string]$provenance.tag -eq $Tag) "tag=$($provenance.tag)"
    Add-Check "release provenance predicate recorded" ([string]$provenance.predicateType -eq "https://slsa.dev/provenance/v1") "$($provenance.predicateType)"
    Add-Check "release provenance APK subjects" (@($provenance.subject).Count -ge 2) "$(@($provenance.subject).Count) subject(s)"
    $provenanceGateByName = @{}
    foreach ($gate in @($provenance.gates)) {
        $gateName = [string]$gate.name
        if (-not [string]::IsNullOrWhiteSpace($gateName)) {
            $provenanceGateByName[$gateName] = $gate
        }
    }
    foreach ($requiredGateName in @(
        "all materials have URIs",
        "material URIs are unique",
        "all materials have digest evidence",
        "all file materials have canonical sha256",
        "all file materials reference expected docs JSON",
        "repo material has canonical git commit",
        "all subjects have names",
        "subject names are unique",
        "all subjects have URIs",
        "subject URIs are unique",
        "all subjects match release tag asset URIs",
        "all subjects use GitHub HTTPS release downloads",
        "all subjects have positive sizes",
        "all subjects have canonical sha256"
    )) {
        $gate = $provenanceGateByName[$requiredGateName]
        $gateDetail = if ($null -eq $gate) { "missing gate" } else { [string]$gate.detail }
        Add-Check "release provenance gate passes: $requiredGateName" ($null -ne $gate -and [bool]$gate.ok) $gateDetail
    }
    foreach ($subject in @($provenance.subject | Where-Object { [string]$_.annotations.kind -in @("debug-apk", "release-apk") })) {
        $subjectName = [string]$subject.name
        if (-not [string]::IsNullOrWhiteSpace($subjectName)) {
            $provenanceApkSubjectDigests[$subjectName] = Normalize-Sha256Digest $subject.digest.sha256
        }
    }
    $materialUris = @($provenance.predicate.materials | ForEach-Object { [string]$_.uri })
    $materialSha256ByUri = @{}
    $repoMaterialCommits = @()
    foreach ($material in @($provenance.predicate.materials)) {
        $materialUri = [string]$material.uri
        if (-not [string]::IsNullOrWhiteSpace($materialUri)) {
            $materialSha256ByUri[$materialUri] = Normalize-Sha256Digest $material.digest.sha256
            if ($materialUri -notlike "file://*") {
                $repoMaterialCommits += [string]$material.digest.gitCommit
            }
        }
    }
    $canonicalRepoMaterialCommits = @($repoMaterialCommits | Where-Object { $_ -match '^[0-9a-f]{40}$' })
    $sourceCommit = [string]$provenance.predicate.buildDefinition.internalParameters.sourceCommit
    Add-Check "release provenance repo material commit is canonical" ($repoMaterialCommits.Count -eq 1 -and $canonicalRepoMaterialCommits.Count -eq 1) "repoMaterials=$($repoMaterialCommits.Count), canonical=$($canonicalRepoMaterialCommits.Count)"
    Add-Check "release provenance repo material commit matches source commit" ($repoMaterialCommits.Count -eq 1 -and $repoMaterialCommits[0] -eq $sourceCommit) "material=$($repoMaterialCommits[0]), source=$sourceCommit"
    Add-Check "release provenance links build environment" (@($materialUris | Where-Object { $_ -like "*build-environment-$Tag.json" }).Count -ge 1) "build-environment-$Tag.json"
    Add-Check "release provenance links permission justification" (@($materialUris | Where-Object { $_ -like "*apk-permission-justification-$Tag.json" }).Count -ge 1) "apk-permission-justification-$Tag.json"

    $expectedFileMaterialUris = @(
        "file://docs/release-asset-manifest-$Tag.json",
        "file://docs/build-environment-$Tag.json",
        "file://docs/apk-permission-justification-$Tag.json"
    )
    $fileMaterialUris = @($materialUris | Where-Object { $_ -like "file://*" })
    $unexpectedFileMaterialUris = @($fileMaterialUris | Where-Object { $expectedFileMaterialUris -notcontains $_ })
    $missingExpectedFileMaterialUris = @($expectedFileMaterialUris | Where-Object { $fileMaterialUris -notcontains $_ })
    $fileMaterialDetail = if ($unexpectedFileMaterialUris.Count -eq 0 -and $missingExpectedFileMaterialUris.Count -eq 0) {
        "fileMaterials=$($fileMaterialUris.Count)"
    } else {
        "unexpected=$($unexpectedFileMaterialUris -join ', '); missing=$($missingExpectedFileMaterialUris -join ', ')"
    }
    Add-Check "release provenance file materials match expected evidence" ($unexpectedFileMaterialUris.Count -eq 0 -and $missingExpectedFileMaterialUris.Count -eq 0) $fileMaterialDetail

    $assetManifestMaterialUri = "file://docs/release-asset-manifest-$Tag.json"
    $assetManifestSha256 = Get-FileSha256 -Path $assetManifestPath
    $recordedAssetManifestSha256 = [string]$materialSha256ByUri[$assetManifestMaterialUri]
    Add-Check "release provenance material digest matches release asset manifest" ($assetManifestSha256 -ne "" -and $recordedAssetManifestSha256 -eq $assetManifestSha256) "recorded=$recordedAssetManifestSha256, actual=$assetManifestSha256"

    $buildEnvironmentMaterialUri = "file://docs/build-environment-$Tag.json"
    $buildEnvironmentSha256 = Get-FileSha256 -Path $buildEnvironmentPath
    $recordedBuildEnvironmentSha256 = [string]$materialSha256ByUri[$buildEnvironmentMaterialUri]
    Add-Check "release provenance material digest matches build environment" ($buildEnvironmentSha256 -ne "" -and $recordedBuildEnvironmentSha256 -eq $buildEnvironmentSha256) "recorded=$recordedBuildEnvironmentSha256, actual=$buildEnvironmentSha256"

    $permissionJustificationMaterialUri = "file://docs/apk-permission-justification-$Tag.json"
    $permissionJustificationSha256 = Get-FileSha256 -Path $permissionJustificationPath
    $recordedPermissionJustificationSha256 = [string]$materialSha256ByUri[$permissionJustificationMaterialUri]
    Add-Check "release provenance material digest matches permission justification" ($permissionJustificationSha256 -ne "" -and $recordedPermissionJustificationSha256 -eq $permissionJustificationSha256) "recorded=$recordedPermissionJustificationSha256, actual=$permissionJustificationSha256"
}

if (Test-Path -LiteralPath $buildEnvironmentPath) {
    $buildEnvironment = Get-Content -LiteralPath $buildEnvironmentPath -Raw | ConvertFrom-Json
    Add-Check "build environment ok flag" ([bool]$buildEnvironment.ok) "ok=$($buildEnvironment.ok)"
    Add-Check "build environment tag matches" ([string]$buildEnvironment.tag -eq $Tag) "tag=$($buildEnvironment.tag)"
    Add-Check "build environment version matches gradle" ([string]$buildEnvironment.project.versionName -eq $versionName -and [string]$buildEnvironment.project.versionCode -eq $versionCode) "$($buildEnvironment.project.versionName)/$($buildEnvironment.project.versionCode)"
    Add-Check "build environment build-tools recorded" (-not [string]::IsNullOrWhiteSpace([string]$buildEnvironment.android.selectedBuildTools)) "$($buildEnvironment.android.selectedBuildTools)"
}

$assetNames = @($releaseApkAssetDigests.Keys | Sort-Object)
$subjectNames = @($provenanceApkSubjectDigests.Keys | Sort-Object)
$hasCrossCheckEvidence = ($assetNames.Count -gt 0 -and $subjectNames.Count -gt 0)
Add-Check "provenance APK comparison evidence present" $hasCrossCheckEvidence "assets=$($assetNames.Count), subjects=$($subjectNames.Count)"
if ($hasCrossCheckEvidence) {
    $missingFromProvenance = @($assetNames | Where-Object { -not $provenanceApkSubjectDigests.ContainsKey($_) })
    $extraInProvenance = @($subjectNames | Where-Object { -not $releaseApkAssetDigests.ContainsKey($_) })
    $nameParityOk = ($missingFromProvenance.Count -eq 0 -and $extraInProvenance.Count -eq 0)
    $nameDetail = if ($nameParityOk) {
        "assets=$($assetNames.Count), subjects=$($subjectNames.Count)"
    } else {
        "missingFromProvenance=$($missingFromProvenance -join ', '); extraInProvenance=$($extraInProvenance -join ', ')"
    }
    Add-Check "provenance APK subjects match release asset names" $nameParityOk $nameDetail

    $digestMismatches = @($assetNames | Where-Object {
        $provenanceApkSubjectDigests.ContainsKey($_) -and $releaseApkAssetDigests[$_] -ne $provenanceApkSubjectDigests[$_]
    })
    $digestDetail = if ($digestMismatches.Count -eq 0) {
        "matched=$($assetNames.Count)"
    } else {
        ($digestMismatches | ForEach-Object {
            "{0}: asset={1}, provenance={2}" -f $_, $releaseApkAssetDigests[$_], $provenanceApkSubjectDigests[$_]
        }) -join "; "
    }
    Add-Check "provenance APK digests match release assets" ($digestMismatches.Count -eq 0) $digestDetail
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
    summary = [pscustomobject]@{
        checkCount = $checkArray.Count
        failureCount = $failed.Count
        requiredFileCount = $requiredFiles.Count
        apkEvidenceCount = $apkEvidenceCount
        releaseAssetApkCount = $releaseAssetApkCount
        provenanceSubjectCount = $provenanceSubjectCount
        deviceMatrixStatus = $deviceMatrixStatus
        permissionReviewStatus = $permissionReviewStatus
    }
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
    Write-Utf8NoBom -Path $JsonOut -Content ($payload | ConvertTo-Json -Depth 8)
}
if ($MarkdownOut) {
    $markdownParent = Split-Path -Parent $MarkdownOut
    if ($markdownParent) { New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null }
    Write-Utf8NoBom -Path $MarkdownOut -Content (Convert-ToMarkdown -Payload $payload)
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
