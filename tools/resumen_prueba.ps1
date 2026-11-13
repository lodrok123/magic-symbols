# resumen_prueba.ps1 - lo llaman tools\pruebas.cmd y tools\prueba_una.cmd (Juego). Entiende la salida de las pruebas de Godot y saca el veredicto.
#
# Que reconoce como "resultado" (N = fallos impresos; ver regla 2):
#     FALLOS: N                         FALLOS N                      FALLOS <nombre>: N
#     OK: N fallos                      RESULTADO <nombre>: N fallos      FALLO: N fallos (prueba_vfx_v2)
#   (da igual lo que haya antes en la linea: "RESULTADO x: 715 combinaciones - FALLOS: 0" vale). Las lineas sueltas "OK ..." / "FALLO ..." / "AVISO ..." de cada comprobacion no cuentan como resultado.
# Que es RUIDO (no es de la prueba; no cuenta como fallo ni se ensena): "resources still in use", "RID allocations ... leaked", "Pages in use exist", WASAPI y
#   "Lambda capture ... was freed". Las de Lambda se cuentan aparte como AVISOS (columna "avisos"); el resto, ni eso.
#
# REGLAS DEL RECUENTO (12/11/2026; antes un "FALLOS: 0" final tapaba lineas FALLO sueltas, un total parcial, un SCRIPT ERROR, un codigo de salida 1 o un cuelgue):
#   0. Cada bateria escribe la salida de cada prueba en su propio %TEMP%\prueba_salida_<PID>_<prueba>.txt (y la borra al leerla). Antes era un unico
#      %TEMP%\prueba_salida.txt para todas: dos baterias a la vez (dos agentes, o Pablo y un agente) se pisaban y una prueba se resumia con la salida de OTRA
#      (la causa del 'FALLOS: 0' falso de prueba_campo_viento con 3 FALLO reales).
#   1. Se cuentan las lineas FALLO sueltas ("FALLO x", "  FALLO x", "FALLO: x"; no "FALLO: N fallos", que es un resultado). Ninguna linea de ruido se las come:
#      solo se saltan como continuacion de un ruido las lineas "   at: ...", "GDScript backtrace" y "[N] ...".
#   2. N impreso = el MAYOR de todas las lineas de resultado (no la ultima): un "FALLOS: 2" parcial no lo borra un "FALLOS: 0" posterior.
#   3. Fallos de la prueba = max(N impreso, lineas FALLO contadas). Una linea FALLO o un "FALLOS: N>0" NUNCA da 0.
#   4. Si N impreso no coincide con las lineas FALLO contadas, se avisa: "DESCUADRE: x lineas FALLO, total impreso y". No cambia el veredicto por si solo.
#   5. Errores de codigo (SCRIPT ERROR, Parse Error, Compile Error, Failed to load script) o un crash de Godot ("Program crashed", CrashHandler, signal 11):
#      la prueba NO puede salir BIEN. Si no hubo otros fallos, cuenta 1 fallo y el veredicto es MAL (ERROR DE CODIGO).
#   6. Codigo de salida de Godot distinto de 0 con 0 fallos (las pruebas hacen quit(1) si fallan): MAL (SALE CON n), 1 fallo. Solo en el modo "todas".
#   7. Cuelgue (parada por tiempo) o ninguna linea de resultado: SIN RESULTADO, aunque haya un "FALLOS: 0" impreso antes de colgarse. Si ademas hubo lineas FALLO
#      o un total > 0, es MAL con esos fallos (nunca 0).
#   8. Una prueba que no puede correr aqui (p. ej. necesita ventana) imprime "SALTADA: <motivo>" y sale con quit(0): veredicto SALTADA, 0 fallos, no es MAL.
#      Solo vale si ademas no hubo lineas FALLO, total > 0, errores de codigo, crash, cuelgue ni codigo de salida distinto de 0.
# Veredicto: BIEN (0 fallos, sin errores de codigo, salida 0) / MAL (fallos > 0, o regla 5/6) / SIN RESULTADO (regla 7) / SALTADA (regla 8).
#   SIN RESULTADO no suma al TOTAL: se cuenta aparte.
# pruebas.cmd sale con 1 si alguna prueba salio MAL o SIN RESULTADO (y con 0 si todas BIEN o SALTADA).
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

$errorCodigo = 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script'
$crash = 'Program crashed|CrashHandler|signal 11|Segmentation fault'
$continuacion = '^\s+(at:|GDScript backtrace|\[\d+\])'

