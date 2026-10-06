@echo off
rem Integra en la maqueta las piezas regeneradas de Meshy que haya en meshy\entrada\ (cartel.glb, pasadero.glb...).
rem Detalle en integrar_piezas.py. Con Godot abierto tambien vale: reimporta al volver a la ventana.
setlocal
cd /d "%~dp0"
set "PY="
py -3 --version >nul 2>&1 && set "PY=py -3"
if not defined PY ( python --version >nul 2>&1 && set "PY=python" )
if not defined PY ( echo No se encuentra Python. & pause & exit /b 1 )
%PY% integrar_piezas.py %*
echo.
pause
