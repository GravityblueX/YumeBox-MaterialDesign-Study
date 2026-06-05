param(
    [Parameter(Mandatory = $true)]
    [Alias("Input")]
    [string]$SourcePath,

    [string]$Output,
    [string]$EncodedImageOutput,
    [ValidateSet("auto", "webp", "jpeg", "png")]
    [string]$Format = "auto",
    [int]$MaxWidth = 1280,
    [int]$MaxHeight = 720,
    [ValidateRange(1, 100)]
    [int]$Quality = 82,
    [switch]$RawBase64,
    [switch]$CopyToClipboard,
    [switch]$KeepOriginalSize
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function Find-CWebpPath {
    foreach ($commandName in @("cwebp", "cwebp.exe")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            return $command.Source
        }
    }

    $wingetPackagesDir = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path -LiteralPath $wingetPackagesDir) {
        $installed = Get-ChildItem -Path $wingetPackagesDir -Recurse -Filter "cwebp.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($installed) {
            return $installed.FullName
        }
    }

    return $null
}

function Find-MagickPath {
    $command = Get-Command magick -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        $installed = Get-ChildItem -Path $root -Directory -Filter "ImageMagick*" -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "magick.exe" } |
            Where-Object { Test-Path -LiteralPath $_ } |
            Sort-Object -Descending |
            Select-Object -First 1
        if ($installed) {
            return $installed
        }
    }

    return $null
}

function Get-WebPInstallHint {
    "Install cwebp with: winget install --id Google.Libwebp --accept-source-agreements --accept-package-agreements"
}

$inputFile = Get-Item -LiteralPath $SourcePath
$cwebpPath = Find-CWebpPath
$magickPath = Find-MagickPath
$resolvedFormat = $Format
if ($resolvedFormat -eq "auto") {
    $resolvedFormat = if ($cwebpPath -or $magickPath) {
        "webp"
    } else {
        "jpeg"
    }
}

$outputPath = if ([string]::IsNullOrWhiteSpace($Output)) {
    $suffix = if ($RawBase64) { "base64.txt" } else { "data-uri.txt" }
    Join-Path $inputFile.DirectoryName "$($inputFile.BaseName).$suffix"
} else {
    $Output
}

if ($KeepOriginalSize -and $inputFile.Extension -ieq ".webp" -and ($resolvedFormat -eq "webp" -or $Format -eq "auto")) {
    $bytes = [System.IO.File]::ReadAllBytes($inputFile.FullName)

    if (-not [string]::IsNullOrWhiteSpace($EncodedImageOutput)) {
        $encodedImagePath = $EncodedImageOutput
        if ([System.IO.Path]::GetExtension($encodedImagePath) -ne ".webp") {
            $encodedImagePath = [System.IO.Path]::ChangeExtension($encodedImagePath, ".webp")
            Write-Warning "Encoded image extension adjusted to match actual format: $encodedImagePath"
        }
        $encodedImageItem = New-Item -ItemType File -Force -Path $encodedImagePath
        [System.IO.File]::WriteAllBytes($encodedImageItem.FullName, $bytes)
    }

    $base64 = [Convert]::ToBase64String($bytes)
    $content = if ($RawBase64) { $base64 } else { "data:image/webp;base64,$base64" }
    $outputItem = New-Item -ItemType File -Force -Path $outputPath
    Set-Content -LiteralPath $outputItem.FullName -Value $content -Encoding ASCII -NoNewline
    if ($CopyToClipboard) {
        Set-Clipboard -Value $content
    }

    Write-Host "Input:  $($inputFile.FullName)"
    Write-Host "Output: $($outputItem.FullName)"
    Write-Host "Format: image/webp"
    Write-Host "Size:   original WebP bytes"
    Write-Host "Bytes:  $($bytes.Length)"
    Write-Host "Text:   $($content.Length) characters"
    if ($CopyToClipboard) {
        Write-Host "Copied output text to clipboard."
    }
    return
}

function Get-ImageCodecInfo([string]$mimeType) {
    [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq $mimeType } |
        Select-Object -First 1
}

function New-EncoderParameters([int]$quality) {
    $encoder = [System.Drawing.Imaging.Encoder]::Quality
    $encoderParameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
    $encoderParameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($encoder, [int64]$quality)
    $encoderParameters
}

$image = [System.Drawing.Image]::FromFile($inputFile.FullName)
$bitmap = $null
$graphics = $null
$memoryStream = [System.IO.MemoryStream]::new()
$bytes = [byte[]]::Empty
$encodedImageItem = $null

