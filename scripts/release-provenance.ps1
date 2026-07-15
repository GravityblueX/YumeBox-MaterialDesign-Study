param(
    [string]$Tag = "",
    [string]$Repo = "GravityblueX/YumeBox-MaterialDesign-Study",
    [string]$AssetManifestJson = "",
    [string]$BuildEnvironmentJson = "",
    [string]$PermissionJustificationJson = "",
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

function Add-Gate {
    param(
        [System.Collections.Generic.List[object]]$Gates,
        [string]$Name,
        [bool]$Ok,
        [string]$Detail
    )
    $Gates.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        detail = $Detail
    })
}

function Normalize-Digest {
    param([string]$Digest)
    if ([string]::IsNullOrWhiteSpace($Digest)) { return "" }
    return ($Digest -replace "^sha256:", "").ToLowerInvariant()
}

function Escape-MarkdownTableCell {
    param([object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return ([string]$Value).
        Replace("`r`n", "<br>").Replace("`n", "<br>").Replace("`r", "<br>").
        Replace("|", "\|")
}

function Format-MarkdownCodeSpan {
    param([object]$Value)
    $text = Escape-MarkdownTableCell -Value $Value
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

function Get-TextFileSha256 {
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

function Git-Text {
    param([string[]]$GitArgs)
    $output = & git -C $ProjectRoot @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return "" }
    return ($output -join "`n").Trim()
}

$props = Read-PropertiesFile -Path (Join-Path $ProjectRoot "gradle.properties")
$versionName = [string]$props["project.version.name"]
$versionCode = [string]$props["project.version.code"]
$applicationId = [string]$props["project.applicationId"]
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "v$versionName" }
if ([string]::IsNullOrWhiteSpace($AssetManifestJson)) {
    $AssetManifestJson = Join-Path $ProjectRoot "docs\release-asset-manifest-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($BuildEnvironmentJson)) {
    $BuildEnvironmentJson = Join-Path $ProjectRoot "docs\build-environment-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($PermissionJustificationJson)) {
    $PermissionJustificationJson = Join-Path $ProjectRoot "docs\apk-permission-justification-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($JsonOut)) {
    $JsonOut = Join-Path $ProjectRoot "docs\release-provenance-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($MarkdownOut)) {
    $MarkdownOut = Join-Path $ProjectRoot "docs\release-provenance-$Tag.md"
}

$gates = New-Object System.Collections.Generic.List[object]
Add-Gate $gates "asset manifest exists" (Test-Path -LiteralPath $AssetManifestJson) $AssetManifestJson
if (-not (Test-Path -LiteralPath $AssetManifestJson)) {
    throw "asset manifest not found: $AssetManifestJson"
}
Add-Gate $gates "build environment exists" (Test-Path -LiteralPath $BuildEnvironmentJson) $BuildEnvironmentJson
if (-not (Test-Path -LiteralPath $BuildEnvironmentJson)) {
    throw "build environment report not found: $BuildEnvironmentJson"
}
Add-Gate $gates "permission justification exists" (Test-Path -LiteralPath $PermissionJustificationJson) $PermissionJustificationJson
if (-not (Test-Path -LiteralPath $PermissionJustificationJson)) {
    throw "permission justification report not found: $PermissionJustificationJson"
}

$manifest = Get-Content -LiteralPath $AssetManifestJson -Raw | ConvertFrom-Json
$apkAssets = @($manifest.assets | Where-Object { $_.kind -in @("debug-apk", "release-apk", "apk") })
$subjects = @()
$canonicalSha256Pattern = '^[0-9a-f]{64}$'
$canonicalGitCommitPattern = '^[0-9a-f]{40}$'
foreach ($asset in $apkAssets) {
    $subjects += [pscustomobject]@{
        name = [string]$asset.name
        uri = [string]$asset.url
        size = [int64]$asset.size
        digest = [pscustomobject]@{
            sha256 = Normalize-Digest ([string]$asset.digest)
        }
        annotations = [pscustomobject]@{
            kind = [string]$asset.kind
            packageName = [string]$asset.installability.packageName
            versionName = [string]$asset.installability.versionName
            versionCode = [string]$asset.installability.versionCode
            signer = [string]$asset.installability.signer
        }
    }
}
$subjectNames = @($subjects | ForEach-Object { [string]$_.name })
$subjectUris = @($subjects | ForEach-Object { [string]$_.uri })
$subjectsMissingName = @($subjects | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.name) })
$subjectsMissingUri = @($subjects | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.uri) })
$subjectsWithInvalidSize = @($subjects | Where-Object { [int64]$_.size -le 0 })
$subjectsWithInvalidSha256 = @($subjects | Where-Object { [string]$_.digest.sha256 -notmatch $canonicalSha256Pattern })
$duplicateSubjectNames = @(
    $subjectNames |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Group-Object |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object { $_.Name }
)
$duplicateSubjectUris = @(
    $subjectUris |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Group-Object |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object { $_.Name }
)

