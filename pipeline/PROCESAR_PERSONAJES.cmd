@echo off
setlocal
cd /d "%~dp0\..\"
title Magic Symbols - Procesar personajes

set "PY="
py -3 --version >nul 2>&1 && set "PY=py -3"
if not defined PY (
  python --version >nul 2>&1 && set "PY=python"
)
if not defined PY (
  echo No se encuentra Python. Instalalo desde python.org y marca "Add to PATH".
  pause
  exit /b 1
)
rem Requisitos de Python (jsonschema, Pillow): si faltan, se instalan una vez desde tools\requirements.txt.
%PY% -c "import jsonschema, PIL" >nul 2>&1 || (echo Instalando requisitos de Python [jsonschema, Pillow]... & %PY% -m pip install --user -q -r "pipeline\tools\requirements.txt")

if not exist "pipeline\inbox" mkdir "pipeline\inbox"
echo.
echo Procesando carpetas de pipeline\inbox ...
%PY% "pipeline\tools\procesar_inbox.py" %*
set "CODE=%ERRORLEVEL%"
echo.
if "%CODE%"=="0" (echo TERMINADO.) else (echo TERMINADO CON FALLOS. Mira pipeline_output\^<personaje^>\REPORTE.md y pipeline\inbox\_logs)
pause
exit /b %CODE%
