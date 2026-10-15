@echo off
rem pruebas.cmd - lanza todas las pruebas sin ventana (herramientas\prueba_*.gd) y los escenarios con la escena entera
rem (herramientas\escenario_*.gd, a 30 fps fijos; escenario_base.gd es el armazon y no se lanza) y resume. Lo escribe el Juego.
rem Uso, desde la raiz del repo (o doble clic):   tools\pruebas.cmd
rem Donde esta Godot: tools\godot_local.txt (una linea con la ruta al .exe). Si no existe, lo busca en los sitios habituales y, si no, lo pregunta.
setlocal EnableDelayedExpansion
cd /d "%~dp0.."
set GODOT=
if exist tools\godot_local.txt set /p GODOT=<tools\godot_local.txt
if defined GODOT if exist "!GODOT!" goto :correr
echo Buscando Godot...
for %%D in ("%~dp0" "%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%USERPROFILE%\Documents" "C:\Godot" "%LOCALAPPDATA%\Programs\Godot" "C:\Program Files\Godot") do (
  if exist "%%~D" for /f "delims=" %%F in ('dir /b /s "%%~D\Godot*.exe" 2^>nul') do (
    echo %%F | findstr /i /v "console" >nul && if not defined GODOT set "GODOT=%%F"
  )
)
if defined GODOT (
  echo Encontrado: !GODOT!
  goto :guardar
)
echo No lo encuentro. Escribe la ruta completa al ejecutable de Godot 4 (botón derecho en el acceso directo de Godot, Propiedades, Destino).
set /p GODOT=Ruta: 
set "GODOT=!GODOT:"=!"
if not exist "!GODOT!" (
  echo No existe "!GODOT!". Vuelve a ejecutar y revisa la ruta.
  pause
  exit /b 1
)
:guardar
echo !GODOT!>tools\godot_local.txt
:correr
set "GODOT=!GODOT:"=!"
for %%G in ("!GODOT!") do set "GODOT=%%~sG"
echo Godot: !GODOT!
set FALLOS_TOTAL=0
for %%P in (herramientas\prueba_*.gd) do call :una "%%~nxP"
rem 15/10 (13.10): los escenarios cargan escenas/PruebaBosque.tscn; tardan mas (unos 20-60 s cada uno) y van a 30 fps fijos, que es lo que pide el plan.
for %%P in (herramientas\escenario_*.gd) do if /i not "%%~nxP"=="escenario_base.gd" call :una "%%~nxP" "--fixed-fps 30"
echo.
echo ================ TOTAL DE FALLOS: !FALLOS_TOTAL! ================
pause
endlocal
exit /b 0

:una
echo.
echo ===== %~1 =====
rem %~2 son opciones de Godot extra (los escenarios pasan --fixed-fps 30).
!GODOT! --headless %~2 --path . --script res://herramientas/%~1 >"%TEMP%\prueba_salida.txt" 2>&1
findstr /C:"FALLO " "%TEMP%\prueba_salida.txt"
rem (Con escena, Godot sin ventana suelta al salir avisos de fugas del renderizador de mentira: no son de la prueba y se descartan.)
findstr /C:"SCRIPT ERROR" /C:"Parse Error" /C:"Failed to load" /C:"ERROR:" "%TEMP%\prueba_salida.txt" | findstr /V /C:"Pages in use" /C:"RID allocations" /C:"leaked at exit"
set HAY=0
for /f "tokens=2" %%N in ('findstr /C:"FALLOS:" "%TEMP%\prueba_salida.txt"') do (
  set HAY=1
  set /a FALLOS_TOTAL+=%%N
  echo FALLOS: %%N
)
if "!HAY!"=="0" (
  echo SIN RESULTADO: la prueba no llego al final. Salida completa:
  type "%TEMP%\prueba_salida.txt"
  set /a FALLOS_TOTAL+=1
)
exit /b 0