$head = Git-Text @("rev-parse", "HEAD")
$branch = Git-Text @("branch", "--show-current")
$remote = Git-Text @("remote", "get-url", "origin")
$dirtyLines = @((Git-Text @("status", "--short")) -split "`r?`n" | Where-Object { $_.Trim() })
$materials = @(
    [pscustomobject]@{
        uri = $remote
        digest = [pscustomobject]@{ gitCommit = $head }
    },
    [pscustomobject]@{
        uri = "file://docs/release-asset-manifest-$Tag.json"
        digest = [pscustomobject]@{ sha256 = Get-TextFileSha256 -Path $AssetManifestJson }
    },
    [pscustomobject]@{
        uri = "file://docs/build-environment-$Tag.json"
        digest = [pscustomobject]@{ sha256 = Get-TextFileSha256 -Path $BuildEnvironmentJson }
    },
    [pscustomobject]@{
        uri = "file://docs/apk-permission-justification-$Tag.json"
        digest = [pscustomobject]@{ sha256 = Get-TextFileSha256 -Path $PermissionJustificationJson }
    }
)
$materialUris = @($materials | ForEach-Object { [string]$_.uri })
$materialsMissingUri = @($materials | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.uri) })
$duplicateMaterialUris = @(
    $materialUris |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Group-Object |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object { $_.Name }
)
$materialsMissingDigest = @(
    $materials | Where-Object {
        $digest = $_.digest
        [string]::IsNullOrWhiteSpace([string]$digest.gitCommit) -and
            [string]::IsNullOrWhiteSpace([string]$digest.sha256)
    }
)
$fileMaterials = @($materials | Where-Object { [string]$_.uri -like "file://*" })
$repoMaterials = @($materials | Where-Object { [string]$_.uri -notlike "file://*" })
$expectedFileMaterialUris = @(
    "file://docs/release-asset-manifest-$Tag.json",
    "file://docs/build-environment-$Tag.json",
    "file://docs/apk-permission-justification-$Tag.json"
)
$unexpectedFileMaterialUris = @(
    $fileMaterials |
        ForEach-Object { [string]$_.uri } |
        Where-Object { $expectedFileMaterialUris -notcontains $_ }
)
$missingExpectedFileMaterialUris = @(
    $expectedFileMaterialUris |
        Where-Object { $materialUris -notcontains $_ }
)
$fileMaterialsWithInvalidSha256 = @(
    $fileMaterials | Where-Object { [string]$_.digest.sha256 -notmatch $canonicalSha256Pattern }
)
$repoMaterialsWithInvalidGitCommit = @(
    $repoMaterials | Where-Object { [string]$_.digest.gitCommit -notmatch $canonicalGitCommitPattern }
)

