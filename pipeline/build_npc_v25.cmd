@echo off
setlocal
cd /d "%~dp0\..\"

if "%~1"=="" (
  echo Falta input GLB.
  echo Uso: pipeline\build_npc_v25.cmd "C:\ruta\npc.glb" "nombre_test"
  exit /b 2
)
if "%~2"=="" (
  echo Falta nombre del test.
  exit /b 2
)

set "INPUT=%~1"
set "TEST=%~2"

call pipeline\run_npc_e2e_v24.cmd "%INPUT%" "%TEST%"
if errorlevel 1 (
  echo BUILD FAILED: E2E v2.4
  exit /b 10
)

call pipeline\render_npc_v25.cmd "%TEST%" "S,W,E"
if errorlevel 1 (
  echo BUILD FAILED: Render v2.5
  exit /b 11
)

echo.
echo ==========================================
echo MAGIC SYMBOLS NPC BUILD V2.5 COMPLETADO
echo ==========================================
echo GLB:     pipeline_output\npc_e2e\%TEST%\export\npc_processed.glb
echo JSON:    pipeline_output\npc_e2e\%TEST%\character_art.json
echo RENDERS: pipeline_output\npc_e2e\%TEST%\renders\idle
echo QA:      pipeline_output\npc_e2e\%TEST%\reports\07_render_qa_report.json
endlocal
