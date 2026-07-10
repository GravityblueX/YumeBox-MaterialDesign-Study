param(
    [string]$Tag = "",
    [string]$PermissionReviewJson = "",
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

function Escape-MarkdownCell {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    return $text.Replace("`r`n", " ").Replace("`n", " ").Replace("`r", " ").Replace("|", "\|")
}

function Format-MarkdownCodeSpan {
    param([object]$Value)
    $text = Escape-MarkdownCell -Value $Value
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $maxTicks = 0
    foreach ($match in [regex]::Matches($text, '`+')) {
        if ($match.Value.Length -gt $maxTicks) { $maxTicks = $match.Value.Length }
    }
    $fence = '`' * ($maxTicks + 1)
    $padded = if ($text.StartsWith('`') -or $text.EndsWith('`')) { " $text " } else { $text }
    return "$fence$padded$fence"
}

$props = Read-PropertiesFile (Join-Path $ProjectRoot "gradle.properties")
$versionName = [string]$props["project.version.name"]
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "v$versionName" }
if ([string]::IsNullOrWhiteSpace($PermissionReviewJson)) {
    $PermissionReviewJson = Join-Path $ProjectRoot "docs\apk-permission-review-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($JsonOut)) {
    $JsonOut = Join-Path $ProjectRoot "docs\apk-permission-justification-$Tag.json"
}
if ([string]::IsNullOrWhiteSpace($MarkdownOut)) {
    $MarkdownOut = Join-Path $ProjectRoot "docs\apk-permission-justification-$Tag.md"
}

$justificationMap = @{
    "android.permission.ACCESS_NETWORK_STATE" = @{
        category = "network-state"
        sensitivity = "normal"
        userBenefit = "Detects network availability before starting proxy, profile refresh, or diagnostics work."
        productionAction = "Keep; mention network-status use in privacy documentation."
    }
    "android.permission.ACCESS_WIFI_STATE" = @{
        category = "network-state"
        sensitivity = "normal"
        userBenefit = "Reads Wi-Fi state for connection display and network-aware routing behavior."
        productionAction = "Keep only if UI or routing features still consume Wi-Fi state."
    }
    "android.permission.CAMERA" = @{
        category = "runtime-sensitive"
        sensitivity = "dangerous"
        userBenefit = "Supports QR/profile scanning from the onboarding and profile import flows."
        productionAction = "Gate behind an explicit user action and request at runtime with scanner copy."
    }
    "android.permission.FOREGROUND_SERVICE" = @{
        category = "foreground-service"
        sensitivity = "normal"
        userBenefit = "Keeps the proxy/VPN runtime visible and controllable while traffic handling is active."
        productionAction = "Keep notification text accurate and user dismiss/stop controls obvious."
    }
    "android.permission.FOREGROUND_SERVICE_DATA_SYNC" = @{
        category = "foreground-service"
        sensitivity = "normal"
        userBenefit = "Covers foreground profile/data synchronization while the service is active."
        productionAction = "Keep scoped to active user-visible sync work."
    }
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE" = @{
        category = "special-foreground-service"
        sensitivity = "special"
        userBenefit = "Documents the special foreground service class needed by the proxy runtime mode."
        productionAction = "Review Play/store-facing declaration before production release."
    }
    "android.permission.INTERNET" = @{
        category = "network"
        sensitivity = "normal"
        userBenefit = "Allows profile fetch, proxy control, diagnostics, and web-based feature surfaces."
        productionAction = "Keep; disclose network use and avoid sending private profile data unexpectedly."
    }
    "android.permission.MANAGE_EXTERNAL_STORAGE" = @{
        category = "broad-storage"
        sensitivity = "special"
        userBenefit = "Supports importing, exporting, and managing local configuration assets during study builds."
        productionAction = "Reduce scope before store release or provide a specific user-facing all-files rationale."
    }
    "android.permission.POST_NOTIFICATIONS" = @{
        category = "runtime-sensitive"
        sensitivity = "dangerous"
        userBenefit = "Shows service status, traffic state, and important runtime notifications on modern Android."
        productionAction = "Request at runtime and keep notification categories user-controllable."
    }
    "android.permission.PROCESS_OUTGOING_CALLS" = @{
        category = "legacy-telephony"
        sensitivity = "restricted"
        userBenefit = "Legacy compatibility surface inherited by the fork; no core study APK flow should depend on it."
        productionAction = "Remove unless a tested, documented feature still requires it."
    }
    "android.permission.QUERY_ALL_PACKAGES" = @{
        category = "package-visibility"
        sensitivity = "special"
        userBenefit = "Supports app selection, access control, and package-aware proxy routing views."
        productionAction = "Minimize with package visibility queries when possible and document the user feature."
    }
    "android.permission.READ_EXTERNAL_STORAGE" = @{
        category = "legacy-storage"
        sensitivity = "dangerous"
        userBenefit = "Reads imported profile files on older Android versions."
        productionAction = "Keep maxSdk scoped; prefer system picker on newer Android versions."
    }
    "android.permission.RECEIVE_BOOT_COMPLETED" = @{
        category = "startup"
        sensitivity = "normal"
        userBenefit = "Allows user-enabled service restoration after reboot."
        productionAction = "Keep behind explicit auto-start setting and respect disabled state."
    }
    "android.permission.REQUEST_INSTALL_PACKAGES" = @{
        category = "package-install"
        sensitivity = "special"
        userBenefit = "Supports user-initiated local package/update flows in study builds."
        productionAction = "Require user confirmation and remove if release distribution does not install packages."
    }
    "android.permission.USE_BIOMETRIC" = @{
        category = "authentication"
        sensitivity = "runtime-protected"
        userBenefit = "Supports biometric lock or sensitive action confirmation."
        productionAction = "Keep optional and provide fallback authentication."
    }
    "android.permission.USE_FINGERPRINT" = @{
        category = "legacy-authentication"
        sensitivity = "runtime-protected"
        userBenefit = "Supports older devices that expose fingerprint APIs."
        productionAction = "Keep only for compatibility; prefer USE_BIOMETRIC where available."
    }
    "android.permission.VIBRATE" = @{
        category = "haptics"
        sensitivity = "normal"
        userBenefit = "Provides tactile feedback for switches, dialogs, and runtime controls."
        productionAction = "Keep lightweight and respect system haptic settings."
    }
    "android.permission.WRITE_EXTERNAL_STORAGE" = @{
        category = "legacy-storage"
        sensitivity = "dangerous"
        userBenefit = "Writes exported profile or diagnostic files on older Android versions."
        productionAction = "Keep maxSdk scoped; prefer app-scoped storage or system picker."
    }
    "com.android.permission.GET_INSTALLED_APPS" = @{
        category = "package-visibility"
        sensitivity = "vendor-special"
        userBenefit = "Supports package-aware routing on Android distributions that expose this vendor permission."
        productionAction = "Confirm device/vendor need and remove if redundant with Android package visibility APIs."
    }
    "com.github.yizuka17.yumebox.md3.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" = @{
        category = "app-private"
        sensitivity = "signature"
        userBenefit = "Protects app-internal dynamic receiver traffic from other apps."
        productionAction = "Keep as app-private protection for internal broadcast surfaces."
    }
}

