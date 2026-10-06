@echo off
setlocal enableextensions
rem Ordena el proyecto: crea la estructura y MUEVE (no borra) lo obsoleto a _obsoleto.
rem Seguro de repetir. Para deshacer, mueve los archivos de vuelta desde _obsoleto.
cd /d "%~dp0.."
set "OB=pipeline\_obsoleto"
set "OBO=pipeline_output\_obsoleto"

echo === Estructura ===
for %%D in (export_godot\characters export_godot\enemies export_godot\terrain "%OB%\scripts" "%OB%\tools" "%OBO%") do if not exist "%%~D" mkdir "%%~D"
if not exist pipeline\.gdignore type nul > pipeline\.gdignore
if not exist pipeline_output\.gdignore type nul > pipeline_output\.gdignore
if not exist "%OB%\.gdignore" type nul > "%OB%\.gdignore"
if not exist "%OBO%\.gdignore" type nul > "%OBO%\.gdignore"

echo === Scripts .cmd antiguos ===
for %%F in (01_bake_basecolor 02_bake_roughness 03_pack_mr 04_finalize 05_export_glb 06_inspect_glb 07_render_SWE build_v08_auto_02 inspect_npc_e2e_v23) do (
  if exist "pipeline\%%F.cmd" move /y "pipeline\%%F.cmd" "%OB%\scripts\" >nul && echo movido %%F.cmd
)

echo === Herramientas .py antiguas ===
for %%F in (ms_art_extend_v1_safe ms_art_rebase_v2 ms_art_rebase_v2_1 ms_art_pipeline_v2_2 apply_idle_pose_offset finalize_v06_actions inspect_glb_actions inspect_glb_alpha inspect_rig_names lock_bone_offsets_v4 lock_feet_from_current_pose promote_active_action_to_idle export_shader_tree) do (
  if exist "pipeline\tools\%%F.py" move /y "pipeline\tools\%%F.py" "%OB%\tools\" >nul && echo movido %%F.py
)
if exist pipeline\tools\__pycache__ rmdir /s /q pipeline\tools\__pycache__

echo === Salidas de prueba ===
for %%F in (ranger_prueba_art ranger_test_01 ranger_test_02 ranger_test_03 ranger_test_04 ranger_test_05) do (
  if exist "pipeline_output\npc_e2e\%%F" move /y "pipeline_output\npc_e2e\%%F" "%OBO%\" >nul && echo movido npc_e2e\%%F
)

echo.
echo Listo. Revisa pipeline\_obsoleto y pipeline_output\_obsoleto y borralos cuando quieras.
pause
