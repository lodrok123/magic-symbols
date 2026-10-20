@echo off
rem prueba_una.cmd - lanza UNA prueba o escenario sin ventana y va contando lo que pasa, con veredicto claro al final. Lo escribe el Juego.
rem Uso, desde la raiz del repo:   tools\prueba_una.cmd escenario_puzles_agua      (sin ".gd"; vale prueba_* o escenario_*)
rem Mientras corre se ve cada linea de la prueba (OK / FALLO / AVISO / SCRIPT ERROR). La salida entera queda en salida_prueba.txt.
rem Como leerlo:
rem   OK            la afirmacion se cumplio.
rem   FALLO         la afirmacion NO se cumplio: el contrato esta roto (o la prueba esta mal). Esto SI es un error.
rem   AVISO         una medida que se imprime para calibrar; no es un error.
rem   SCRIPT ERROR  el codigo ha petado en algun sitio (la linea "at:" de debajo dice donde). Es un error del codigo,
rem                 aunque la prueba siga y acabe en FALLOS: 0.
rem   "SIN RESULTADO"  ninguna linea de resultado (FALLOS: N, OK: N fallos, RESULTADO x: N fallos...): no compilo o se colgo (se colgo o no compilo): mirar salida_prueba.txt.
setlocal EnableDelayedExpansion
cd /d "%~dp0.."
if "%~1"=="" (
  echo Falta el nombre. Ejemplo:  tools\prueba_una.cmd escenario_puzles_agua
  pause
  exit /b 2
)
set NOMBRE=%~1
set NOMBRE=%NOMBRE:.gd=%
if not exist "herramientas\%NOMBRE%.gd" (
  echo No existe herramientas\%NOMBRE%.gd
  pause
  exit /b 2
)
set GODOT=
if exist tools\godot_local.txt set /p GODOT=<tools\godot_local.txt
set "GODOT=!GODOT:"=!"
rem godot_local.txt puede traer la ruta de OTRO ordenador (si alguien lo sube a git): si no existe, se usa el Godot de tools\ y se corrige el archivo.
if not exist "!GODOT!" if exist "%~dp0Godot_v4.7.2-stable_win64.exe" (
  set "GODOT=%~dp0Godot_v4.7.2-stable_win64.exe"
  echo !GODOT!>tools\godot_local.txt
  echo Aviso: godot_local.txt apuntaba a una ruta que no existe aqui; corregido a !GODOT!
)
if not exist "!GODOT!" (
  echo No encuentro Godot. Escribe su ruta en tools\godot_local.txt o ejecuta antes tools\pruebas.cmd.
  pause
  exit /b 2
)
set OPC=
echo %NOMBRE% | findstr /B /C:"escenario_" >nul && set OPC=--fixed-fps 30
rem 20/10 (Pipeline, con permiso de Pablo): tambien las pruebas que extienden escenario_base (cast_points, nado_desactivado) piden 30 fps fijos
findstr /C:"escenario_base.gd" herramientas\%NOMBRE%.gd 2>nul | findstr /C:"extends" >nul && set OPC=--fixed-fps 30
echo ===== %NOMBRE% =====  (Godot: !GODOT!)  %OPC%
echo Arrancando... (un escenario tarda minutos: cada OK/FALLO sale segun ocurre)
echo.
rem PowerShell hace de "tee": ensena cada linea al momento y la guarda. Solo se ensenan las lineas que importan.
!GODOT! --headless %OPC% --path . --script res://herramientas/%NOMBRE%.gd 2>&1 | powershell -NoProfile -Command "$input | Tee-Object -FilePath salida_prueba.txt | Select-String -Pattern '^\s*(OK |OK:|FALLO|AVISO|SCRIPT ERROR|at:|RESULTADO)' | ForEach-Object { $_.Line }"
rem Tee-Object escribe UTF-16 y findstr no lo lee: se pasa a UTF-8.
powershell -NoProfile -Command "(Get-Content salida_prueba.txt) | Set-Content -Encoding UTF8 salida_prueba.txt"
echo.
rem 19/10: el veredicto lo saca tools\resumen_prueba.ps1 (mismas reglas que pruebas.cmd: acepta las cinco formas de linea de resultado y descarta el ruido de fugas).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resumen_prueba.ps1" -Una -Archivo salida_prueba.txt
rem La ventana se queda abierta (si se abrio con doble clic, si no se cerraria sin dejar leer).
pause
endlocal