Add-Gate $gates "asset manifest ok" ([bool]$manifest.ok) "ok=$($manifest.ok)"
Add-Gate $gates "asset manifest tag matches" ([string]$manifest.tag -eq $Tag) "tag=$($manifest.tag)"
Add-Gate $gates "debug and release APK subjects" (@($subjects | Where-Object { $_.annotations.kind -eq "debug-apk" }).Count -ge 1 -and @($subjects | Where-Object { $_.annotations.kind -eq "release-apk" }).Count -ge 1) "$(@($subjects).Count) subject(s)"
Add-Gate $gates "all subjects have sha256" (@($subjects | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.digest.sha256) }).Count -eq 0) "$(@($subjects).Count) subject(s)"
Add-Gate $gates "all subjects have names" ($subjectsMissingName.Count -eq 0) "subjects=$($subjects.Count), missing=$($subjectsMissingName.Count)"
Add-Gate $gates "subject names are unique" ($duplicateSubjectNames.Count -eq 0) "subjects=$($subjects.Count), duplicates=$($duplicateSubjectNames.Count)"
Add-Gate $gates "all subjects have URIs" ($subjectsMissingUri.Count -eq 0) "subjects=$($subjects.Count), missing=$($subjectsMissingUri.Count)"
Add-Gate $gates "subject URIs are unique" ($duplicateSubjectUris.Count -eq 0) "subjects=$($subjects.Count), duplicates=$($duplicateSubjectUris.Count)"
Add-Gate $gates "all subjects have positive sizes" ($subjectsWithInvalidSize.Count -eq 0) "subjects=$($subjects.Count), invalid=$($subjectsWithInvalidSize.Count)"
Add-Gate $gates "all subjects have canonical sha256" ($subjectsWithInvalidSha256.Count -eq 0) "subjects=$($subjects.Count), invalid=$($subjectsWithInvalidSha256.Count)"
Add-Gate $gates "git commit available" (-not [string]::IsNullOrWhiteSpace($head)) $head
Add-Gate $gates "release is not draft" (-not [bool]$manifest.release.isDraft) "isDraft=$($manifest.release.isDraft)"
Add-Gate $gates "package id recorded" (-not [string]::IsNullOrWhiteSpace($applicationId)) $applicationId
Add-Gate $gates "version recorded" (-not [string]::IsNullOrWhiteSpace($versionName) -and -not [string]::IsNullOrWhiteSpace($versionCode)) "$versionName/$versionCode"
Add-Gate $gates "all materials have URIs" ($materialsMissingUri.Count -eq 0) "materials=$($materials.Count), missing=$($materialsMissingUri.Count)"
Add-Gate $gates "material URIs are unique" ($duplicateMaterialUris.Count -eq 0) "materials=$($materials.Count), duplicates=$($duplicateMaterialUris.Count)"
Add-Gate $gates "all materials have digest evidence" ($materialsMissingDigest.Count -eq 0) "materials=$($materials.Count), missing=$($materialsMissingDigest.Count)"
Add-Gate $gates "all file materials have canonical sha256" ($fileMaterials.Count -gt 0 -and $fileMaterialsWithInvalidSha256.Count -eq 0) "fileMaterials=$($fileMaterials.Count), invalid=$($fileMaterialsWithInvalidSha256.Count)"
Add-Gate $gates "all file materials reference expected docs JSON" ($unexpectedFileMaterialUris.Count -eq 0 -and $missingExpectedFileMaterialUris.Count -eq 0) "fileMaterials=$($fileMaterials.Count), expected=$($expectedFileMaterialUris.Count), unexpected=$($unexpectedFileMaterialUris.Count), missing=$($missingExpectedFileMaterialUris.Count)"
Add-Gate $gates "repo material has canonical git commit" ($repoMaterials.Count -eq 1 -and $repoMaterialsWithInvalidGitCommit.Count -eq 0) "repoMaterials=$($repoMaterials.Count), invalid=$($repoMaterialsWithInvalidGitCommit.Count)"

