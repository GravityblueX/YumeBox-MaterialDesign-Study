param(
    [string]$Tag = "",
    [string]$Repo = "GravityblueX/YumeBox-MaterialDesign-Study",
    [string]$InstallabilityJson = "",
    [string]$PermissionReviewJson = "",
    [string]$JsonOut = "",
    [string]$MarkdownOut = ""
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

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

function Get-AssetKind {
    param([string]$Name)
    if ($Name -match "-debug\.apk$") { return "debug-apk" }
    if ($Name -match "-release\.apk$") { return "release-apk" }
    if ($Name -match "\.apk$") { return "apk" }
    if ($Name -match "installability-report" -and $Name -match "\.json$") { return "installability-json" }
    if ($Name -match "installability-report" -and $Name -match "\.md$") { return "installability-md" }
    if ($Name -match "release-health" -and $Name -match "\.md$") { return "release-health" }
    return "supporting"
}

function Escape-Md {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return ([string]$Value).
        Replace("`r`n", "<br>").
        Replace("`n", "<br>").Replace("`r", "<br>").
        Replace("|", "\|")
}

function Format-MdCodeSpan {
    param([object]$Value)
    $text = Escape-Md -Value $Value
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

function ConvertTo-DateTimeOffsetOrNull {
    param([object]$Value)
    if ($null -eq $Value) { return $null }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try {
        return [System.DateTimeOffset]::Parse($text, [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        return $null
    }
}

function Test-GitHubReleaseAssetUrlName {
    param(
        [string]$Url,
        [string]$Repo,
        [string]$Tag,
        [string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($Url) -or [string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    $repoParts = $Repo -split "/", 2
    if ($repoParts.Count -ne 2) {
        return $false
    }

    try {
        $uri = [System.Uri]::new($Url)
    } catch {
        return $false
    }

    if (-not $uri.Scheme.Equals("https", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    if (-not $uri.Host.Equals("github.com", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $path = $uri.AbsolutePath.Trim("/")
    if ([string]::IsNullOrWhiteSpace($path)) {
        return $false
    }

    $segments = @($path.Split("/") | ForEach-Object { [System.Uri]::UnescapeDataString($_) })
    return (
        $segments.Count -eq 6 -and
        $segments[0].Equals($repoParts[0], [System.StringComparison]::Ordinal) -and
        $segments[1].Equals($repoParts[1], [System.StringComparison]::Ordinal) -and
        $segments[2].Equals("releases", [System.StringComparison]::Ordinal) -and
        $segments[3].Equals("download", [System.StringComparison]::Ordinal) -and
        $segments[4].Equals($Tag, [System.StringComparison]::Ordinal) -and
        $segments[5].Equals($Name, [System.StringComparison]::Ordinal)
    )
}

$props = Read-PropertiesFile -Path (Join-Path $ProjectRoot "gradle.properties")
$versionName = [string]$props["project.version.name"]
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "v$versionName" }
if ([string]::IsNullOrWhiteSpace($InstallabilityJson)) {
    $InstallabilityJson = Join-Path $ProjectRoot "docs\apk-installability-report-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($PermissionReviewJson)) {
    $PermissionReviewJson = Join-Path $ProjectRoot "docs\apk-permission-review-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($JsonOut)) {
    $JsonOut = Join-Path $ProjectRoot "docs\release-asset-manifest-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($MarkdownOut)) {
    $MarkdownOut = Join-Path $ProjectRoot "docs\release-asset-manifest-$Tag.md"
}

$generatedAt = [System.DateTimeOffset]::Now
$gates = New-Object System.Collections.Generic.List[object]
Add-Gate $gates "installability report exists" (Test-Path -LiteralPath $InstallabilityJson) $InstallabilityJson
Add-Gate $gates "permission review exists" (Test-Path -LiteralPath $PermissionReviewJson) $PermissionReviewJson

if (-not (Test-Path -LiteralPath $InstallabilityJson)) {
    throw "installability report not found: $InstallabilityJson"
}
if (-not (Test-Path -LiteralPath $PermissionReviewJson)) {
    throw "permission review not found: $PermissionReviewJson"
}

$installability = Get-Content -LiteralPath $InstallabilityJson -Raw | ConvertFrom-Json
$permissionReview = Get-Content -LiteralPath $PermissionReviewJson -Raw | ConvertFrom-Json
Add-Gate $gates "installability report ok" ([bool]$installability.ok) "ok=$($installability.ok)"
Add-Gate $gates "installability tag matches" ([string]$installability.tag -eq $Tag) "tag=$($installability.tag)"
Add-Gate $gates "permission review ok" ([bool]$permissionReview.ok) "ok=$($permissionReview.ok)"
Add-Gate $gates "permission review tag matches" ([string]$permissionReview.tag -eq $Tag) "tag=$($permissionReview.tag)"

$releaseRaw = & gh release view $Tag --repo $Repo --json tagName,name,isDraft,isPrerelease,publishedAt,assets 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "gh release view failed for $Repo $Tag`: $($releaseRaw -join "`n")"
}
$release = ($releaseRaw -join "`n") | ConvertFrom-Json
$publishedAt = ConvertTo-DateTimeOffsetOrNull $release.publishedAt
Add-Gate $gates "release tag matches" ([string]$release.tagName -eq $Tag) "tag=$($release.tagName)"
Add-Gate $gates "release is not draft" (-not [bool]$release.isDraft) "isDraft=$($release.isDraft)"
Add-Gate $gates "release published timestamp recorded" ($null -ne $publishedAt) "publishedAt=$($release.publishedAt)"
Add-Gate $gates "release published timestamp is not in the future" ($null -ne $publishedAt -and $publishedAt -le $generatedAt) "publishedAt=$($release.publishedAt), generatedAt=$($generatedAt.ToString("o"))"

$installabilityByName = @{}
foreach ($apk in @($installability.apks)) {
    $installabilityByName[[string]$apk.name] = $apk
}
$permissionByName = @{}
foreach ($review in @($permissionReview.apks)) {
    $permissionByName[[string]$review.name] = $review
}

$assets = @()
foreach ($asset in @($release.assets)) {
    $name = [string]$asset.name
    $kind = Get-AssetKind -Name $name
    $apk = $installabilityByName[$name]
    $review = $permissionByName[$name]
    $digest = Normalize-Digest ([string]$asset.digest)
    $apkDigest = if ($apk) { Normalize-Digest ([string]$apk.sha256) } else { "" }
    $sizeMatches = if ($apk) { [int64]$asset.size -eq [int64]$apk.size } else { $null }
    $digestMatches = if ($apk) { $digest -eq $apkDigest } else { $null }

    $assets += [pscustomobject]@{
        name = $name
        kind = $kind
        size = [int64]$asset.size
        digest = [string]$asset.digest
        state = [string]$asset.state
        contentType = [string]$asset.contentType
        downloadCount = [int]$asset.downloadCount
        url = [string]$asset.url
        installability = if ($apk) {
            [pscustomobject]@{
                present = $true
                sizeMatches = [bool]$sizeMatches
                digestMatches = [bool]$digestMatches
                githubDigestMatches = [bool]$apk.githubDigestMatches
                zipalignOk = [bool]$apk.zipalign.ok
                badgingOk = [bool]$apk.badging.ok
                signatureOk = [bool]$apk.signature.ok
                packageName = [string]$apk.badging.metadata.packageName
                versionName = [string]$apk.badging.metadata.versionName
                versionCode = [string]$apk.badging.metadata.versionCode
                nativeAbis = @($apk.badging.metadata.nativeAbis)
                signer = [string]$apk.signature.signer
            }
        } else {
            [pscustomobject]@{ present = $false }
        }
        permissionReview = if ($review) {
            [pscustomobject]@{
                present = $true
                permissionCount = [int]$review.permissionCount
                attentionCount = [int]$review.attentionCount
            }
        } else {
            [pscustomobject]@{ present = $false }
        }
    }
}

$apkAssets = @($assets | Where-Object { $_.kind -in @("debug-apk", "release-apk", "apk") })
$debugApks = @($assets | Where-Object { $_.kind -eq "debug-apk" })
$releaseApks = @($assets | Where-Object { $_.kind -eq "release-apk" })
$uploadedReports = @($assets | Where-Object { $_.kind -in @("installability-json", "installability-md", "release-health") })
$canonicalDigestPattern = '^sha256:[0-9a-f]{64}$'
$assetNames = @($assets | ForEach-Object { [string]$_.name })
$assetUrls = @($assets | ForEach-Object { [string]$_.url })
$assetsMissingName = @($assets | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.name) })
$assetsMissingUrl = @($assets | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.url) })
$assetsWithInvalidSize = @($assets | Where-Object { [int64]$_.size -le 0 })
$duplicateAssetNames = @(
    $assetNames |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Group-Object |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object { $_.Name }
)
$duplicateAssetUrls = @(
    $assetUrls |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Group-Object |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object { $_.Name }
)
$assetUploadFailures = @($assets | Where-Object { [string]$_.state -ne "uploaded" })
$assetDigestFormatFailures = @($assets | Where-Object { [string]$_.digest -notmatch $canonicalDigestPattern })
$assetUrlFailures = @($assets | Where-Object {
    $expectedSuffix = "/releases/download/$Tag/$($_.name)"
    -not ([string]$_.url).EndsWith($expectedSuffix, [System.StringComparison]::Ordinal)
})
$expectedAssetUrlPrefix = "https://github.com/$Repo/releases/download/$Tag/"
$assetGithubDownloadUrlFailures = @($assets | Where-Object {
    -not ([string]$_.url).StartsWith($expectedAssetUrlPrefix, [System.StringComparison]::Ordinal)
})
$assetUrlNameFailures = @($assets | Where-Object {
    -not (Test-GitHubReleaseAssetUrlName -Url ([string]$_.url) -Repo $Repo -Tag $Tag -Name ([string]$_.name))
})
$apkDigestFormatFailures = @($apkAssets | Where-Object { [string]$_.digest -notmatch $canonicalDigestPattern })
$apkUrlFailures = @($apkAssets | Where-Object {
    $expectedSuffix = "/releases/download/$Tag/$($_.name)"
    -not ([string]$_.url).EndsWith($expectedSuffix, [System.StringComparison]::Ordinal)
})
$apkGithubDownloadUrlFailures = @($apkAssets | Where-Object {
    -not ([string]$_.url).StartsWith($expectedAssetUrlPrefix, [System.StringComparison]::Ordinal)
})
$apkUrlNameFailures = @($apkAssets | Where-Object {
    -not (Test-GitHubReleaseAssetUrlName -Url ([string]$_.url) -Repo $Repo -Tag $Tag -Name ([string]$_.name))
})

Add-Gate $gates "all release assets have names" ($assetsMissingName.Count -eq 0) "assets=$($assets.Count), missing=$($assetsMissingName.Count)"
Add-Gate $gates "release asset names are unique" ($duplicateAssetNames.Count -eq 0) "assets=$($assets.Count), duplicates=$($duplicateAssetNames.Count)"
Add-Gate $gates "all release assets have URLs" ($assetsMissingUrl.Count -eq 0) "assets=$($assets.Count), missing=$($assetsMissingUrl.Count)"
Add-Gate $gates "release asset URLs are unique" ($duplicateAssetUrls.Count -eq 0) "assets=$($assets.Count), duplicates=$($duplicateAssetUrls.Count)"
Add-Gate $gates "all release assets have positive sizes" ($assetsWithInvalidSize.Count -eq 0) "assets=$($assets.Count), invalid=$($assetsWithInvalidSize.Count)"
Add-Gate $gates "all release assets are uploaded" ($assetUploadFailures.Count -eq 0) "assets=$($assets.Count), invalid=$($assetUploadFailures.Count)"
Add-Gate $gates "all release asset digests are canonical SHA-256" ($assetDigestFormatFailures.Count -eq 0) "assets=$($assets.Count), invalid=$($assetDigestFormatFailures.Count)"
Add-Gate $gates "all release asset URLs match release tag" ($assetUrlFailures.Count -eq 0) "assets=$($assets.Count), invalid=$($assetUrlFailures.Count); tag=$Tag"
Add-Gate $gates "all release asset URLs use GitHub HTTPS downloads" ($assetGithubDownloadUrlFailures.Count -eq 0) "assets=$($assets.Count), invalid=$($assetGithubDownloadUrlFailures.Count); prefix=$expectedAssetUrlPrefix"
Add-Gate $gates "all release asset URL filenames match asset names" ($assetUrlNameFailures.Count -eq 0) "assets=$($assets.Count), invalid=$($assetUrlNameFailures.Count)"
Add-Gate $gates "debug APK asset present" ($debugApks.Count -ge 1) "$($debugApks.Count) debug APK asset(s)"
Add-Gate $gates "release APK asset present" ($releaseApks.Count -ge 1) "$($releaseApks.Count) release APK asset(s)"
Add-Gate $gates "support reports uploaded" ($uploadedReports.Count -ge 3) "$($uploadedReports.Count) report asset(s)"
Add-Gate $gates "release APK assets uploaded" (($apkAssets | Where-Object { $_.state -ne "uploaded" }).Count -eq 0) "apkAssets=$($apkAssets.Count)"
Add-Gate $gates "APK asset digests are canonical SHA-256" ($apkDigestFormatFailures.Count -eq 0) "invalid=$($apkDigestFormatFailures.Count); apkAssets=$($apkAssets.Count)"
Add-Gate $gates "APK asset URLs match release tag" ($apkUrlFailures.Count -eq 0) "invalid=$($apkUrlFailures.Count); tag=$Tag"
Add-Gate $gates "APK asset URLs use GitHub HTTPS downloads" ($apkGithubDownloadUrlFailures.Count -eq 0) "invalid=$($apkGithubDownloadUrlFailures.Count); prefix=$expectedAssetUrlPrefix"
Add-Gate $gates "APK asset URL filenames match names" ($apkUrlNameFailures.Count -eq 0) "invalid=$($apkUrlNameFailures.Count); apkAssets=$($apkAssets.Count)"
Add-Gate $gates "all release APKs in installability report" (($apkAssets | Where-Object { -not $_.installability.present }).Count -eq 0) "apkAssets=$($apkAssets.Count)"
Add-Gate $gates "all installability APKs in release" ((@($installability.apks | Where-Object { -not (@($apkAssets.name) -contains [string]$_.name) })).Count -eq 0) "reportApks=$(@($installability.apks).Count)"
Add-Gate $gates "APK asset digests match report" (($apkAssets | Where-Object { $_.installability.present -and -not $_.installability.digestMatches }).Count -eq 0) "apkAssets=$($apkAssets.Count)"
Add-Gate $gates "APK asset sizes match report" (($apkAssets | Where-Object { $_.installability.present -and -not $_.installability.sizeMatches }).Count -eq 0) "apkAssets=$($apkAssets.Count)"
Add-Gate $gates "APK tooling checks passed" (($apkAssets | Where-Object {
    $_.installability.present -and (-not $_.installability.zipalignOk -or -not $_.installability.badgingOk -or -not $_.installability.signatureOk -or -not $_.installability.githubDigestMatches)
}).Count -eq 0) "zipalign/badging/signature/digest"
Add-Gate $gates "permission review covers APKs" (($apkAssets | Where-Object { -not $_.permissionReview.present }).Count -eq 0) "apkAssets=$($apkAssets.Count)"

$gateArray = @(foreach ($gate in $gates) { $gate })
$failures = @($gateArray | Where-Object { -not [bool]$_.ok })
$payload = [pscustomobject]@{
    reportType = "yumebox_release_asset_manifest"
    generatedAt = $generatedAt.ToString("o")
    repo = $Repo
    tag = $Tag
    release = [pscustomobject]@{
        name = [string]$release.name
        tagName = [string]$release.tagName
        isDraft = [bool]$release.isDraft
        isPrerelease = [bool]$release.isPrerelease
        publishedAt = if ($null -ne $publishedAt) { $publishedAt.ToString("o") } else { [string]$release.publishedAt }
    }
    installabilityReport = $InstallabilityJson
    permissionReview = $PermissionReviewJson
    ok = ($failures.Count -eq 0)
    summary = [pscustomobject]@{
        assetCount = @($assets).Count
        apkAssetCount = $apkAssets.Count
        debugApkCount = $debugApks.Count
        releaseApkCount = $releaseApks.Count
        reportAssetCount = $uploadedReports.Count
    }
    gates = $gateArray
    failures = @($failures)
    assets = @($assets | Sort-Object kind,name)
    referenceBasis = @(
        "GitHub Release asset manifest",
        "APK supply-chain digest and size reconciliation",
        "Installability report remains the source of zipalign, badging, signature, and package metadata truth",
        "Permission review remains separate from installability and release asset presence"
    )
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOut) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarkdownOut) | Out-Null
Write-Utf8NoBom -Path $JsonOut -Content ($payload | ConvertTo-Json -Depth 10)

$status = if ($payload.ok) { "OK" } else { "FAIL" }
$repoCode = Format-MdCodeSpan -Value $Repo
$releaseNameCode = Format-MdCodeSpan -Value $payload.release.name
$statusCode = Format-MdCodeSpan -Value $status
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Release Asset Manifest - $Tag")
$lines.Add("")
$lines.Add("Generated: $($payload.generatedAt)")
$lines.Add("Repo: $repoCode")
$lines.Add("Release: $releaseNameCode")
$lines.Add("Published: $($payload.release.publishedAt)")
$lines.Add("Status: $statusCode")
$lines.Add("")
$lines.Add("## Summary")
$lines.Add("")
$lines.Add("| Metric | Value |")
$lines.Add("|---|---:|")
$lines.Add("| Assets | $($payload.summary.assetCount) |")
$lines.Add("| APK assets | $($payload.summary.apkAssetCount) |")
$lines.Add("| Debug APKs | $($payload.summary.debugApkCount) |")
$lines.Add("| Release APKs | $($payload.summary.releaseApkCount) |")
$lines.Add("| Supporting reports | $($payload.summary.reportAssetCount) |")
$lines.Add("")
$lines.Add("## Gates")
$lines.Add("")
$lines.Add("| Gate | Result | Detail |")
$lines.Add("|---|---|---|")
foreach ($gate in $payload.gates) {
    $gateStatus = if ($gate.ok) { "OK" } else { "FAIL" }
    $lines.Add("| $(Escape-Md $gate.name) | $gateStatus | $(Escape-Md $gate.detail) |")
}
$lines.Add("")
$lines.Add("## APK Assets")
$lines.Add("")
$lines.Add("| Asset | Kind | Size | SHA-256 | Tooling | Permissions |")
$lines.Add("|---|---|---:|---|---|---|")
foreach ($asset in @($payload.assets | Where-Object { $_.kind -in @("debug-apk", "release-apk", "apk") })) {
    $tooling = if ($asset.installability.present) {
        "zipalign=$($asset.installability.zipalignOk); badging=$($asset.installability.badgingOk); signature=$($asset.installability.signatureOk)"
    } else {
        "missing installability row"
    }
    $permissions = if ($asset.permissionReview.present) {
        "$($asset.permissionReview.permissionCount) permissions; $($asset.permissionReview.attentionCount) attention"
    } else {
        "missing review"
    }
    $assetName = Format-MdCodeSpan -Value $asset.name
    $assetKind = Escape-Md -Value $asset.kind
    $assetDigest = Format-MdCodeSpan -Value (Normalize-Digest $asset.digest)
    $toolingCell = Escape-Md -Value $tooling
    $permissionsCell = Escape-Md -Value $permissions
    $lines.Add("| $assetName | $assetKind | $($asset.size) | $assetDigest | $toolingCell | $permissionsCell |")
}
$lines.Add("")
$lines.Add("## Supporting Assets")
$lines.Add("")
$lines.Add("| Asset | Kind | Size | Digest |")
$lines.Add("|---|---|---:|---|")
foreach ($asset in @($payload.assets | Where-Object { $_.kind -notin @("debug-apk", "release-apk", "apk") })) {
    $assetName = Format-MdCodeSpan -Value $asset.name
    $assetKind = Escape-Md -Value $asset.kind
    $assetDigest = Format-MdCodeSpan -Value $asset.digest
    $lines.Add("| $assetName | $assetKind | $($asset.size) | $assetDigest |")
}
$lines.Add("")
$lines.Add("## Boundary")
$lines.Add("")
$lines.Add("- This manifest proves release asset consistency against archived APK installability and permission-review reports.")
$lines.Add("- It does not replace a real-device install matrix, privacy review, or production release-signing audit.")
$lines.Add("")
Write-Utf8NoBom -Path $MarkdownOut -Content ($lines -join "`n")

Write-Host "Status=$status"
Write-Host "JsonOut=$JsonOut"
Write-Host "MarkdownOut=$MarkdownOut"
if (-not $payload.ok) { exit 1 }
