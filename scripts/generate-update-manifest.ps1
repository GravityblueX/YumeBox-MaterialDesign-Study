param(
    [Parameter(Mandatory = $true)]
    [string]$Apk,

    [Parameter(Mandatory = $true)]
    [string]$Tag,

    [Parameter(Mandatory = $true)]
    [string]$VersionName,

    [Parameter(Mandatory = $true)]
    [int]$VersionCode,

    [string]$Owner = "Yizuka17",
    [string]$Repo = "YumeBox-MaterialDesign",
    [string]$Channel = "stable",
    [string]$Output = "website/update/update.json",
    [string]$ReleaseNotes = "",
    [string]$ManifestUrl = "",
    [string]$CoverUrl = "",
    [string]$CoverDataUriFile = ""
)

$ErrorActionPreference = "Stop"

$apkFile = Get-Item -LiteralPath $Apk
$fileName = $apkFile.Name
$releaseApkFileName = "YumeBoxMD3-release.apk"
$manifestBranch = if ($Channel -eq "preview") { "Dev" } else { "Yume" }
if ([string]::IsNullOrWhiteSpace($ManifestUrl)) {
    $ManifestUrl = "https://raw.githubusercontent.com/$Owner/$Repo/$manifestBranch/website/update/$(Split-Path -Leaf $Output)"
}
$coverDataUri = if (-not [string]::IsNullOrWhiteSpace($CoverDataUriFile)) {
    (Get-Content -LiteralPath $CoverDataUriFile -Raw).Trim()
} else {
    ""
}

$manifest = [ordered]@{
    manifestUrl = $ManifestUrl
    channel = $Channel
    tag = $Tag
    versionName = $VersionName
    versionCode = $VersionCode
    releaseNotes = $ReleaseNotes
    releaseUrl = "https://github.com/$Owner/$Repo/releases/tag/$Tag"
    coverUrl = $CoverUrl
    coverDataUri = $coverDataUri
}

$outputParent = Split-Path -Parent $Output
if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
    New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
}

$json = $manifest | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $Output -Value $json -Encoding UTF8
Write-Host "Generated $Output"
Write-Host "Commit and push the generated manifest under website/update on the $manifestBranch branch."
Write-Host "Upload the APK to the GitHub Release as:"
Write-Host "  $releaseApkFileName"
Write-Host "Source APK:"
Write-Host "  $fileName"