# Devuelve: Impreso (el MAYOR N de las lineas de resultado, o $null), LineasFallo (lineas FALLO sueltas), Avisos, Medidas (lineas "AVISO"),
# Errores (errores de codigo), Crash, Mostrar (lineas que se ensenan: FALLO y errores de codigo, sin ruido)
function Analizar([string[]]$lineas) {
    $r = [ordered]@{ Impreso = $null; LineasFallo = 0; Saltada = $null; Avisos = 0; Medidas = 0; Errores = 0; Crash = $false; Mostrar = New-Object System.Collections.Generic.List[string] }
    $saltando = $false
    $mostrado = $false
    foreach ($l in $lineas) {
        if ($l -eq $null) { continue }
        # las lineas de continuacion de un mensaje de Godot ("   at: ...", "GDScript backtrace", "[0] ...") siguen la suerte de su mensaje (regla 1: solo esas)
        if ($saltando -and $l -match $continuacion) { continue }
        $saltando = $false
        if ($l -match $lambda) { $r.Avisos++; $saltando = $true; continue }
        $esRuido = $false
        foreach ($p in $ruido) { if ($l -match $p) { $esRuido = $true; break } }
        if ($esRuido) { $saltando = $true; continue }
        $t = $l.TrimStart()
        if ($t -cmatch '^FALLO:(?!\s*\d+\s+fallos)') { $r.LineasFallo++; $r.Mostrar.Add($l); $mostrado = $true; continue }   # "FALLO: <comprobacion>" suelta (vfx_v2); "FALLO: N fallos" es el resultado
        if ($t -match '^(?i:ok|fallo|aviso)\s') {       # una comprobacion suelta ("  ok  ...", "  FALLO  ...", "AVISO ..."): no es un resultado
            if ($t -cmatch '^FALLO\s') { $r.LineasFallo++; $r.Mostrar.Add($l); $mostrado = $true }
            if ($t -cmatch '^AVISO') { $r.Medidas++ }
            continue
        }
        foreach ($f in $formas) {
            $m = [regex]::Match($l, $f)
            if ($m.Success) {
                $n = [int]$m.Groups[1].Value
                if ($r.Impreso -eq $null -or $n -gt $r.Impreso) { $r.Impreso = $n }   # regla 2
                break
            }
        }
        if ($t -cmatch '^SALTADA:') { $r.Saltada = $t; $r.Mostrar.Add($l); continue }   # regla 8
        if ($l -match $crash) { $r.Crash = $true; $r.Mostrar.Add($l); $mostrado = $true }
        elseif ($l -match $errorCodigo) { $r.Errores++; $r.Mostrar.Add($l); $mostrado = $true }
        elseif ($l -match '^ERROR:') { $r.Mostrar.Add($l); $mostrado = $true }
        elseif ($l -match '^\s+at:' -and $mostrado) { $r.Mostrar.Add($l) }
        else { $mostrado = $false }
    }
    return $r
}

# Aplica las reglas 3-7. $colgada: se paro por tiempo. $codigo: codigo de salida de Godot ($null si no se sabe).
# Devuelve: Fallos (int, o $null si SIN RESULTADO sin fallos vistos), Veredicto, Notas (lista de textos que se ensenan)
function Veredicto($r, [bool]$colgada = $false, $codigo = $null) {
    $notas = New-Object System.Collections.Generic.List[string]
    $vistos = $r.LineasFallo
    if ($r.Impreso -ne $null -and $r.Impreso -gt $vistos) { $vistos = $r.Impreso }                     # regla 3
    if ($r.Impreso -ne $null -and $r.Impreso -ne $r.LineasFallo) {                                         # regla 4
        $notas.Add(("DESCUADRE: {0} lineas FALLO, total impreso {1}" -f $r.LineasFallo, $r.Impreso))
    }
    # regla 8: SALTADA limpia (sin fallos, sin errores de codigo, sin cuelgue, salida 0)
    if ($r.Saltada -ne $null -and $vistos -eq 0 -and $r.Errores -eq 0 -and -not $r.Crash -and -not $colgada -and ($codigo -eq $null -or $codigo -eq 0)) {
        return [pscustomobject]@{ Fallos = 0; Veredicto = 'SALTADA'; Notas = $notas }
    }
    if ($colgada) { $notas.Add('SE CUELGA: parada por tiempo') }
    if ($r.Crash) { $notas.Add('CRASH de Godot') }
    if ($colgada -or $r.Crash -or $r.Impreso -eq $null) {                                                  # regla 7 (y crash)
        if ($r.Impreso -eq $null -and -not $colgada -and -not $r.Crash) { $notas.Add('ninguna linea de resultado') }
        if ($vistos -gt 0) { return [pscustomobject]@{ Fallos = $vistos; Veredicto = 'MAL (SIN FINAL)'; Notas = $notas } }
        return [pscustomobject]@{ Fallos = $null; Veredicto = 'SIN RESULTADO'; Notas = $notas }
    }
    if ($vistos -gt 0) {
        $v = 'MAL'
        if ($r.Errores -gt 0) { $v = 'MAL (+ERROR DE CODIGO)' }
        return [pscustomobject]@{ Fallos = $vistos; Veredicto = $v; Notas = $notas }
    }
    if ($r.Errores -gt 0) {                                                                                # regla 5
        $notas.Add(("{0} errores de codigo con 0 fallos: cuenta como 1 fallo" -f $r.Errores))
        return [pscustomobject]@{ Fallos = 1; Veredicto = 'MAL (ERROR DE CODIGO)'; Notas = $notas }
    }
    if ($codigo -ne $null -and $codigo -ne 0) {                                                            # regla 6
        $notas.Add(("Godot sale con codigo {0} pese a 0 fallos: cuenta como 1 fallo" -f $codigo))
        return [pscustomobject]@{ Fallos = 1; Veredicto = ("MAL (SALE CON {0})" -f $codigo); Notas = $notas }
    }
    return [pscustomobject]@{ Fallos = 0; Veredicto = 'BIEN'; Notas = $notas }
}

