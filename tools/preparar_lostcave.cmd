@echo off
rem preparar_lostcave.cmd - saca del zip de Cosmos el pack "Stylized Lost Cave" y genera arte\lostcave\piezas\lost_*.tscn (24/11/2026).
rem Uso, desde la raiz del repo (o doble clic):   tools\preparar_lostcave.cmd   [ruta al zip]
rem Sin ruta usa %USERPROFILE%\Downloads\StylizedLostCaveForward.zip. Nada de lo que genera va a git (ver arte\lostcave\LEEME.md).
rem Donde esta Godot: tools\godot_local.txt (una linea con la ruta al .exe) o el Godot de tools\.
setlocal EnableDelayedExpansion
cd /d "%~dp0.."
set "ZIP=%~1"
if "%ZIP%"=="" set "ZIP=%USERPROFILE%\Downloads\StylizedLostCaveForward.zip"
if not exist "%ZIP%" (
  echo No encuentro el zip: "%ZIP%"
  echo Bajalo de Cosmos ^(Stylized Lost Cave, version Godot^) y pasa su ruta:  tools\preparar_lostcave.cmd "C:\ruta\StylizedLostCaveForward.zip"
  pause
  exit /b 1
)
set GODOT=
if exist tools\godot_local.txt set /p GODOT=<tools\godot_local.txt
if defined GODOT if exist "!GODOT!" goto :correr
for %%F in (tools\Godot*.exe) do echo %%F | findstr /i /v "console" >nul && if not defined GODOT set "GODOT=%%~fF"
if not defined GODOT (
  echo No encuentro Godot. Escribe su ruta en tools\godot_local.txt y vuelve a ejecutar.
  pause
  exit /b 1
)
:correr
echo [1/7] Sacar del zip (texturas originales, recetas de material, mallas limpias)
python tools\preparar_lostcave.py "%ZIP%" || goto :fallo
echo [2/7] Importar mallas
"!GODOT!" --headless --path . --import >nul 2>&1
echo [3/7] Texturas a 1K y roca horneada
"!GODOT!" --headless --path . --script res://herramientas/generar_piezas_lostcave.gd -- --texturas || goto :fallo
echo [4/7] Importar texturas (dos pasadas: a veces la primera no recoge los PNG recien escritos)
"!GODOT!" --headless --path . --import >nul 2>&1
"!GODOT!" --headless --path . --import >nul 2>&1
echo [5/7] Ajustes 3D de las texturas (VRAM, mipmaps, normales)
"!GODOT!" --headless --path . --script res://herramientas/generar_piezas_lostcave.gd -- --ajustes || goto :fallo
echo [6/7] Reimportar
"!GODOT!" --headless --path . --import >nul 2>&1
echo [7/7] Materiales y piezas
"!GODOT!" --headless --path . --script res://herramientas/generar_piezas_lostcave.gd -- --piezas || goto :fallo
echo.
echo Listo. Para verlas:  "!GODOT!" --path . res://laboratorios/LabLostCave.tscn
exit /b 0
:fallo
echo Algo ha fallado: mira la salida de arriba.
pause
exit /b 1