$gates = New-Object System.Collections.Generic.List[object]
Add-Gate $gates "permission review exists" (Test-Path -LiteralPath $PermissionReviewJson) $PermissionReviewJson
if (-not (Test-Path -LiteralPath $PermissionReviewJson)) {
    throw "permission review not found: $PermissionReviewJson"
}

$review = Get-Content -LiteralPath $PermissionReviewJson -Raw | ConvertFrom-Json
$permissions = @{}
$attentionReasons = @{}
foreach ($apk in @($review.apks)) {
    foreach ($permission in @($apk.permissions)) {
        $name = [string]$permission.name
        if (-not $permissions.ContainsKey($name)) {
            $permissions[$name] = [pscustomobject]@{
                name = $name
                maxSdkVersion = [string]$permission.maxSdkVersion
                presentInApks = New-Object System.Collections.Generic.List[string]
            }
        }
        $permissions[$name].presentInApks.Add([string]$apk.name)
    }
    foreach ($item in @($apk.attention)) {
        $attentionReasons[[string]$item.permission] = [string]$item.reason
    }
}

$rows = @()
foreach ($name in ($permissions.Keys | Sort-Object)) {
    $definition = $justificationMap[$name]
    $known = $null -ne $definition
    $rows += [pscustomobject]@{
        permission = $name
        maxSdkVersion = [string]$permissions[$name].maxSdkVersion
        sensitivity = if ($known) { [string]$definition.sensitivity } else { "unknown" }
        category = if ($known) { [string]$definition.category } else { "undocumented" }
        userBenefit = if ($known) { [string]$definition.userBenefit } else { "" }
        productionAction = if ($known) { [string]$definition.productionAction } else { "" }
        attentionReason = if ($attentionReasons.ContainsKey($name)) { [string]$attentionReasons[$name] } else { "" }
        presentInApks = @($permissions[$name].presentInApks)
    }
}

