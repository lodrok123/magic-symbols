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
rem   "SIN RESULTADO"  la prueba no llego al final (se colgo o no compilo): mirar salida_prueba.txt.
setlocal EnableDelayedExpansion
cd /d "%~dp0.."
if "%~1"=="" (
  echo Falta el nombre. Ejemplo:  tools\prueba_una.cmd escenario_puzles_agua
  exit /b 2
)
set NOMBRE=%~1
set NOMBRE=%NOMBRE:.gd=%
if not exist "herramientas\%NOMBRE%.gd" (
  echo No existe herramientas\%NOMBRE%.gd
  exit /b 2
)
set GODOT=
if exist tools\godot_local.txt set /p GODOT=<tools\godot_local.txt
set "GODOT=!GODOT:"=!"
if not exist "!GODOT!" if exist "tools\Godot_v4.7.2-stable_win64.exe" set "GODOT=tools\Godot_v4.7.2-stable_win64.exe"
if not exist "!GODOT!" (
  echo No encuentro Godot. Escribe su ruta en tools\godot_local.txt o ejecuta antes tools\pruebas.cmd.
  exit /b 2
)
set OPC=
echo %NOMBRE% | findstr /B /C:"escenario_" >nul && set OPC=--fixed-fps 30
echo ===== %NOMBRE% =====  (Godot: !GODOT!)  %OPC%
echo Arrancando... (un escenario tarda minutos: cada OK/FALLO sale segun ocurre)
echo.
rem PowerShell hace de "tee": ensena cada linea al momento y la guarda. Solo se ensenan las lineas que importan.
!GODOT! --headless %OPC% --path . --script res://herramientas/%NOMBRE%.gd 2>&1 | powershell -NoProfile -Command "$input | Tee-Object -FilePath salida_prueba.txt | Select-String -Pattern '^(OK |FALLO|AVISO|SCRIPT ERROR|   at:|FALLOS:)' | ForEach-Object { $_.Line }"
rem Tee-Object escribe UTF-16 y findstr no lo lee: se pasa a UTF-8.
powershell -NoProfile -Command "(Get-Content salida_prueba.txt) | Set-Content -Encoding UTF8 salida_prueba.txt"
echo.
set FALLOS=
for /f "tokens=2" %%N in ('findstr /C:"FALLOS:" salida_prueba.txt') do set FALLOS=%%N
for /f %%N in ('findstr /C:"SCRIPT ERROR" salida_prueba.txt ^| find /c /v ""') do set ERRORES=%%N
for /f %%N in ('findstr /B /C:"AVISO" salida_prueba.txt ^| find /c /v ""') do set AVISOS=%%N
echo ================================================================
if not defined FALLOS (
  echo RESULTADO: SIN RESULTADO - la prueba no llego al final. Mira salida_prueba.txt ^(ultimas lineas^):
  powershell -NoProfile -Command "Get-Content salida_prueba.txt -Tail 15"
  echo ================================================================
  exit /b 1
)
if "!FALLOS!"=="0" (
  if "!ERRORES!"=="0" (
    echo RESULTADO: BIEN - 0 fallos, 0 errores de codigo, !AVISOS! avisos ^(los avisos son medidas, no errores^)
  ) else (
    echo RESULTADO: PASA CON ERRORES DE CODIGO - 0 fallos pero !ERRORES! SCRIPT ERROR ^(mira las lineas "at:" de arriba^)
  )
) else (
  echo RESULTADO: MAL - !FALLOS! fallos, !ERRORES! errores de codigo, !AVISOS! avisos
)
echo ================================================================
endlocal
