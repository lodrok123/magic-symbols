@echo off
rem GENERAR_ESCENAS_PIEZAS.cmd - vuelve a hornear arte\piezas\<id>.tscn de las piezas indicadas con el .glb actual de arte\meshy\piezas\.
rem Por que: los niveles usan esas escenas (la malla va dentro); cambiar el .glb solo no cambia los niveles. Lo escribe el Pipeline.
rem Uso, desde cualquier sitio:   arte\meshy\GENERAR_ESCENAS_PIEZAS.cmd arbol_redondo pino arbusto_otono
rem (Sin ids: lee la lista de arte\meshy\ULTIMAS_INSTALADAS.txt, que deja recibir_assets.py al instalar.)
rem OJO: sobrescribe esas escenas; no las uses con una pieza que Pablo haya retocado a mano (el cofre lleva su controlador y animacion).
setlocal EnableDelayedExpansion
cd /d "%~dp0..\.."
set GODOT=
if exist tools\godot_local.txt set /p GODOT=<tools\godot_local.txt
set "GODOT=!GODOT:"=!"
if not exist "!GODOT!" if exist tools\Godot_v4.7.2-stable_win64.exe (
  set "GODOT=%CD%\tools\Godot_v4.7.2-stable_win64.exe"
  echo !GODOT!>tools\godot_local.txt
)
if not exist "!GODOT!" (
  echo No encuentro Godot. Escribe su ruta en tools\godot_local.txt
  pause
  exit /b 2
)
set IDS=%*
if "%IDS%"=="" if exist arte\meshy\ULTIMAS_INSTALADAS.txt (
  for /f "usebackq delims=" %%L in ("arte\meshy\ULTIMAS_INSTALADAS.txt") do set IDS=!IDS! %%L
)
if "%IDS%"=="" (
  echo No hay ids. Ejemplo: arte\meshy\GENERAR_ESCENAS_PIEZAS.cmd arbol_redondo pino
  pause
  exit /b 2
)
echo Importando recursos nuevos (puede tardar un minuto)...
"!GODOT!" --headless --path . --import > salida_importar.txt 2>&1
echo Horneando: %IDS%
"!GODOT!" --headless --path . --script res://herramientas/generar_piezas_ids.gd -- %IDS%
echo.
echo Hecho. Abre Godot para que reimporte las escenas y revisa un nivel.
pause