if ($Una) {
    $lineas = Get-Content -LiteralPath $Archivo -Encoding UTF8
    $r = Analizar $lineas
    $res = Veredicto $r
    $linea = '=' * 64
    Write-Output $linea
    $res.Notas | ForEach-Object { Write-Output $_ }
    if ($res.Veredicto -eq 'SIN RESULTADO') {
        Write-Output 'RESULTADO: SIN RESULTADO - la prueba no llego al final. Ultimas lineas de la salida:'
        $lineas | Select-Object -Last 15 | ForEach-Object { Write-Output $_ }
    }
    elseif ($res.Veredicto -eq 'BIEN') { Write-Output ("RESULTADO: BIEN - 0 fallos, 0 errores de codigo, {0} avisos de lambda, {1} medidas (los avisos y las medidas no son errores)" -f $r.Avisos, $r.Medidas) }
    else { Write-Output ("RESULTADO: {0} - {1} fallos, {2} errores de codigo, {3} avisos de lambda, {4} medidas" -f $res.Veredicto, $res.Fallos, $r.Errores, $r.Avisos, $r.Medidas) }
    Write-Output $linea
    if ($res.Veredicto -eq 'BIEN' -or $res.Veredicto -eq 'SALTADA') { exit 0 } else { exit 1 }
}

# ---- modo "todas": recorre herramientas\prueba_*.gd y herramientas\escenario_*.gd ----
Set-Location (Join-Path $PSScriptRoot '..')
$Patron = @($Patron | ForEach-Object { $_ -split '[,; ]+' } | Where-Object { $_ -ne '' })      # desde el .cmd llega todo en un solo texto
$todas = @(Get-ChildItem -LiteralPath 'herramientas' -Filter 'prueba_*.gd' | Sort-Object Name) +
         @(Get-ChildItem -LiteralPath 'herramientas' -Filter 'escenario_*.gd' | Where-Object { $_.Name -ne 'escenario_base.gd' } | Sort-Object Name)
# 29/10 (H0 del PLAN_SISTEMA_HECHIZOS): alias de suite. `solo hechizos` = la lista nombrada de las pruebas del sistema de hechizos (nombres completos, coincidencia exacta de BaseName).
$suiteHechizos = @('prueba_hechizo', 'prueba_hechizo_golden', 'prueba_eventos_hechizo', 'prueba_hechizo_vivo', 'prueba_ejecucion_combinaciones', 'prueba_dano_tinta', 'prueba_campos_ejecutados',
    'prueba_barrido_hechizos', 'prueba_materia_v2', 'prueba_receta_v2', 'prueba_haz', 'prueba_pulso', 'prueba_reacciones', 'prueba_colisiones_forma', 'prueba_prevision_hechizo', 'prueba_proyectil_solidez', 'prueba_tinta',
    'prueba_en_punto_proyectil', 'prueba_trayectorias')
