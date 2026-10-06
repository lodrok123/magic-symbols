@echo off
rem Copia los modelos 3D maestros del pipeline a res://poc_25d/ para que Godot los importe.
rem Solo los personajes que usan las escenas vivas (PruebaTest2, PruebaJugabilidad3D, LabVfx3D, CatalogoAssets).
rem Los antiguos (hero, hero_v2, chibi_test, goblin_warrior) ya no se copian: estan en _descartado\.
cd /d "%~dp0.."
for %%p in (chibi_elf bookseller_chibi goblin_warrior_chibi alchemist_elf goblin_archer_chibi) do (
  if exist "pipeline\characters\%%p\%%p_master.glb" (
    copy /y "pipeline\characters\%%p\%%p_master.glb" "poc_25d\%%p.glb" >nul && echo   %%p.glb
  ) else (
    echo   (!) falta pipeline\characters\%%p\%%p_master.glb
  )
)
echo.
echo Listo. Abre Godot y espera a que importe los .glb.
pause
