@echo off
setlocal
cd /d "%~dp0\..\"

if "%~1"=="" (
  echo Falta nombre del test E2E.
  echo Uso: pipeline\render_npc_v25.cmd "ranger_test_05" "S,W,E"
  exit /b 2
)

set "TEST=%~1"
set "DIRS=%~2"
if "%DIRS%"=="" set "DIRS=S,W,E"

set "BLENDER=C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
set "STUDIO=%CD%\Render Studio\MS_CHARACTER_RENDER_STUDIO.blend"
set "SCRIPT=%CD%\pipeline\tools\render_npc_v2_5.py"
set "WORK=%CD%\pipeline_output\npc_e2e\%TEST%"
set "CHARACTER=%WORK%\character_art.json"
set "OUT=%WORK%\renders\idle"
set "REPORT=%WORK%\reports\07_render_qa_report.json"

if not exist "%STUDIO%" (
  echo ERROR: No existe Render Studio:
  echo   %STUDIO%
  exit /b 3
)
if not exist "%CHARACTER%" (
  echo ERROR: No existe character_art.json:
  echo   %CHARACTER%
  exit /b 4
)

echo.
echo === MAGIC SYMBOLS NPC RENDER V2.5 ===
echo TEST : %TEST%
echo DIRS : %DIRS%
echo OUT  : %OUT%
echo.

"%BLENDER%" "%STUDIO%" --background --python "%SCRIPT%" -- --character-json "%CHARACTER%" --directions "%DIRS%" --output "%OUT%" --report "%REPORT%"
set "BLENDER_EXIT=%ERRORLEVEL%"
if not "%BLENDER_EXIT%"=="0" (
  echo.
  echo RENDER FAILED: Blender exit code %BLENDER_EXIT%
  exit /b %BLENDER_EXIT%
)

if not exist "%REPORT%" (
  echo.
  echo RENDER FAILED: no se genero el informe QA:
  echo   %REPORT%
  exit /b 5
)

echo.
echo RENDER OK:
echo   %OUT%
echo   %REPORT%
endlocal