if ($Patron.Count -eq 1 -and $Patron[0] -eq 'hechizos') {
    $todas = @($todas | Where-Object { $suiteHechizos -contains $_.BaseName })
    if ($todas.Count -eq 0) { Write-Output 'Ninguna prueba de la suite hechizos'; exit 2 }
    Write-Output ("Suite hechizos (" + $todas.Count + " de " + $suiteHechizos.Count + "): " + (($todas | ForEach-Object { $_.BaseName }) -join ', '))
    $Patron = @()
}
elseif ($Patron.Count -gt 0) {
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
    # 13/11/2026: la CABECERA entera (las lineas de comentario del principio, hasta 40), no solo las 10 primeras: pasar_pagina, mochila_sensacion, ping_debil,
    # destello_elemento, muerte_elemento, mapa_abierto y trampas_pared lo piden en las lineas 11-16 y en la bateria corrian sin el (y solo ahi fallaban).
    $sigue = $true
    $cabecera = (Get-Content -LiteralPath $f.FullName -TotalCount 40 -Encoding UTF8 | ForEach-Object { if ($sigue -and $_ -notmatch '^\s*(#|extends\b|class_name\b|@tool\b|$)') { $sigue = $false }; if ($sigue) { $_ } }) | Out-String
    if ($nombre -like 'escenario_*' -or $cabecera.Contains('--fixed-fps 30') -or (Select-String -LiteralPath $f.FullName -Pattern 'extends "res://herramientas/escenario_base.gd"' -SimpleMatch -Quiet)) { $opc += @('--fixed-fps', '30') }
    $opc += @('--path', '.', '--script', "res://herramientas/$($f.Name)")
    # 12/11/2026: un archivo PROPIO por bateria y prueba. Antes era %TEMP%\prueba_salida.txt para todas: dos baterias a la vez (dos agentes, o Pablo y
    # un agente) se pisaban la salida y una prueba se resumia con la salida de OTRA (asi salio FALLOS: 0 en prueba_campo_viento con 3 FALLO reales).
    $out = Join-Path $tmp ("prueba_salida_{0}_{1}.txt" -f $PID, $nombre)
    $err = Join-Path $tmp ("prueba_error_{0}_{1}.txt" -f $PID, $nombre)
    Remove-Item -LiteralPath $out, $err -ErrorAction SilentlyContinue
    Write-Output ''
    Write-Output "===== $nombre ====="
    $p = Start-Process -FilePath $Godot -ArgumentList $opc -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $null = $p.Handle      # sin tocar el Handle antes de que acabe, ExitCode sale vacio
    $colgada = $false
    $codigo = $null
    if (-not $p.WaitForExit($TimeoutS * 1000)) { $colgada = $true; try { $p.Kill(); $null = $p.WaitForExit(10000) } catch {} ; Write-Output "(se cuelga: parada tras $TimeoutS s)" }
    else { $p.WaitForExit(); try { $codigo = $p.ExitCode } catch { $codigo = $null } }
    $lineas = @()
    if (Test-Path -LiteralPath $out) { $lineas += Get-Content -LiteralPath $out -Encoding UTF8 }
    if (Test-Path -LiteralPath $err) { $lineas += Get-Content -LiteralPath $err -Encoding UTF8 }
    Remove-Item -LiteralPath $out, $err -ErrorAction SilentlyContinue
    $r = Analizar $lineas
    $res = Veredicto $r $colgada $codigo
    $r.Mostrar | ForEach-Object { Write-Output $_ }
    $res.Notas | ForEach-Object { Write-Output $_ }
    if ($res.Fallos -eq $null) {
        Write-Output 'SIN RESULTADO: la prueba no llego al final. Ultimas lineas:'
        $lineas | Select-Object -Last 12 | ForEach-Object { Write-Output $_ }
    } else { Write-Output ("FALLOS: {0}" -f $res.Fallos) }
    $filas += [pscustomobject]@{ Prueba = $nombre; Fallos = $res.Fallos; Avisos = ($r.Avisos + $r.Medidas); Veredicto = $res.Veredicto; Errores = $r.Errores; Descuadre = ($r.Impreso -ne $null -and $r.Impreso -ne $r.LineasFallo) }
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
$mal = @($filas | Where-Object { $_.Veredicto -like 'MAL*' })
$conErr = @($filas | Where-Object { $_.Errores -gt 0 })
$desc = @($filas | Where-Object { $_.Descuadre })
$salt = @($filas | Where-Object { $_.Veredicto -eq 'SALTADA' })
Write-Output ('=' * 64)
Write-Output ("TOTAL DE FALLOS REALES: {0}   ({1} pruebas, {2} MAL, {3} SIN RESULTADO)" -f $total, $filas.Count, $mal.Count, $sin.Count)
if ($sin.Count -gt 0) { Write-Output ("SIN RESULTADO (no suman al total): " + (($sin | ForEach-Object { $_.Prueba }) -join ', ')) }
if ($conErr.Count -gt 0) { Write-Output ("Con SCRIPT ERROR (cuentan como fallo aunque acaben en 0 fallos): " + (($conErr | ForEach-Object { "$($_.Prueba) x$($_.Errores)" }) -join ', ')) }
if ($salt.Count -gt 0) { Write-Output ("SALTADAS (no corren aqui; su motivo sale arriba): " + (($salt | ForEach-Object { $_.Prueba }) -join ', ')) }
if ($desc.Count -gt 0) { Write-Output ("DESCUADRE (lineas FALLO contadas distintas del total impreso; se toma el mayor): " + (($desc | ForEach-Object { $_.Prueba }) -join ', ')) }
Write-Output "(los avisos = 'Lambda capture ... was freed' + lineas AVISO de medidas; no son fallos)"
Write-Output ('=' * 64)
if ($mal.Count -gt 0 -or $sin.Count -gt 0) { exit 1 }
exit 0
