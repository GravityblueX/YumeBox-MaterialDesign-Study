param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Repo = 'GravityblueX/YumeBox-MaterialDesign-Study',
    [string]$Tag = '',
    [switch]$SkipDebug,
    [switch]$SkipRelease
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

function Copy-Asset {
    param(
        [string]$Source,
        [string]$BuildType,
        [string]$Tag,
        [string]$AssetDir
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "APK not found: $Source"
    }
    $assetName = "YumeBox-Study-$Tag-arm64-v8a-$BuildType.apk"
    $target = Join-Path $AssetDir $assetName
    Copy-Item -LiteralPath $Source -Destination $target -Force
    return $target
}

$versionName = Read-GradleProperty 'project.version.name'
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "v$versionName"
}

$assetDir = Join-Path $ProjectRoot ".release-assets\$Tag"
New-Item -ItemType Directory -Force -Path $assetDir | Out-Null

$assets = @()
if (-not $SkipDebug) {
    $assets += Copy-Asset `
        -Source (Join-Path $ProjectRoot 'app\build\outputs\apk\debug\YumeBox Study-arm64-v8a-debug.apk') `
        -BuildType 'debug' `
        -Tag $Tag `
        -AssetDir $assetDir
}
if (-not $SkipRelease) {
    $assets += Copy-Asset `
        -Source (Join-Path $ProjectRoot 'app\build\outputs\apk\release\YumeBox Study-arm64-v8a-release.apk') `
        -BuildType 'release' `
        -Tag $Tag `
        -AssetDir $assetDir
}

if ($assets.Count -eq 0) {
    throw 'No APK assets selected.'
}

Write-Host '=== Prepared assets ==='
foreach ($asset in $assets) {
    $hash = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant()
    $item = Get-Item -LiteralPath $asset
    Write-Host ("{0} {1} bytes sha256:{2}" -f $item.Name, $item.Length, $hash)
}

Write-Host '=== Upload to GitHub Release ==='
foreach ($asset in $assets) {
    gh release upload $Tag $asset --repo $Repo --clobber
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Write-Host '=== Refresh release health ==='
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'release-health.ps1') -Tag $Tag -Repo $Repo
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$health = Join-Path $ProjectRoot "release-health-$Tag.md"
if (Test-Path -LiteralPath $health) {
    gh release upload $Tag $health --repo $Repo --clobber
}

Write-Host '=== Release assets ==='
gh release view $Tag --repo $Repo --json tagName,name,url,assets
