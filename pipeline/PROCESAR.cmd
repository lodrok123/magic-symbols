@echo off
setlocal
cd /d "%~dp0\..\"
title Magic Symbols - Procesar
rem Uso:  PROCESAR.cmd [procesar | nuevo <tipo> <id> | aprobar <id> | rehacer <id> | estado | escena [id] | migrar | demo | cola | arte <id> [--estilos a,b] [--anim idle] [--dirs SW,SE,NE]]  [--force] [--sin-arte] [--dry-run]
set "PY="
py -3 --version >nul 2>&1 && set "PY=py -3"
if not defined PY ( python --version >nul 2>&1 && set "PY=python" )
if not defined PY ( echo No se encuentra Python. & pause & exit /b 1 )
rem Requisitos de Python (jsonschema, Pillow): si faltan, se instalan una vez desde tools\requirements.txt.
%PY% -c "import jsonschema, PIL" >nul 2>&1 || (echo Instalando requisitos de Python [jsonschema, Pillow]... & %PY% -m pip install --user -q -r "pipeline\tools\requirements.txt")
%PY% "pipeline\tools\ms_assets.py" %*
set "CODE=%ERRORLEVEL%"
echo.
if "%CODE%"=="0" (echo TERMINADO.) else (echo TERMINADO CON AVISOS/FALLOS. Mira pipeline_output\^<id^>\REPORTE.md)
pause
exit /b %CODE%
