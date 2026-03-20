Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$canvasSize = 1024
$targetGlyphRatio = 0.565
$baseEmSize = 580.0
$glyph = [string][char]0x706F
$glyphColor = [System.Drawing.Color]::FromArgb(255, 82, 77, 84)
$skyColor = [System.Drawing.Color]::FromArgb(255, 217, 238, 251)
$lampColor = [System.Drawing.Color]::FromArgb(255, 255, 248, 240)
$opticalOffsetY = -6.0
$preferredFamilies = @(
  "Yu Mincho",
  "BIZ UDMincho Medium",
  "HGPMinchoB",
  "MS Mincho"
)

function Get-FontFamilyName {
  param([string[]]$Candidates)

  $available = [System.Drawing.FontFamily]::Families | Select-Object -ExpandProperty Name
  foreach ($candidate in $Candidates) {
    if ($available -contains $candidate) {
      return $candidate
    }
  }

  throw "A usable Japanese Mincho font was not found."
}

function New-GlyphPath {
  param(
    [System.Drawing.FontFamily]$FontFamily,
    [single]$EmSize
  )

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $format = New-Object System.Drawing.StringFormat([System.Drawing.StringFormat]::GenericTypographic)
  $path.AddString(
    $glyph,
    $FontFamily,
    [int][System.Drawing.FontStyle]::Regular,
    $EmSize,
    [System.Drawing.PointF]::new(0, 0),
    $format
  )
  $format.Dispose()
  return $path
}

function New-IconBitmap {
  param([int]$Size)

  return New-Object System.Drawing.Bitmap($Size, $Size)
}

function Save-Png {
  param(
    [System.Drawing.Bitmap]$Bitmap,
    [string]$Path
  )

  $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

$fontFamilyName = Get-FontFamilyName -Candidates $preferredFamilies
$fontFamily = New-Object System.Drawing.FontFamily($fontFamilyName)

try {
  $initialPath = New-GlyphPath -FontFamily $fontFamily -EmSize ([single]$baseEmSize)
  try {
    $initialBounds = $initialPath.GetBounds()
    $targetWidth = $canvasSize * $targetGlyphRatio
    $scaledEmSize = [single]($baseEmSize * ($targetWidth / $initialBounds.Width))
  }
  finally {
    $initialPath.Dispose()
  }

  $glyphPath = New-GlyphPath -FontFamily $fontFamily -EmSize $scaledEmSize
  try {
    $glyphBounds = $glyphPath.GetBounds()
    $translateX = (($canvasSize - $glyphBounds.Width) / 2.0) - $glyphBounds.X
    $translateY = (($canvasSize - $glyphBounds.Height) / 2.0) - $glyphBounds.Y + $opticalOffsetY

    $matrix = New-Object System.Drawing.Drawing2D.Matrix
    try {
      $matrix.Translate([single]$translateX, [single]$translateY)
      $glyphPath.Transform($matrix)
    }
    finally {
      $matrix.Dispose()
    }

    $masterBitmap = New-IconBitmap -Size $canvasSize
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($masterBitmap)
      try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.Clear($skyColor)

        $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
          [System.Drawing.PointF]::new(0, $canvasSize),
          [System.Drawing.PointF]::new($canvasSize, 0),
          $skyColor,
          $lampColor
        )
        try {
          $graphics.FillRectangle($bgBrush, 0, 0, $canvasSize, $canvasSize)
        }
        finally {
          $bgBrush.Dispose()
        }

        $textBrush = New-Object System.Drawing.SolidBrush($glyphColor)
        try {
          $graphics.FillPath($textBrush, $glyphPath)
        }
        finally {
          $textBrush.Dispose()
        }
      }
      finally {
        $graphics.Dispose()
      }

      $targets = @(
        @{ Size = 1024; Paths = @("suminohi-icon-1024.png") },
        @{ Size = 512; Paths = @("suminohi-icon-512.png", "icon-512.png") },
        @{ Size = 192; Paths = @("suminohi-icon-192.png", "icon-192.png") },
        @{ Size = 180; Paths = @("suminohi-icon-180.png", "icon-180.png") }
      )

      foreach ($target in $targets) {
        $outputBitmap = if ($target.Size -eq $canvasSize) {
          $masterBitmap
        } else {
          $resized = New-IconBitmap -Size $target.Size
          $resizedGraphics = [System.Drawing.Graphics]::FromImage($resized)
          try {
            $resizedGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $resizedGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $resizedGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $resizedGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $resizedGraphics.DrawImage($masterBitmap, 0, 0, $target.Size, $target.Size)
          }
          finally {
            $resizedGraphics.Dispose()
          }
          $resized
        }

        try {
          foreach ($relativePath in $target.Paths) {
            $absolutePath = Join-Path $scriptDir $relativePath
            Save-Png -Bitmap $outputBitmap -Path $absolutePath
          }
        }
        finally {
          if ($target.Size -ne $canvasSize) {
            $outputBitmap.Dispose()
          }
        }
      }

      Write-Output ("Generated icons with font '{0}' at em-size {1}." -f $fontFamilyName, [math]::Round($scaledEmSize, 1))
    }
    finally {
      $masterBitmap.Dispose()
    }
  }
  finally {
    $glyphPath.Dispose()
  }
}
finally {
  $fontFamily.Dispose()
}
