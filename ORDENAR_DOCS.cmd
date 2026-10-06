@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
rem ============================================================================
rem  ORDENAR_DOCS.cmd  --  reparte docs\ en cuatro carpetas por tema y corrige
rem  las referencias "docs/NOMBRE" en todos los .md, .gd, .txt y .cmd del repo.
rem
rem     docs\proyecto   reglas, plan, diario, diseno futuro
rem     docs\arte       direccion de arte, assets, personaje, referencias PNG
rem     docs\sistemas   contratos y guias de sistemas de juego
rem     docs\qa         mediciones, conclusiones de pruebas, playtests
rem
rem  Se ejecuta UNA vez, desde la raiz del proyecto, con Godot cerrado.
rem  Es seguro repetirlo: lo que ya esta movido se salta.
rem  Los .png van con su .import (Godot mantiene el uid, nada se rompe).
rem ============================================================================

set "RAIZ=%~dp0"
set "DOCS=%RAIZ%docs"
if not exist "%DOCS%" (echo [ERROR] No hay carpeta docs junto a este script. & goto :fin)

tasklist /fi "imagename eq Godot*" 2>nul | find /i "Godot" >nul && (
    echo [PARADO] Cierra Godot antes de mover archivos del proyecto.
    goto :fin
)

for %%c in (proyecto arte sistemas qa) do if not exist "%DOCS%\%%c" mkdir "%DOCS%\%%c"

rem --- tabla: archivo|carpeta -------------------------------------------------
set N=0
call :add CONTEXTO.md proyecto
call :add PROPIETARIOS.md proyecto
call :add PLAN_ARREGLOS.md proyecto
call :add DIARIO.md proyecto
call :add DISENO_FUTURO.md proyecto

call :add ARTE.md arte
call :add ANIMACION.md arte
call :add PERSONAJE.md arte
call :add ASSETS_PENDIENTES.md arte
call :add ASSETS_FALTANTES.md arte
call :add EXPERIMENTOS_ESTILO.md arte
call :add PLAN_HOMOGENEIZAR_ARTE.md arte
call :add PLAN_PASTEL.md arte
call :add RETIRADA_ARTE_ANTERIOR.md arte
call :add HIERBA_OPTIMIZACION.md arte
call :add propuesta_arquitectura_arte.md arte
call :add guia_arte.png arte
call :add lamina_glifos.png arte
call :add lamina_maleza.png arte
call :add personaje_ancla.png arte
call :add plantilla_losa.png arte
call :add referencia_direcciones.png arte
call :add referencia_grimorio_grande.png arte
call :add referencia_grimorio_pasar.png arte
call :add referencia_grimorio.png arte
call :add referencia_idle_fuente.png arte
call :add referencia_personaje.png arte
call :add referencia_pluma_recorte.png arte
call :add referencia_pluma.png arte
call :add rita_fuente.png arte

call :add NUEVOS_SISTEMAS.md sistemas
call :add ESTADOS_SUELO.md sistemas
call :add ENCARGO_JUEGO_ESTADOS.md sistemas
call :add CAMBIOS_JUEGO_PENDIENTES.md sistemas
call :add IMPLEMENTAR_TECNICAS.md sistemas
call :add TECNICAS_APLICABLES.md sistemas
call :add PLAN_ACCION_TEST2.md sistemas
call :add runas.png sistemas

call :add QA_ARTE.md qa
call :add TEST2_CONCLUSIONES.md qa

rem --- mover ------------------------------------------------------------------
echo.
set MOVIDOS=0
for /l %%i in (1,1,%N%) do (
    set "F=!A%%i!" & set "C=!B%%i!"
    if exist "%DOCS%\!F!" (
        move /y "%DOCS%\!F!" "%DOCS%\!C!\" >nul && (echo   docs\!F!  ->  docs\!C!\ & set /a MOVIDOS+=1)
        if exist "%DOCS%\!F!.import" move /y "%DOCS%\!F!.import" "%DOCS%\!C!\" >nul
    )
)
if exist "%DOCS%\Playtests" (
    if not exist "%DOCS%\qa\playtests" (
        move /y "%DOCS%\Playtests" "%DOCS%\qa\playtests" >nul && (echo   docs\Playtests  ->  docs\qa\playtests & set /a MOVIDOS+=1)
    )
)
echo.
echo Movidos: %MOVIDOS%

rem --- corregir referencias docs/NOMBRE -> docs/carpeta/NOMBRE ------------------
rem Escribe la tabla a un archivo temporal y deja que PowerShell la aplique a
rem todos los .md/.gd/.txt/.cmd del repo (fuera de .godot, .git y pipeline_output).
set "TABLA=%TEMP%\ordenar_docs_tabla.txt"
>"%TABLA%" (
    for /l %%i in (1,1,%N%) do echo !A%%i!^|!B%%i!
    echo Playtests^|qa/playtests
)
setlocal DisableDelayedExpansion
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$raiz='%RAIZ%'.TrimEnd('\');" ^
  "$tabla=Get-Content -LiteralPath '%TABLA%' | Where-Object { $_ -match '\|' } | ForEach-Object { $p=$_.Split('|'); @{ n=$p[0]; c=$p[1] } };" ^
  "$utf8=New-Object System.Text.UTF8Encoding($false); $tocados=0;" ^
  "Get-ChildItem -LiteralPath $raiz -Recurse -File -Include *.md,*.gd,*.txt,*.cmd | Where-Object { $_.FullName -notmatch '\\(\.godot|\.git|pipeline_output|_to_delete)(\\|$)' } | ForEach-Object {" ^
  "  $t=[IO.File]::ReadAllText($_.FullName); $o=$t;" ^
  "  foreach($e in $tabla){ if($e.n -eq 'Playtests'){ $t=$t -replace 'docs([/\\])Playtests','docs$1qa$1playtests' } else { $nn=[regex]::Escape($e.n); $t=$t -replace ('docs([/\\])'+$nn+'(?![\w.])'),('docs$1'+$e.c+'$1'+$e.n) } }" ^
  "  if($t -ne $o){ [IO.File]::WriteAllText($_.FullName,$t,$utf8); $tocados++; Write-Host ('  referencias: '+$_.FullName.Substring($raiz.Length+1)) }" ^
  "}; Write-Host ('Archivos con referencias corregidas: '+$tocados)"
endlocal
del "%TABLA%" 2>nul

echo.
echo [OK] docs\ ordenado. Abre Godot para que reimporte las imagenes movidas.
echo      Actualiza en los dos proyectos de Claude: docs/PROPIETARIOS.md -> docs/proyecto/PROPIETARIOS.md,
echo      docs/CONTEXTO.md -> docs/proyecto/CONTEXTO.md, docs/DIARIO.md -> docs/proyecto/DIARIO.md
goto :fin

:add
set /a N+=1
set "A%N%=%~1"
set "B%N%=%~2"
goto :eof

:fin
echo.
pause
endlocal
