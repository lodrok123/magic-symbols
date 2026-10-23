# resumen_prueba.ps1 - lo llaman tools\pruebas.cmd y tools\prueba_una.cmd (Juego). Entiende la salida de las pruebas de Godot y saca el veredicto.
#
# Que reconoce como "resultado" (la ULTIMA linea que case; N = fallos de la prueba):
#     FALLOS: N                         FALLOS N                      FALLOS <nombre>: N
#     OK: N fallos                      RESULTADO <nombre>: N fallos      FALLO: N fallos (prueba_vfx_v2)
#   (da igual lo que haya antes en la linea: "RESULTADO x: 715 combinaciones - FALLOS: 0" vale). Las lineas sueltas "OK ..." / "FALLO ..." / "AVISO ..." de cada comprobacion no cuentan como resultado.
# Que es RUIDO (no es de la prueba; no cuenta como fallo ni se ensena): "resources still in use", "RID allocations ... leaked", "Pages in use exist", WASAPI y
#   "Lambda capture ... was freed". Las de Lambda se cuentan aparte como AVISOS (columna "avisos"); el resto, ni eso.
# Veredicto: BIEN (N = 0) / MAL (N > 0) / SIN RESULTADO (ninguna linea de resultado: no compilo o se colgo). SIN RESULTADO no suma al TOTAL de fallos: se cuenta aparte.
#
# Modos:
#   -Archivo <salida.txt> -Una              veredicto de UNA salida ya guardada (lo usa prueba_una.cmd)
#   -Godot <exe> [-Patron a,b]              corre todas las pruebas (o las que contengan algun patron) y saca la tabla (lo usa pruebas.cmd)
param(
    [string]$Godot = "",
    [string[]]$Patron = @(),
    [string]$Archivo = "",
    [switch]$Una,
    [int]$TimeoutS = 1800
)

$formas = @(
    '(?i)\bFALLOS:\s*(\d+)',
    '(?i)\bFALLOS\s+(\d+)\b',
    '(?i)\bFALLOS\s+[^\s:]+:\s*(\d+)',
    '(?i)\bOK:\s*(\d+)\s+fallos\b',
    '(?i)\bRESULTADO\s+[^\s:]+:\s*(\d+)\s+fallos\b',
    '(?i)^\s*FALLO:\s*(\d+)\s+fallos\b'
)
$ruido = @('resources still in use', 'RID allocations.*leaked', 'Pages in use exist', 'WASAPI')
$lambda = 'Lambda capture.*was freed'

# Devuelve: Fallos (int o $null), Avisos, Medidas (lineas "AVISO"), Errores (lineas SCRIPT ERROR), Mostrar (lineas que se ensenan: FALLO y errores de codigo, sin ruido)
function Analizar([string[]]$lineas) {
    $r = [ordered]@{ Fallos = $null; Avisos = 0; Medidas = 0; Errores = 0; Mostrar = New-Object System.Collections.Generic.List[string] }
    $saltando = $false
    $mostrado = $false
    foreach ($l in $lineas) {
        if ($l -eq $null) { continue }
        # las lineas de continuacion de un mensaje de Godot ("   at: ...", "GDScript backtrace", "[0] ...") empiezan con espacios: siguen la suerte de su mensaje
        if ($l -match '^\s+\S' -and $saltando) { continue }
        $saltando = $false
        if ($l -match $lambda) { $r.Avisos++; $saltando = $true; continue }
        $esRuido = $false
        foreach ($p in $ruido) { if ($l -match $p) { $esRuido = $true; break } }
        if ($esRuido) { $saltando = $true; continue }
        $t = $l.TrimStart()
        if ($t -cmatch '^FALLO:(?!\s*\d+\s+fallos)') { $r.Mostrar.Add($l); $mostrado = $true; continue }   # "FALLO: <comprobacion>" suelta (vfx_v2); "FALLO: N fallos" es el resultado
        if ($t -match '^(?i:ok|fallo|aviso)\s') {       # una comprobacion suelta ("  ok  ...", "  FALLO  ...", "AVISO ..."): no es un resultado
            if ($t -cmatch '^FALLO\s') { $r.Mostrar.Add($l); $mostrado = $true }
            if ($t -cmatch '^AVISO') { $r.Medidas++ }
            continue
        }
        foreach ($f in $formas) {
            $m = [regex]::Match($l, $f)
            if ($m.Success) { $r.Fallos = [int]$m.Groups[1].Value; break }
        }
        if ($l -match 'SCRIPT ERROR|Parse Error|Failed to load|Compile Error') { $r.Errores++; $r.Mostrar.Add($l); $mostrado = $true }
        elseif ($l -match '^ERROR:') { $r.Mostrar.Add($l); $mostrado = $true }
        elseif ($l -match '^\s+at:' -and $mostrado) { $r.Mostrar.Add($l) }
        else { $mostrado = $false }
    }
    return $r
}

