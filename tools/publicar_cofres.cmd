@echo off
setlocal
cd /d "%~dp0.."
git diff --cached --quiet
if errorlevel 1 goto staged_error
git diff --check
if errorlevel 1 goto failed
git add -- ^
  "escenas/puzle.gd" ^
  "jugador/pj_3d.gd" ^
  "objetos/secuencia_cofre_legendario_3d.gd" ^
  "objetos/ceremonia_cofre_3d.gd" ^
  "presentacion/cofre_3d.gd" ^
  "presentacion/cofre_ceremonia_vfx_3d.gd" ^
  "presentacion/cofre_estrellas_3d.gd" ^
  "presentacion/libro_ceremonia_3d.gd" ^
  "laboratorios/LabCofresCeremonia3D.tscn" ^
  "laboratorios/lab_cofres_ceremonia_3d.gd" ^
  "tools/probar_cofres.cmd" ^
  "herramientas/captura_cofres_ceremonia.gd" ^
  "herramientas/medir_cofres_mixamo.gd" ^
  "herramientas/prueba_cofres_ceremonia.gd" ^
  "herramientas/prueba_cofres_cueva.gd" ^
  "herramientas/captura_cofre_abrir.gd" ^
  "herramientas/captura_cueva_arreglos.gd" ^
  "herramientas/captura_jugadora_integrada.gd" ^
  "herramientas/captura_pulso_fase2.gd" ^
  "herramientas/escenario_bosque_01_v01.gd" ^
  "herramientas/escenario_cueva_pulso.gd" ^
  "docs/CONCEPTO_APERTURA_COFRES_2026-11-19.md" ^
  "docs/PLAN_IMPLEMENTACION_COFRES_2026-11-19.md" ^
  "docs/COFRES_IMPLEMENTACION_Y_PRUEBA_2026-11-19.md" ^
  "docs/capturas/cofres_ceremonia" ^
  "docs/capturas/cofres_cueva" ^
  "escenas/puzle.gd.uid" ^
  "jugador/pj_3d.gd.uid" ^
  "objetos/secuencia_cofre_legendario_3d.gd.uid" ^
  "objetos/ceremonia_cofre_3d.gd.uid" ^
  "presentacion/cofre_3d.gd.uid" ^
  "presentacion/cofre_ceremonia_vfx_3d.gd.uid" ^
  "presentacion/cofre_estrellas_3d.gd.uid" ^
  "presentacion/libro_ceremonia_3d.gd.uid" ^
  "laboratorios/lab_cofres_ceremonia_3d.gd.uid" ^
  "herramientas/captura_cofre_abrir.gd.uid" ^
  "herramientas/captura_cueva_arreglos.gd.uid" ^
  "herramientas/captura_jugadora_integrada.gd.uid" ^
  "herramientas/captura_pulso_fase2.gd.uid" ^
  "herramientas/escenario_bosque_01_v01.gd.uid" ^
  "herramientas/escenario_cueva_pulso.gd.uid"
if errorlevel 1 goto failed
git diff --cached --check
if errorlevel 1 goto failed
git diff --cached --stat
git diff --cached --quiet
if not errorlevel 1 goto push
git commit -m "Cofres: apertura con estrellas, libro y camara orbital"
if errorlevel 1 goto failed
:push
git push origin HEAD
if errorlevel 1 goto failed
echo Commit y push completados.
git log -1 --oneline
pause
exit /b 0
:staged_error
echo Hay cambios ya preparados en el indice. Revisalos antes de publicar los cofres.
pause
exit /b 1
:failed
echo No se ha completado la publicacion. Revisa el error anterior.
pause
exit /b 1
