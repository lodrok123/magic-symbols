# Hoja resumen de las capturas de las cinco reglas (3/11/2026): una fila por hechizo, un fotograma por columna, recortados al entorno de la jugadora.
# Uso (desde la raiz):  powershell -NoProfile -ExecutionPolicy Bypass -File herramientas\hoja_reglas_glifos.ps1 [carpeta] [salida.png]
# Lee celdas.json de la carpeta (lo escribe captura_reglas_glifos.gd). Solo ASCII en el script: los rotulos con runas se leen en el diario.
param([string]$Carpeta = "docs\capturas\vfx_en_juego\reglas_glifos", [string]$Salida = "")
Add-Type -AssemblyName System.Drawing
$Carpeta = (Resolve-Path $Carpeta).Path
if ($Salida -eq "") { $Salida = Join-Path $Carpeta "hoja_reglas_glifos.png" }
$json = [IO.File]::ReadAllText((Join-Path $Carpeta "celdas.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
$rotulos = @{
  "r1_muro_fuego" = "R1  fuego  wall-barrier + line + line + height + arrow : the wall ADVANCES"
  "r2_muro_va_y_vuelve" = "R2  fuego  same + return : goes and COMES BACK"
  "r3_orbes_fuego" = "R3  fuego  repeat + repeat + return (no arrow) : three ORBS orbit the caster"
  "r4_pilar_agua" = "R4  agua  height x3 + grow : pillar RISES from the bottom (and lifts what is inside)"
  "r5_explosion_agua" = "R5  agua  grow + grow + charge : water ball grows and EXPLODES in an area"
  "rayo_adelante" = "rayo  line x3 : lightning straight ahead (untouched)"
}
$grupos = $json | Group-Object hechizo
$ancho = 420; $alto = 260; $margen = 6; $cab = 22
$maxCols = 1; foreach ($gr in $grupos) { if ($gr.Count -gt $maxCols) { $maxCols = [int]$gr.Count } }
$nf = @($grupos).Count; $wTot = [int]($maxCols * ($ancho + $margen) + $margen); $hTot = [int]($nf * ($alto + $cab + $margen) + $margen)
$hoja = New-Object Drawing.Bitmap -ArgumentList $wTot, $hTot
$g = [Drawing.Graphics]::FromImage($hoja)
$g.Clear([Drawing.Color]::FromArgb(24, 24, 28))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$fuente = New-Object Drawing.Font("Segoe UI", 10, [Drawing.FontStyle]::Bold)
$fuenteT = New-Object Drawing.Font("Segoe UI", 9)
$y = $margen
foreach ($gr in $grupos) {
  $r = $rotulos[$gr.Name]; if (-not $r) { $r = $gr.Name }
  $g.DrawString($r, $fuente, [Drawing.Brushes]::White, $margen, $y)
  $x = $margen
  foreach ($c in $gr.Group) {
    $ruta = Join-Path $Carpeta ($c.id + ".png")
    if (Test-Path $ruta) {
      $im = [Drawing.Image]::FromFile((Resolve-Path $ruta))
      # recorte centrado en la jugadora (la camara del juego la deja en el centro del fotograma)
      $cw = [int]($im.Width * 0.9); $ch = [int]($im.Height * 0.9)
      $cx = [int](($im.Width - $cw) / 2); $cy = [int](($im.Height - $ch) / 2)
      $g.DrawImage($im, (New-Object Drawing.Rectangle $x, ($y + $cab), $ancho, $alto), (New-Object Drawing.Rectangle $cx, $cy, $cw, $ch), [Drawing.GraphicsUnit]::Pixel)
      $im.Dispose()
      $g.DrawString(("t = {0:N2} s" -f [double]$c.t), $fuenteT, [Drawing.Brushes]::Gold, ($x + 4), ($y + $cab + 2))
    }
    $x += $ancho + $margen
  }
  $y += $alto + $cab + $margen
}
$g.Dispose()
$hoja.Save($Salida, [Drawing.Imaging.ImageFormat]::Png)
$hoja.Dispose()
Write-Output "hoja escrita: $Salida"
