# Crop + downscale the campus photo into a page banner.
param(
    [string]$In = "C:\Users\wliang\Documents\GitHub\lw-g38.github.io\images\IMG_4406.jpeg",
    [string]$Out = "C:\Users\wliang\Documents\GitHub\lw-g38.github.io\images\campus-banner.jpg",
    [int]$CropY = 460,      # top of the band (below this: sky we don't need)
    [int]$CropH = 1152,     # 4032 / 1152 = 3.5:1 banner
    [int]$TargetW = 1860,   # 2x the 930px content column, for retina
    [int]$Quality = 82
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile($In)
"Source: $($src.Width) x $($src.Height)"

# iPhone photos can carry an EXIF orientation tag that System.Drawing ignores.
if ($src.PropertyIdList -contains 0x0112) {
    $o = $src.GetPropertyItem(0x0112).Value[0]
    "EXIF orientation: $o (1 = normal, no rotation needed)"
} else {
    "EXIF orientation: not set"
}

$cropW = $src.Width
$targetH = [int][math]::Round($CropH * $TargetW / $cropW)
"Crop  : x=0 y=$CropY w=$cropW h=$CropH  (ratio $([math]::Round($cropW/$CropH,2)):1)"
"Output: $TargetW x $targetH"

$bmp = New-Object System.Drawing.Bitmap($TargetW, $targetH)
$bmp.SetResolution(72, 72)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$srcRect = New-Object System.Drawing.Rectangle -ArgumentList 0, $CropY, $cropW, $CropH
$dstRect = New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $TargetW, $targetH
$g.DrawImage($src, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters -ArgumentList 1
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter -ArgumentList ([System.Drawing.Imaging.Encoder]::Quality, [int]$Quality)

if (Test-Path $Out) { Remove-Item $Out -Force }
$bmp.Save($Out, $codec, $encParams)

$g.Dispose(); $bmp.Dispose(); $src.Dispose()

$size = (Get-Item $Out).Length
"Saved : $Out  ($([math]::Round($size/1KB,1)) KB)"