$gateArray = @(foreach ($gate in $gates) { $gate })
$failures = @($gateArray | Where-Object { -not [bool]$_.ok })
$payload = [pscustomobject]@{
    reportType = "yumebox_release_provenance"
    predicateType = "https://slsa.dev/provenance/v1"
    generatedAt = (Get-Date).ToString("o")
    repo = $Repo
    tag = $Tag
    ok = ($failures.Count -eq 0)
    subject = @($subjects)
    predicate = [pscustomobject]@{
        buildDefinition = [pscustomobject]@{
            buildType = "https://github.com/GravityblueX/YumeBox-MaterialDesign-Study/study-apk-release"
            externalParameters = [pscustomobject]@{
                tag = $Tag
                packageName = $applicationId
                versionName = $versionName
                versionCode = $versionCode
                abi = [string]$props["abi.app.list"]
            }
            internalParameters = [pscustomobject]@{
                sourceBranch = $branch
                sourceCommit = $head
                sourceRemote = $remote
            }
        }
        runDetails = [pscustomobject]@{
            builder = [pscustomobject]@{
                id = "local-yumebox-study-release-toolchain"
            }
            metadata = [pscustomobject]@{
                invocationId = "manual-local-$Tag"
                startedOn = $manifest.generatedAt
                finishedOn = (Get-Date).ToString("o")
            }
        }
        materials = @($materials)
    }
    gates = $gateArray
    failures = @($failures)
    dirtyCountWhenGenerated = @($dirtyLines).Count
    referenceBasis = @(
        "SLSA provenance style subject and material digest mapping",
        "GitHub Release assets remain the downloadable APK source of truth",
        "Build environment and permission justification evidence are linked as release materials",
        "Installability and permission evidence remain separate linked reports"
    )
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOut) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarkdownOut) | Out-Null
Write-Utf8NoBom -Path $JsonOut -Content ($payload | ConvertTo-Json -Depth 12)

$status = if ($payload.ok) { "OK" } else { "FAIL" }
$predicateCode = Format-MarkdownCodeSpan -Value $payload.predicateType
$repoCode = Format-MarkdownCodeSpan -Value $Repo
$statusCode = Format-MarkdownCodeSpan -Value $status
$headCode = Format-MarkdownCodeSpan -Value $head
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Release Provenance - $Tag")
$lines.Add("")
$lines.Add("Generated: $($payload.generatedAt)")
$lines.Add("Predicate: $predicateCode")
$lines.Add("Repo: $repoCode")
$lines.Add("Status: $statusCode")
$lines.Add("Source commit: $headCode")
$lines.Add("")
$lines.Add("## Subjects")
$lines.Add("")
$lines.Add("| APK | Kind | Size | SHA-256 | Package | Version |")
$lines.Add("|---|---|---:|---|---|---|")
foreach ($subject in $payload.subject) {
    $subjectName = Format-MarkdownCodeSpan -Value $subject.name
    $subjectKind = Escape-MarkdownTableCell -Value $subject.annotations.kind
    $subjectDigest = Format-MarkdownCodeSpan -Value $subject.digest.sha256
    $subjectPackage = Format-MarkdownCodeSpan -Value $subject.annotations.packageName
    $subjectVersion = Escape-MarkdownTableCell -Value "$($subject.annotations.versionName)/$($subject.annotations.versionCode)"
    $lines.Add("| $subjectName | $subjectKind | $($subject.size) | $subjectDigest | $subjectPackage | $subjectVersion |")
}
$lines.Add("")
$lines.Add("## Gates")
$lines.Add("")
$lines.Add("| Gate | Result | Detail |")
$lines.Add("|---|---|---|")
foreach ($gate in $payload.gates) {
    $gateStatus = if ($gate.ok) { "OK" } else { "FAIL" }
    $gateName = Escape-MarkdownTableCell -Value $gate.name
    $gateDetail = Escape-MarkdownTableCell -Value $gate.detail
    $lines.Add("| $gateName | $gateStatus | $gateDetail |")
}
$lines.Add("")
$lines.Add("## Boundary")
$lines.Add("")
$lines.Add("- This provenance statement is study-release evidence, not a hosted trusted builder attestation.")
$lines.Add("- It links downloadable APK subjects to local build metadata, release asset manifest, and git source commit.")
$lines.Add("- Production release still requires private release signing, device matrix, privacy review, and trusted CI provenance.")
$lines.Add("")
Write-Utf8NoBom -Path $MarkdownOut -Content ($lines -join "`n")

Write-Host "Status=$status"
Write-Host "JsonOut=$JsonOut"
Write-Host "MarkdownOut=$MarkdownOut"
if (-not $payload.ok) { exit 1 }
