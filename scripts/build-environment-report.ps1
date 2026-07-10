param(
    [string]$Tag = "",
    [string]$JsonOut = "",
    [string]$MarkdownOut = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Read-PropertiesFile {
    param([string]$Path)
    $props = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $props }
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
    $Gates.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
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

function Escape-MarkdownInline {
    param([object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return ([string]$Value).
        Replace("`r`n", " ").Replace("`n", " ").Replace("`r", " ")
}

function Format-MarkdownCodeSpan {
    param([object]$Value)
    $text = Escape-MarkdownInline -Value $Value
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $maxTicks = 0
    foreach ($match in [regex]::Matches($text, '`+')) {
        if ($match.Value.Length -gt $maxTicks) { $maxTicks = $match.Value.Length }
    }
    $fence = '`' * ($maxTicks + 1)
    $padded = if ($text.StartsWith('`') -or $text.EndsWith('`')) { " $text " } else { $text }
    return "$fence$padded$fence"
}

function Invoke-Text {
    param([string]$Command, [string[]]$CommandArgs = @())
    try {
        $output = & $Command @CommandArgs 2>&1
        return [pscustomobject]@{
            exitCode = $LASTEXITCODE
            output = @($output | ForEach-Object { [string]$_ })
        }
    } catch {
        return [pscustomobject]@{
            exitCode = 1
            output = @([string]$_.Exception.Message)
        }
    }
}

function Resolve-AndroidSdkRoot {
    param($LocalProps)
    if ($env:ANDROID_HOME) { return $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { return $env:ANDROID_SDK_ROOT }
    if ($LocalProps["sdk.dir"]) { return ([string]$LocalProps["sdk.dir"] -replace "\\\\", "\") }
    return (Join-Path $env:LOCALAPPDATA "Android\Sdk")
}

$gradleProps = Read-PropertiesFile (Join-Path $ProjectRoot "gradle.properties")
$localProps = Read-PropertiesFile (Join-Path $ProjectRoot "local.properties")
$versionName = [string]$gradleProps["project.version.name"]
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "v$versionName" }
if ([string]::IsNullOrWhiteSpace($JsonOut)) { $JsonOut = Join-Path $ProjectRoot "docs\build-environment-$Tag.json" }
if ([string]::IsNullOrWhiteSpace($MarkdownOut)) { $MarkdownOut = Join-Path $ProjectRoot "docs\build-environment-$Tag.md" }

$sdkRoot = Resolve-AndroidSdkRoot -LocalProps $localProps
$buildToolsRoot = Join-Path $sdkRoot "build-tools"
$buildTools = @()
if (Test-Path -LiteralPath $buildToolsRoot) {
    $buildTools = @(Get-ChildItem -LiteralPath $buildToolsRoot -Directory | Sort-Object Name | ForEach-Object { $_.Name })
}
$selectedBuildTools = ""
foreach ($name in ($buildTools | Sort-Object -Descending)) {
    $dir = Join-Path $buildToolsRoot $name
    if ((Test-Path -LiteralPath (Join-Path $dir "apksigner.bat")) -and (Test-Path -LiteralPath (Join-Path $dir "zipalign.exe")) -and (Test-Path -LiteralPath (Join-Path $dir "aapt.exe"))) {
        $selectedBuildTools = $name
        break
    }
}

$java = Invoke-Text "java" @("-version")
$gradleWrapper = Join-Path $ProjectRoot "gradlew.bat"
$gradleVersion = if (Test-Path -LiteralPath $gradleWrapper) {
    Invoke-Text $gradleWrapper @("--version")
} else {
    [pscustomobject]@{ exitCode = 1; output = @("gradlew.bat missing") }
}

$gates = New-Object System.Collections.Generic.List[object]
Add-Gate $gates "gradle.properties exists" (Test-Path -LiteralPath (Join-Path $ProjectRoot "gradle.properties")) "gradle.properties"
Add-Gate $gates "local.properties exists" (Test-Path -LiteralPath (Join-Path $ProjectRoot "local.properties")) "local.properties"
Add-Gate $gates "version name present" (-not [string]::IsNullOrWhiteSpace($versionName)) $versionName
Add-Gate $gates "version code present" (-not [string]::IsNullOrWhiteSpace([string]$gradleProps["project.version.code"])) ([string]$gradleProps["project.version.code"])
Add-Gate $gates "application id present" (-not [string]::IsNullOrWhiteSpace([string]$gradleProps["project.applicationId"])) ([string]$gradleProps["project.applicationId"])
Add-Gate $gates "Android SDK root exists" (Test-Path -LiteralPath $sdkRoot) $sdkRoot
Add-Gate $gates "Android build tools available" (-not [string]::IsNullOrWhiteSpace($selectedBuildTools)) $selectedBuildTools
Add-Gate $gates "Gradle wrapper exists" (Test-Path -LiteralPath $gradleWrapper) $gradleWrapper
Add-Gate $gates "Gradle wrapper version readable" ($gradleVersion.exitCode -eq 0 -and (@($gradleVersion.output).Count -gt 0)) "exit=$($gradleVersion.exitCode)"
Add-Gate $gates "Java version readable" ($java.exitCode -eq 0 -or @($java.output).Count -gt 0) "exit=$($java.exitCode)"

$gateArray = @(foreach ($gate in $gates) { $gate })
$failures = @($gateArray | Where-Object { -not [bool]$_.ok })
$payload = [pscustomobject]@{
    reportType = "yumebox_build_environment"
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $ProjectRoot
    tag = $Tag
    ok = ($failures.Count -eq 0)
    android = [pscustomobject]@{
        sdkRoot = $sdkRoot
        buildTools = @($buildTools)
        selectedBuildTools = $selectedBuildTools
    }
    java = [pscustomobject]@{
        exitCode = $java.exitCode
        output = @($java.output)
    }
    gradle = [pscustomobject]@{
        wrapper = $gradleWrapper
        exitCode = $gradleVersion.exitCode
        output = @($gradleVersion.output)
    }
    project = [pscustomobject]@{
        applicationId = [string]$gradleProps["project.applicationId"]
        versionName = $versionName
        versionCode = [string]$gradleProps["project.version.code"]
        abiList = [string]$gradleProps["abi.app.list"]
    }
    gates = $gateArray
    failures = @($failures)
    referenceBasis = @(
        "Android app signing and package tooling require traceable SDK build tools",
        "Gradle wrapper version is part of reproducible local build evidence",
        "Build environment report complements APK digest and provenance reports"
    )
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOut) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarkdownOut) | Out-Null
$payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $JsonOut -Encoding UTF8

$status = if ($payload.ok) { "OK" } else { "FAIL" }
$statusCode = Format-MarkdownCodeSpan -Value $status
$sdkRootCode = Format-MarkdownCodeSpan -Value $sdkRoot
$selectedBuildToolsCode = Format-MarkdownCodeSpan -Value $selectedBuildTools
$applicationIdCode = Format-MarkdownCodeSpan -Value $payload.project.applicationId
$versionLabelCode = Format-MarkdownCodeSpan -Value "$($payload.project.versionName)/$($payload.project.versionCode)"
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Build Environment - $Tag")
$lines.Add("")
$lines.Add("Generated: $($payload.generatedAt)")
$lines.Add("Status: $statusCode")
$lines.Add("Android SDK: $sdkRootCode")
$lines.Add("Selected build-tools: $selectedBuildToolsCode")
$lines.Add("Application: $applicationIdCode")
$lines.Add("Version: $versionLabelCode")
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
$lines.Add("## Java")
$lines.Add("")
foreach ($line in @($java.output | Select-Object -First 6)) {
    $lineCode = Format-MarkdownCodeSpan -Value $line
    $lines.Add("- $lineCode")
}
$lines.Add("")
$lines.Add("## Gradle")
$lines.Add("")
foreach ($line in @($gradleVersion.output | Select-Object -First 10)) {
    $lineCode = Format-MarkdownCodeSpan -Value $line
    $lines.Add("- $lineCode")
}
$lines.Add("")
($lines -join "`n") | Set-Content -LiteralPath $MarkdownOut -Encoding UTF8

Write-Host "Status=$status"
Write-Host "JsonOut=$JsonOut"
Write-Host "MarkdownOut=$MarkdownOut"
if (-not $payload.ok) { exit 1 }
