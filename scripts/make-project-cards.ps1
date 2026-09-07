# Normalise project photos into consistent 16:10 card images.
#
# Sources arrive at assorted sizes, ratios and formats (including .webp, which
# GDI+ cannot read), so this uses WPF's imaging stack rather than
# System.Drawing: BitmapDecoder handles every format Windows has a codec for.
#
# Each image is centre-cropped to 16:10 and scaled to 800x500, matching the
# aspect-ratio box the project cards render in.

param(
    [string]$ImagesDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "images"),
    [int]$TargetW = 800,
    [int]$TargetH = 500,
    [int]$Quality = 82
)

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$outDir = Join-Path $ImagesDir "projects"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# source file -> output name
$map = [ordered]@{
    "nrlf.jpg"         = "nrlf.jpg"
    "scmb.jpg"         = "scmb.jpg"
    "shc-redwood.webp" = "shc-redwood.jpg"
    "som-stanford.jpg" = "som-stanford.jpg"
    "ucsf.jpg"         = "ucsf-parnassus.jpg"
    "ucsf-mb.jpg"      = "ucsf-mission-bay.jpg"
}

$targetRatio = $TargetW / $TargetH

foreach ($srcName in $map.Keys) {
    $inPath = Join-Path $ImagesDir $srcName
    $outPath = Join-Path $outDir $map[$srcName]

    if (-not (Test-Path $inPath)) { "SKIP  $srcName (not found)"; continue }

    try {
        $stream = [System.IO.File]::OpenRead($inPath)
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
            $stream,
            [System.Windows.Media.Imaging.BitmapCreateOptions]::None,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $frame = $decoder.Frames[0]
        $stream.Close()
    }
    catch {
        "FAIL  $srcName -- cannot decode: $($_.Exception.Message)"
        continue
    }

    $sw = $frame.PixelWidth
    $sh = $frame.PixelHeight
    $srcRatio = $sw / $sh

    # Centre-crop to the target ratio.
    if ($srcRatio -gt $targetRatio) {
        $cw = [int][math]::Round($sh * $targetRatio); $ch = $sh
    }
    else {
        $cw = $sw; $ch = [int][math]::Round($sw / $targetRatio)
    }
    if ($cw -gt $sw) { $cw = $sw }
    if ($ch -gt $sh) { $ch = $sh }
    $cx = [int][math]::Floor(($sw - $cw) / 2)
    $cy = [int][math]::Floor(($sh - $ch) / 2)

    $rect = New-Object System.Windows.Int32Rect $cx, $cy, $cw, $ch
    $cropped = New-Object System.Windows.Media.Imaging.CroppedBitmap $frame, $rect

    $scale = New-Object System.Windows.Media.ScaleTransform ($TargetW / $cw), ($TargetH / $ch)
    $scaled = New-Object System.Windows.Media.Imaging.TransformedBitmap $cropped, $scale

    $encoder = New-Object System.Windows.Media.Imaging.JpegBitmapEncoder
    $encoder.QualityLevel = $Quality
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($scaled))

    $fs = [System.IO.File]::Open($outPath, [System.IO.FileMode]::Create)
    $encoder.Save($fs)
    $fs.Close()

    $kb = [math]::Round((Get-Item $outPath).Length / 1KB, 1)
    "OK    {0,-18} {1,4}x{2,-4} -> crop {3}x{4} -> {5}x{6}  ({7} KB)" -f `
        $srcName, $sw, $sh, $cw, $ch, $TargetW, $TargetH, $kb
}