function Veredicto($r) {
    if ($r.Fallos -eq $null) { return 'SIN RESULTADO' }
    if ($r.Fallos -gt 0) { return 'MAL' }
    return 'BIEN'
}

if ($Una) {
    $lineas = Get-Content -LiteralPath $Archivo -Encoding UTF8
    $r = Analizar $lineas
    $v = Veredicto $r
    $linea = '=' * 64
    Write-Output $linea
    switch ($v) {
        'SIN RESULTADO' {
            Write-Output 'RESULTADO: SIN RESULTADO - la prueba no llego al final. Ultimas lineas de la salida:'
            $lineas | Select-Object -Last 15 | ForEach-Object { Write-Output $_ }
        }
        'MAL' { Write-Output ("RESULTADO: MAL - {0} fallos, {1} errores de codigo, {2} avisos de lambda, {3} medidas" -f $r.Fallos, $r.Errores, $r.Avisos, $r.Medidas) }
        default {
            if ($r.Errores -eq 0) { Write-Output ("RESULTADO: BIEN - 0 fallos, 0 errores de codigo, {0} avisos de lambda, {1} medidas (los avisos y las medidas no son errores)" -f $r.Avisos, $r.Medidas) }
            else { Write-Output ("RESULTADO: PASA CON ERRORES DE CODIGO - 0 fallos pero {0} SCRIPT ERROR (mira las lineas 'at:' de arriba)" -f $r.Errores) }
        }
    }
    Write-Output $linea
    if ($v -eq 'BIEN') { exit 0 } else { exit 1 }
}

# ---- modo "todas": recorre herramientas\prueba_*.gd y herramientas\escenario_*.gd ----
Set-Location (Join-Path $PSScriptRoot '..')
$Patron = @($Patron | ForEach-Object { $_ -split '[,; ]+' } | Where-Object { $_ -ne '' })      # desde el .cmd llega todo en un solo texto
$todas = @(Get-ChildItem -LiteralPath 'herramientas' -Filter 'prueba_*.gd' | Sort-Object Name) +
         @(Get-ChildItem -LiteralPath 'herramientas' -Filter 'escenario_*.gd' | Where-Object { $_.Name -ne 'escenario_base.gd' } | Sort-Object Name)
