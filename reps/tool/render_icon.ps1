# Renderiza o icone do app (logo-3-mark) em PNG nos tamanhos do Android.
# Usa System.Drawing pra evitar dependencia externa (ImageMagick/Inkscape).
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File tool/render_icon.ps1
#
# Saidas:
#   android/app/src/main/res/mipmap-mdpi/ic_launcher.png   (48x48)
#   android/app/src/main/res/mipmap-hdpi/ic_launcher.png   (72x72)
#   android/app/src/main/res/mipmap-xhdpi/ic_launcher.png  (96x96)
#   android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png (144x144)
#   android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png (192x192)
#   android/app/src/main/res/drawable/splash_logo.png (512x512)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$resDir = "$root\android\app\src\main\res"

function Render-Icon {
  param(
    [int]$size,
    [string]$outPath,
    [switch]$withText
  )

  # Canvas
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  # Background dark
  $bgColor = [System.Drawing.Color]::FromArgb(255, 10, 10, 11)
  $g.Clear($bgColor)

  # Dimensoes proporcionais (referencia 1024x1024 do SVG)
  $scale = $size / 1024.0

  # Helper para retangulo
  function Fill-Rect {
    param($graphics, $r, $g_, $b, $alpha, $x, $y, $w, $h)
    $color = [System.Drawing.Color]::FromArgb($alpha, $r, $g_, $b)
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillRectangle($brush, $x, $y, $w, $h)
    $brush.Dispose()
  }

  # --- 3 barras representando reps ---
  # REP 1 (vermelho cheio) - barra completa
  $r = 239; $g_ = 68; $b = 68
  Fill-Rect $g $r $g_ $b 255 (240*$scale) (298*$scale) (56*$scale) (120*$scale)
  Fill-Rect $g $r $g_ $b 255 (728*$scale) (298*$scale) (56*$scale) (120*$scale)
  Fill-Rect $g $r $g_ $b 255 (296*$scale) (346*$scale) (432*$scale) (24*$scale)

  # REP 2 (branco 55%)
  $alpha2 = [int]([Math]::Round(255 * 0.55))
  Fill-Rect $g 255 255 255 $alpha2 (272*$scale) (498*$scale) (48*$scale) (100*$scale)
  Fill-Rect $g 255 255 255 $alpha2 (704*$scale) (498*$scale) (48*$scale) (100*$scale)
  Fill-Rect $g 255 255 255 $alpha2 (320*$scale) (538*$scale) (384*$scale) (20*$scale)

  # REP 3 (branco 22%)
  $alpha3 = [int]([Math]::Round(255 * 0.22))
  Fill-Rect $g 255 255 255 $alpha3 (304*$scale) (678*$scale) (40*$scale) (80*$scale)
  Fill-Rect $g 255 255 255 $alpha3 (680*$scale) (678*$scale) (40*$scale) (80*$scale)
  Fill-Rect $g 255 255 255 $alpha3 (344*$scale) (710*$scale) (336*$scale) (16*$scale)

  # Wordmark inferior + chip vermelho top-left - so quando o icone for grande
  # o suficiente para o texto ser legivel.
  if ($withText -and $size -ge 96) {
    # Marker chip top-left
    Fill-Rect $g 239 68 68 255 (80*$scale) (80*$scale) (48*$scale) (48*$scale)

    # Texto REPS (Space Grotesk em fallback Arial Black)
    $fontSize = [Math]::Max(8, [int]([Math]::Round(48 * $scale * 1.0)))
    $font = New-Object System.Drawing.Font("Arial Black", $fontSize, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, ($size * 0.82), $size, ($size * 0.12))
    $g.DrawString("REPS", $font, $brush, $rect, $sf)
    $font.Dispose()
    $brush.Dispose()
  }

  $g.Dispose()
  $dir = Split-Path $outPath -Parent
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "[OK] $outPath ($size x $size)" -ForegroundColor Green
}

# --- Mipmaps Android ---
$sizes = @{
  'mipmap-mdpi'    = 48
  'mipmap-hdpi'    = 72
  'mipmap-xhdpi'   = 96
  'mipmap-xxhdpi'  = 144
  'mipmap-xxxhdpi' = 192
}

foreach ($folder in $sizes.Keys) {
  $size = $sizes[$folder]
  $out = "$resDir\$folder\ic_launcher.png"
  Render-Icon -size $size -outPath $out -withText
}

# --- Splash logo (drawable, 512px) ---
$splashOut = "$resDir\drawable\splash_logo.png"
Render-Icon -size 512 -outPath $splashOut -withText
$splashOut2 = "$resDir\drawable-v21\splash_logo.png"
Render-Icon -size 512 -outPath $splashOut2 -withText

Write-Host ""
Write-Host "[done] Icones renderizados com sucesso." -ForegroundColor Cyan