$apkPermissionSets = @(
    foreach ($apk in @($review.apks)) {
        (@($apk.permissions) | ForEach-Object { [string]$_.name } | Sort-Object) -join "`n"
    }
)
$missingDefinitions = @($rows | Where-Object { [string]::IsNullOrWhiteSpace($_.userBenefit) -or [string]::IsNullOrWhiteSpace($_.productionAction) })
$attentionMissingActions = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.attentionReason) -and [string]::IsNullOrWhiteSpace($_.productionAction) })

Add-Gate $gates "permission review ok" ([bool]$review.ok) "ok=$($review.ok)"
Add-Gate $gates "permissions discovered" ($rows.Count -ge 10) "$($rows.Count) permission(s)"
Add-Gate $gates "all permissions have justification" ($missingDefinitions.Count -eq 0) "$($missingDefinitions.Count) missing"
Add-Gate $gates "attention permissions have production actions" ($attentionMissingActions.Count -eq 0) "$($attentionMissingActions.Count) missing"
Add-Gate $gates "APK permission sets consistent" (($apkPermissionSets | Select-Object -Unique).Count -eq 1) "$(@($review.apks).Count) APK(s)"

$gateArray = @($gates | ForEach-Object { $_ })
$failures = @($gateArray | Where-Object { -not [bool]$_.ok })
$payload = [pscustomobject]@{
    reportType = "yumebox_apk_permission_justification"
    generatedAt = (Get-Date).ToString("o")
    tag = $Tag
    projectRoot = $ProjectRoot
    permissionReview = $PermissionReviewJson
    ok = ($failures.Count -eq 0)
    status = if ($attentionReasons.Count -gt 0) { "review_required" } else { "ok" }
    summary = [pscustomobject]@{
        permissionCount = $rows.Count
        attentionPermissionCount = $attentionReasons.Count
        apkCount = @($review.apks).Count
    }
    gates = $gateArray
    failures = @($failures)
    permissions = @($rows)
    referenceBasis = @(
        "Android permission review should connect package metadata to user-facing reasons",
        "OWASP MASVS style mobile review separates installability from privacy and permission justification",
        "Special and dangerous permissions need release-time rationale before production distribution"
    )
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOut) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarkdownOut) | Out-Null
$payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $JsonOut -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$status = if ($payload.ok) { "OK" } else { "FAIL" }
$statusCode = Format-MarkdownCodeSpan -Value $status
$reviewStatusCode = Format-MarkdownCodeSpan -Value $payload.status
$permissionReviewJsonCode = Format-MarkdownCodeSpan -Value $PermissionReviewJson
$lines.Add("# APK Permission Justification - $Tag")
$lines.Add("")
$lines.Add("Generated: $($payload.generatedAt)")
$lines.Add("Status: $statusCode")
$lines.Add("Review status: $reviewStatusCode")
$lines.Add("Permission review: $permissionReviewJsonCode")
$lines.Add("")
$lines.Add("## Gates")
$lines.Add("")
$lines.Add("| Gate | Result | Detail |")
$lines.Add("|---|---|---|")
foreach ($gate in $payload.gates) {
    $gateStatus = if ($gate.ok) { "OK" } else { "FAIL" }
    $lines.Add("| $(Escape-MarkdownCell -Value $gate.name) | $gateStatus | $(Escape-MarkdownCell -Value $gate.detail) |")
}
$lines.Add("")
$lines.Add("## Permission Reasons")
$lines.Add("")
$lines.Add("| Permission | Sensitivity | Category | User Benefit | Production Action |")
$lines.Add("|---|---|---|---|---|")
foreach ($row in $rows) {
    $lines.Add("| $(Escape-MarkdownCell -Value $row.permission) | $(Escape-MarkdownCell -Value $row.sensitivity) | $(Escape-MarkdownCell -Value $row.category) | $(Escape-MarkdownCell -Value $row.userBenefit) | $(Escape-MarkdownCell -Value $row.productionAction) |")
}
$lines.Add("")
$lines.Add("## Boundary")
$lines.Add("")
$lines.Add("- This report explains the study APK permission surface; it does not certify production mobile security.")
$lines.Add("- Special and dangerous permissions remain review-required before a public store release.")
$lines.Add("- Installability remains verified separately by zipalign, package metadata, signature, and digest checks.")
$lines.Add("")
($lines -join "`n") | Set-Content -LiteralPath $MarkdownOut -Encoding UTF8

Write-Host "Status=$status"
Write-Host "JsonOut=$JsonOut"
Write-Host "MarkdownOut=$MarkdownOut"
if (-not $payload.ok) { exit 1 }
