@echo off
setlocal
cd /d "%~dp0\..\"

if "%~1"=="" (
  echo Falta input GLB.
  echo Uso: pipeline\run_npc_e2e_v24.cmd "input.glb" "nombre_test"
  exit /b 2
)
if "%~2"=="" (
  echo Falta el nombre corto del test.
  exit /b 2
)

set "BLENDER=C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
set "INPUT=%~1"
set "TEST=%~2"
set "WORK=%CD%\pipeline_output\npc_e2e\%TEST%"
set "SCRIPT=%CD%\pipeline\tools\ms_npc_e2e_v2_4.py"
set "PROFILE=%CD%\pipeline\profiles\npc_e2e_v2_4.json"
set "REPORT=%WORK%\reports\e2e_report.json"

echo.
echo === MAGIC SYMBOLS NPC E2E V2.4 ===
echo INPUT: %INPUT%
echo WORK : %WORK%
echo.

"%BLENDER%" --background --python "%SCRIPT%" -- --input-glb "%INPUT%" --profile "%PROFILE%" --workspace "%WORK%" --stage all --report "%REPORT%"
if errorlevel 1 exit /b %errorlevel%

echo.
echo OK:
echo   %WORK%\export\npc_processed.glb
echo   %WORK%\character_art.json
echo   %WORK%\reports\e2e_report.json
echo   %WORK%\textures\
endlocal
