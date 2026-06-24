param(
    [string]$Tag = "",
    [string]$InstallabilityJson = "",
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

function Get-PermissionRows {
    param($Apk)
    $rows = @()
    foreach ($line in @($Apk.badging.output)) {
        if ($line -match "uses-permission:\s+name='([^']+)'(?:\s+maxSdkVersion='([^']+)')?") {
            $rows += [pscustomobject]@{
                name = $matches[1]
                maxSdkVersion = if ($matches.Count -gt 2) { $matches[2] } else { "" }
            }
        }
    }
    return @($rows | Sort-Object name -Unique)
}

$props = Read-PropertiesFile (Join-Path $ProjectRoot "gradle.properties")
$versionName = [string]$props["project.version.name"]
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "v$versionName" }
if ([string]::IsNullOrWhiteSpace($InstallabilityJson)) {
    $InstallabilityJson = Join-Path $ProjectRoot "docs\apk-installability-report-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($JsonOut)) {
    $JsonOut = Join-Path $ProjectRoot "docs\apk-permission-review-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($MarkdownOut)) {
    $MarkdownOut = Join-Path $ProjectRoot "docs\apk-permission-review-$Tag.md"
}

$attentionMap = @{
    "android.permission.MANAGE_EXTERNAL_STORAGE" = "broad file access; production release needs explicit user-facing justification"
    "android.permission.QUERY_ALL_PACKAGES" = "broad package visibility; keep scoped and documented"
    "android.permission.REQUEST_INSTALL_PACKAGES" = "package install request permission; verify user-initiated flow"
    "android.permission.PROCESS_OUTGOING_CALLS" = "legacy sensitive telephony permission; confirm compatibility need"
    "android.permission.CAMERA" = "runtime sensitive permission; confirm scanner/onboarding flow"
    "android.permission.POST_NOTIFICATIONS" = "runtime notification permission on modern Android"
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE" = "special foreground service declaration; confirm store-facing explanation"
}

if (-not (Test-Path -LiteralPath $InstallabilityJson)) {
    throw "installability report not found: $InstallabilityJson"
}

$installability = Get-Content -LiteralPath $InstallabilityJson -Raw | ConvertFrom-Json
$apkReviews = @()
foreach ($apk in @($installability.apks)) {
    $permissions = Get-PermissionRows -Apk $apk
    $attention = @()
    foreach ($permission in $permissions) {
        if ($attentionMap.ContainsKey($permission.name)) {
            $attention += [pscustomobject]@{
                permission = $permission.name
                maxSdkVersion = $permission.maxSdkVersion
                reason = $attentionMap[$permission.name]
            }
        }
    }
    $apkReviews += [pscustomobject]@{
        name = $apk.name
        packageName = $apk.badging.metadata.packageName
        versionName = $apk.badging.metadata.versionName
        versionCode = $apk.badging.metadata.versionCode
        permissionCount = @($permissions).Count
        attentionCount = @($attention).Count
        permissions = @($permissions)
        attention = @($attention)
    }
}

$allAttention = @($apkReviews | ForEach-Object { $_.attention } | Where-Object { $_ })
$payload = [pscustomobject]@{
    reportType = "yumebox_apk_permission_review"
    generatedAt = (Get-Date).ToString("o")
    tag = $Tag
    projectRoot = $ProjectRoot
    installabilityReport = $InstallabilityJson
    installabilityOk = [bool]$installability.ok
    ok = ([bool]$installability.ok -and @($apkReviews).Count -gt 0)
    status = if (@($allAttention).Count -gt 0) { "review_required" } else { "ok" }
    referenceBasis = @(
        "Android app signing and package metadata checks prove installability, not production security",
        "OWASP MASVS style review separates permissions and privacy review from APK signature checks",
        "Runtime and special Android permissions require a user-facing justification before production release"
    )
    apks = @($apkReviews)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOut) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarkdownOut) | Out-Null
$payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $JsonOut -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# APK Permission Review - $Tag")
$lines.Add("")
$lines.Add("Generated: $($payload.generatedAt)")
$lines.Add("Status: ``$($payload.status)``")
$lines.Add("Installability report: ``$InstallabilityJson``")
$lines.Add("")
$lines.Add("## APK Summary")
$lines.Add("")
$lines.Add("| APK | Permissions | Attention Items |")
$lines.Add("|---|---:|---:|")
foreach ($review in $apkReviews) {
    $lines.Add("| ``$($review.name)`` | $($review.permissionCount) | $($review.attentionCount) |")
}
$lines.Add("")
$lines.Add("## Attention Items")
$lines.Add("")
if (@($allAttention).Count -eq 0) {
    $lines.Add("- None.")
} else {
    foreach ($review in $apkReviews) {
        foreach ($item in @($review.attention)) {
            $lines.Add("- ``$($review.name)``: ``$($item.permission)`` - $($item.reason)")
        }
    }
}
$lines.Add("")
$lines.Add("## Boundary")
$lines.Add("")
$lines.Add("- This report is a study-build permission review, not a production mobile security certification.")
$lines.Add("- Installability remains covered by zipalign, badging, signature, digest, and optional device-install reports.")
$lines.Add("- Production release requires a separate privacy, permission, and upgrade-path review.")
($lines -join "`n") | Set-Content -LiteralPath $MarkdownOut -Encoding UTF8

Write-Host "Status=$($payload.status)"
Write-Host "JsonOut=$JsonOut"
Write-Host "MarkdownOut=$MarkdownOut"
if (-not $payload.ok) { exit 1 }
