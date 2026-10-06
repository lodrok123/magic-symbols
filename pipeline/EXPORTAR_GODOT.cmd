@echo off
setlocal
cd /d "%~dp0.."
title Magic Symbols - Exportar a Godot
rem Uso: EXPORTAR_GODOT.cmd <id> [--tipo characters^|enemies] [--forzar]
set "PY="
py -3 --version >nul 2>&1 && set "PY=py -3"
if not defined PY ( python --version >nul 2>&1 && set "PY=python" )
if not defined PY ( echo No se encuentra Python. Instalalo desde python.org y marca "Add to PATH". & pause & exit /b 1 )
rem Requisitos de Python (jsonschema, Pillow): si faltan, se instalan una vez desde tools\requirements.txt.
%PY% -c "import jsonschema, PIL" >nul 2>&1 || (echo Instalando requisitos de Python [jsonschema, Pillow]... & %PY% -m pip install --user -q -r "pipeline\tools\requirements.txt")
set "ID=%~1"
if "%ID%"=="" set /p ID=Id del personaje aprobado (carpeta de pipeline_output): 
if "%ID%"=="" exit /b 2
%PY% pipeline\tools\exportar_godot.py "%ID%" %2 %3 %4
set "CODE=%ERRORLEVEL%"
echo.
pause
exit /b %CODE%
