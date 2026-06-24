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

$head = Git-Text @("rev-parse", "HEAD")
$branch = Git-Text @("branch", "--show-current")
$remote = Git-Text @("remote", "get-url", "origin")
$dirtyLines = @((Git-Text @("status", "--short")) -split "`r?`n" | Where-Object { $_.Trim() })

Add-Gate $gates "asset manifest ok" ([bool]$manifest.ok) "ok=$($manifest.ok)"
Add-Gate $gates "asset manifest tag matches" ([string]$manifest.tag -eq $Tag) "tag=$($manifest.tag)"
Add-Gate $gates "debug and release APK subjects" (@($subjects | Where-Object { $_.annotations.kind -eq "debug-apk" }).Count -ge 1 -and @($subjects | Where-Object { $_.annotations.kind -eq "release-apk" }).Count -ge 1) "$(@($subjects).Count) subject(s)"
Add-Gate $gates "all subjects have sha256" (@($subjects | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.digest.sha256) }).Count -eq 0) "$(@($subjects).Count) subject(s)"
Add-Gate $gates "git commit available" (-not [string]::IsNullOrWhiteSpace($head)) $head
Add-Gate $gates "release is not draft" (-not [bool]$manifest.release.isDraft) "isDraft=$($manifest.release.isDraft)"
Add-Gate $gates "package id recorded" (-not [string]::IsNullOrWhiteSpace($applicationId)) $applicationId
Add-Gate $gates "version recorded" (-not [string]::IsNullOrWhiteSpace($versionName) -and -not [string]::IsNullOrWhiteSpace($versionCode)) "$versionName/$versionCode"

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
        materials = @(
            [pscustomobject]@{
                uri = $remote
                digest = [pscustomobject]@{ gitCommit = $head }
            },
            [pscustomobject]@{
                uri = "file://docs/release-asset-manifest-$Tag.json"
                digest = [pscustomobject]@{ sha256 = (Get-FileHash -LiteralPath $AssetManifestJson -Algorithm SHA256).Hash.ToLowerInvariant() }
            },
            [pscustomobject]@{
                uri = "file://docs/build-environment-$Tag.json"
                digest = [pscustomobject]@{ sha256 = (Get-FileHash -LiteralPath $BuildEnvironmentJson -Algorithm SHA256).Hash.ToLowerInvariant() }
            },
            [pscustomobject]@{
                uri = "file://docs/apk-permission-justification-$Tag.json"
                digest = [pscustomobject]@{ sha256 = (Get-FileHash -LiteralPath $PermissionJustificationJson -Algorithm SHA256).Hash.ToLowerInvariant() }
            }
        )
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
$payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $JsonOut -Encoding UTF8

$status = if ($payload.ok) { "OK" } else { "FAIL" }
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Release Provenance - $Tag")
$lines.Add("")
$lines.Add("Generated: $($payload.generatedAt)")
$lines.Add("Predicate: ``$($payload.predicateType)``")
$lines.Add("Repo: ``$Repo``")
$lines.Add("Status: ``$status``")
$lines.Add("Source commit: ``$head``")
$lines.Add("")
$lines.Add("## Subjects")
$lines.Add("")
$lines.Add("| APK | Kind | Size | SHA-256 | Package | Version |")
$lines.Add("|---|---|---:|---|---|---|")
foreach ($subject in $payload.subject) {
    $lines.Add("| ``$($subject.name)`` | $($subject.annotations.kind) | $($subject.size) | ``$($subject.digest.sha256)`` | ``$($subject.annotations.packageName)`` | $($subject.annotations.versionName)/$($subject.annotations.versionCode) |")
}
$lines.Add("")
$lines.Add("## Gates")
$lines.Add("")
$lines.Add("| Gate | Result | Detail |")
$lines.Add("|---|---|---|")
foreach ($gate in $payload.gates) {
    $gateStatus = if ($gate.ok) { "OK" } else { "FAIL" }
    $lines.Add("| $($gate.name) | $gateStatus | $($gate.detail) |")
}
$lines.Add("")
$lines.Add("## Boundary")
$lines.Add("")
$lines.Add("- This provenance statement is study-release evidence, not a hosted trusted builder attestation.")
$lines.Add("- It links downloadable APK subjects to local build metadata, release asset manifest, and git source commit.")
$lines.Add("- Production release still requires private release signing, device matrix, privacy review, and trusted CI provenance.")
$lines.Add("")
($lines -join "`n") | Set-Content -LiteralPath $MarkdownOut -Encoding UTF8

Write-Host "Status=$status"
Write-Host "JsonOut=$JsonOut"
Write-Host "MarkdownOut=$MarkdownOut"
if (-not $payload.ok) { exit 1 }
