@echo off
rem Ordena poc_25d: lo que ya no usa ninguna escena viva (PruebaTest2, LabVfx3D, CatalogoAssets)
rem se mueve a poc_25d\_descartado\, con sus .import y texturas extraidas. NO borra nada.
rem Ejecutar con GODOT CERRADO. Para deshacer: mover de vuelta lo que haya en _descartado\.
setlocal
cd /d "%~dp0"
set "D=_descartado"
mkdir "%D%" 2>nul
rem Sin .gdignore, Godot seguiria importando (y cargando en el editor) lo descartado.
if not exist "%D%\.gdignore" type nul > "%D%\.gdignore"
mkdir "%D%\pruebas_A_E" 2>nul
mkdir "%D%\modelos_viejos" 2>nul
mkdir "meshy\entrada\_procesados" 2>nul

echo.
echo == Pruebas A-E (sustituidas por PruebaTest2 y LabVfx3D) ==
for %%f in (Prueba3D.tscn prueba_3d.gd prueba_3d.gd.uid Prueba2D.tscn prueba_2d.gd prueba_2d.gd.uid ^
            Prueba25D.tscn prueba_25d.gd prueba_25d.gd.uid PruebaCenital.tscn prueba_cenital.gd prueba_cenital.gd.uid ^
            PruebaDiorama.tscn prueba_diorama.gd prueba_diorama.gd.uid ms_actor_3d.gd ms_actor_3d.gd.uid) do (
  if exist "%%f" move /y "%%f" "%D%\pruebas_A_E\" >nul && echo   %%f
)
if exist "kit_suelo" move /y "kit_suelo" "%D%\pruebas_A_E\kit_suelo" >nul && echo   kit_suelo\
if exist "suelo" move /y "suelo" "%D%\pruebas_A_E\suelo" >nul && echo   suelo\ (losetas cenitales de la prueba D)

echo.
echo == Modelos de la direccion anterior (hero realista, chibi de prueba, goblin viejo) ==
for %%p in (hero hero_v2 chibi_test goblin_warrior) do (
  for %%f in ("%%p.glb" "%%p.glb.import" "%%p_normal.png" "%%p_normal.png.import" ^
              "%%p_texture_0.png" "%%p_texture_0.png.import" ^
              "%%p_texture_0_metallic_roughness.png" "%%p_texture_0_metallic_roughness.png.import") do (
    if exist "%%~f" move /y "%%~f" "%D%\modelos_viejos\" >nul && echo   %%~f
  )
)

echo.
echo == GLB de Meshy ya partidos en bibliotecas ==
for %%f in ("meshy\entrada\Tree_Trio_texture.glb" "meshy\entrada\Market_Ruin_texture.glb" "meshy\entrada\Armas_Goblin_texture.glb" ^
            "meshy\entrada\Meshy_AI_Enchanted_Forest_Trea_1005002832_texture.glb" ^
            "meshy\entrada\Meshy_AI_Mystic_Adventure_Prop_1004234516_texture.glb" ^
            "meshy\entrada\Meshy_AI_Whimsical_Forest_Elem_1004232552_texture.glb") do (
  if exist "%%~f" move /y "%%~f" "meshy\entrada\_procesados\" >nul && echo   %%~f
)

echo.
echo == Bibliotecas repetidas (5/10 noche): arboles.glb = arboles_2.glb; meshy\armas_goblin.glb ya preparado en equipo\ ==
mkdir "%D%\bibliotecas_repetidas" 2>nul
for %%f in ("meshy\arboles.glb" "meshy\arboles.glb.import" "meshy\arboles_0.jpg" "meshy\arboles_0.jpg.import" ^
            "meshy\arboles_1.jpg" "meshy\arboles_1.jpg.import" ^
            "meshy\armas_goblin.glb" "meshy\armas_goblin.glb.import" "meshy\armas_goblin_0.jpg" "meshy\armas_goblin_0.jpg.import" ^
            "meshy\armas_goblin_1.jpg" "meshy\armas_goblin_1.jpg.import") do (
  if exist "%%~f" move /y "%%~f" "%D%\bibliotecas_repetidas\" >nul && echo   %%~f
)

echo.
echo == Grimorios originales de Meshy (ya preparados en equipo\grimorio_1..3.glb) ==
mkdir "%D%\grimorios_meshy" 2>nul
for %%f in (grimorio\Meshy_AI_*) do (
  move /y "%%f" "%D%\grimorios_meshy\" >nul && echo   %%f
)

echo.
echo Hecho. Abre Godot: reimporta y las escenas vivas no deben avisar de nada con (!).
echo Si CatalogoAssets o LabVfx3D echan en falta algo, mueve ese archivo de vuelta desde %D%\.
pause
