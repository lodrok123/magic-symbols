@echo off
setlocal
cd /d "%~dp0\..\"
title Magic Symbols - Fase de arte

set "PY="
py -3 --version >nul 2>&1 && set "PY=py -3"
if not defined PY (
  python --version >nul 2>&1 && set "PY=python"
)
if not defined PY (
  echo No se encuentra Python.
  pause
  exit /b 1
)
rem Requisitos de Python (jsonschema, Pillow): si faltan, se instalan una vez desde tools\requirements.txt.
%PY% -c "import jsonschema, PIL" >nul 2>&1 || (echo Instalando requisitos de Python [jsonschema, Pillow]... & %PY% -m pip install --user -q -r "pipeline\tools\requirements.txt")

set "CID=%~1"
if "%CID%"=="" set /p CID=Id del personaje ya procesado (carpeta de pipeline\characters, p. ej. ranger_prueba): 
if "%CID%"=="" exit /b 2

%PY% "pipeline\tools\art_stage.py" "%CID%"
set "CODE=%ERRORLEVEL%"
echo.
echo Detalle: pipeline_output\%CID%\art_stage.log
pause
exit /b %CODE%