try {
    $targetWidth = $image.Width
    $targetHeight = $image.Height

    if (-not $KeepOriginalSize) {
        $scale = [Math]::Min($MaxWidth / $image.Width, $MaxHeight / $image.Height)
        if ($scale -lt 1) {
            $targetWidth = [Math]::Max(1, [int][Math]::Round($image.Width * $scale))
            $targetHeight = [Math]::Max(1, [int][Math]::Round($image.Height * $scale))
        }
    }

    $bitmap = [System.Drawing.Bitmap]::new($targetWidth, $targetHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($image, 0, 0, $targetWidth, $targetHeight)

    if ($resolvedFormat -eq "webp") {
        $tempPng = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid()).png"
        $tempWebp = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid()).webp"
        try {
            $pngCodec = Get-ImageCodecInfo "image/png"
            $bitmap.Save($tempPng, $pngCodec, $null)
            if ($cwebpPath) {
                & $cwebpPath -quiet -q $Quality $tempPng -o $tempWebp
                if ($LASTEXITCODE -ne 0) {
                    throw "cwebp failed with exit code $LASTEXITCODE."
                }
            } elseif ($magickPath) {
                & $magickPath $tempPng -quality $Quality $tempWebp
                if ($LASTEXITCODE -ne 0) {
                    throw "magick failed with exit code $LASTEXITCODE."
                }
            } else {
                if ($Format -eq "webp") {
                    throw "No WebP encoder found. $(Get-WebPInstallHint)"
                }
                Write-Warning "No WebP encoder found. Falling back to JPEG."
                $resolvedFormat = "jpeg"
            }

            if ($resolvedFormat -eq "webp") {
                $bytes = [System.IO.File]::ReadAllBytes($tempWebp)
            }
        } finally {
            Remove-Item -LiteralPath $tempPng, $tempWebp -Force -ErrorAction SilentlyContinue
        }
    }

    if ($resolvedFormat -ne "webp") {
        $mimeType = if ($resolvedFormat -eq "png") { "image/png" } else { "image/jpeg" }
        $codec = Get-ImageCodecInfo $mimeType
        if ($null -eq $codec) {
            throw "No encoder found for $mimeType"
        }

        if ($resolvedFormat -eq "jpeg") {
            $encoderParameters = New-EncoderParameters $Quality
            try {
                $bitmap.Save($memoryStream, $codec, $encoderParameters)
            } finally {
                $encoderParameters.Dispose()
            }
        } else {
            $bitmap.Save($memoryStream, $codec, $null)
        }

        $bytes = $memoryStream.ToArray()
    }

    if (-not [string]::IsNullOrWhiteSpace($EncodedImageOutput)) {
        $encodedImagePath = $EncodedImageOutput
        $actualExtension = if ($resolvedFormat -eq "webp") {
            ".webp"
        } elseif ($resolvedFormat -eq "png") {
            ".png"
        } else {
            ".jpg"
        }
        if ([System.IO.Path]::GetExtension($encodedImagePath) -ne $actualExtension) {
            $encodedImagePath = [System.IO.Path]::ChangeExtension($encodedImagePath, $actualExtension)
            Write-Warning "Encoded image extension adjusted to match actual format: $encodedImagePath"
        }
        $encodedImageItem = New-Item -ItemType File -Force -Path $encodedImagePath
        [System.IO.File]::WriteAllBytes($encodedImageItem.FullName, $bytes)
    }

    $mimeType = if ($resolvedFormat -eq "webp") {
        "image/webp"
    } elseif ($resolvedFormat -eq "png") {
        "image/png"
    } else {
        "image/jpeg"
    }
    $base64 = [Convert]::ToBase64String($bytes)
    $content = if ($RawBase64) { $base64 } else { "data:$mimeType;base64,$base64" }

    $outputItem = New-Item -ItemType File -Force -Path $outputPath
    Set-Content -LiteralPath $outputItem.FullName -Value $content -Encoding ASCII -NoNewline
    if ($CopyToClipboard) {
        Set-Clipboard -Value $content
    }

    Write-Host "Input:  $($inputFile.FullName)"
    Write-Host "Output: $($outputItem.FullName)"
    Write-Host "Format: $mimeType"
    if ($Format -ne $resolvedFormat) {
        Write-Host "Requested format: $Format; resolved format: $resolvedFormat"
    }
    if ($resolvedFormat -eq "webp") {
        $encoderPath = if ($cwebpPath) { $cwebpPath } else { $magickPath }
        Write-Host "WebP encoder: $encoderPath"
    }
    if (-not [string]::IsNullOrWhiteSpace($EncodedImageOutput)) {
        Write-Host "Encoded image: $($encodedImageItem.FullName)"
    }
    Write-Host "Size:   $($image.Width)x$($image.Height) -> ${targetWidth}x${targetHeight}"
    Write-Host "Bytes:  $($inputFile.Length) -> $($bytes.Length)"
    Write-Host "Text:   $($content.Length) characters"
    if ($CopyToClipboard) {
        Write-Host "Copied output text to clipboard."
    }
} finally {
    if ($null -ne $graphics) {
        $graphics.Dispose()
    }
    if ($null -ne $bitmap) {
        $bitmap.Dispose()
    }
    $memoryStream.Dispose()
    $image.Dispose()
}
