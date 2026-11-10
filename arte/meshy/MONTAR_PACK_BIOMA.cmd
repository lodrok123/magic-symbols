@echo off
chcp 65001 >nul
rem Monta arte\meshy\packs\pack_<bioma>.glb con las piezas del bioma que haya en meshy\entrada\ (nombre = id) y dice cuales faltan. Detalle en montar_pack_bioma.py.
rem Uso:  MONTAR_PACK_BIOMA.cmd [bioma]     (por defecto: pantano)
setlocal
cd /d "%~dp0"
set "PY="
py -3 --version >nul 2>&1 && set "PY=py -3"
if not defined PY ( python --version >nul 2>&1 && set "PY=python" )
if not defined PY ( echo No se encuentra Python. & pause & exit /b 1 )
if "%~1"=="" ( %PY% montar_pack_bioma.py pantano ) else ( %PY% montar_pack_bioma.py %* )
echo.
pause