if ($Patron.Count -gt 0) {
    $todas = @($todas | Where-Object { $n = $_.BaseName; ($Patron | Where-Object { $_ -ne '' -and $n -like "*$_*" }).Count -gt 0 })
    if ($todas.Count -eq 0) { Write-Output ("Ninguna prueba casa con: " + ($Patron -join ', ')); exit 2 }
    Write-Output ("Subconjunto (" + $todas.Count + "): " + (($todas | ForEach-Object { $_.BaseName }) -join ', '))
}
$tmp = [IO.Path]::GetTempPath()
$filas = @()
foreach ($f in $todas) {
    $nombre = $f.BaseName
    $opc = @('--headless')
    # los escenarios cargan la escena entera: 30 fps fijos, que es lo que pide el plan. Tambien las pruebas que EXTIENDEN escenario_base (prueba_cast_points, prueba_nado_desactivado):
    # su cabecera pide --fixed-fps 30 y sin el miden fotogramas de mas (Pipeline, 20/10, con permiso de Pablo)
    # 23/10: y las pruebas cuya cabecera (las 10 primeras lineas) pide «--fixed-fps 30»: miden tiempos (quemado, disolver, cortes, burbujas) y sin el fallaban solo en la bateria.
    $cabecera = Get-Content -LiteralPath $f.FullName -TotalCount 10 -Encoding UTF8 | Out-String
    if ($nombre -like 'escenario_*' -or $cabecera.Contains('--fixed-fps 30') -or (Select-String -LiteralPath $f.FullName -Pattern 'extends "res://herramientas/escenario_base.gd"' -SimpleMatch -Quiet)) { $opc += @('--fixed-fps', '30') }
    $opc += @('--path', '.', '--script', "res://herramientas/$($f.Name)")
    $out = Join-Path $tmp 'prueba_salida.txt'
    $err = Join-Path $tmp 'prueba_error.txt'
    Remove-Item -LiteralPath $out, $err -ErrorAction SilentlyContinue
    Write-Output ''
    Write-Output "===== $nombre ====="
    $p = Start-Process -FilePath $Godot -ArgumentList $opc -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    if (-not $p.WaitForExit($TimeoutS * 1000)) { try { $p.Kill() } catch {} ; Write-Output "(se cuelga: parada tras $TimeoutS s)" }
    $lineas = @()
    if (Test-Path -LiteralPath $out) { $lineas += Get-Content -LiteralPath $out -Encoding UTF8 }
    if (Test-Path -LiteralPath $err) { $lineas += Get-Content -LiteralPath $err -Encoding UTF8 }
    $r = Analizar $lineas
    $v = Veredicto $r
    $r.Mostrar | ForEach-Object { Write-Output $_ }
    if ($v -eq 'SIN RESULTADO') {
        Write-Output 'SIN RESULTADO: la prueba no llego al final. Ultimas lineas:'
        $lineas | Select-Object -Last 12 | ForEach-Object { Write-Output $_ }
    } else { Write-Output ("FALLOS: {0}" -f $r.Fallos) }
    $filas += [pscustomobject]@{ Prueba = $nombre; Fallos = $r.Fallos; Avisos = ($r.Avisos + $r.Medidas); Veredicto = $v; Errores = $r.Errores }
}

Write-Output ''
Write-Output ('=' * 64)
$ancho = [Math]::Max(6, ($filas | ForEach-Object { $_.Prueba.Length } | Measure-Object -Maximum).Maximum)
Write-Output (("{0,-$ancho}  {1,6}  {2,6}  {3}" -f 'prueba', 'fallos', 'avisos', 'veredicto'))
Write-Output (("{0,-$ancho}  {1,6}  {2,6}  {3}" -f ('-' * $ancho), '------', '------', '---------------'))
foreach ($x in $filas) {
    $fa = if ($x.Fallos -eq $null) { '-' } else { "$($x.Fallos)" }
    Write-Output (("{0,-$ancho}  {1,6}  {2,6}  {3}" -f $x.Prueba, $fa, $x.Avisos, $x.Veredicto))
}
$total = ($filas | Where-Object { $_.Fallos -ne $null } | Measure-Object -Property Fallos -Sum).Sum
if ($total -eq $null) { $total = 0 }
$sin = @($filas | Where-Object { $_.Veredicto -eq 'SIN RESULTADO' })
$mal = @($filas | Where-Object { $_.Veredicto -eq 'MAL' })
$conErr = @($filas | Where-Object { $_.Errores -gt 0 })
Write-Output ('=' * 64)
Write-Output ("TOTAL DE FALLOS REALES: {0}   ({1} pruebas, {2} MAL, {3} SIN RESULTADO)" -f $total, $filas.Count, $mal.Count, $sin.Count)
if ($sin.Count -gt 0) { Write-Output ("SIN RESULTADO (no suman al total): " + (($sin | ForEach-Object { $_.Prueba }) -join ', ')) }
if ($conErr.Count -gt 0) { Write-Output ("Con SCRIPT ERROR (el codigo peto aunque acabe en 0 fallos): " + (($conErr | ForEach-Object { "$($_.Prueba) x$($_.Errores)" }) -join ', ')) }
Write-Output "(los avisos = 'Lambda capture ... was freed' + lineas AVISO de medidas; no son fallos)"
Write-Output ('=' * 64)
