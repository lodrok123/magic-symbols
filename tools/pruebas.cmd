@echo off
rem pruebas.cmd - lanza todas las pruebas sin ventana (herramientas\prueba_*.gd) y los escenarios con la escena entera
rem (herramientas\escenario_*.gd, a 30 fps fijos; escenario_base.gd es el armazon y no se lanza) y resume. Lo escribe el Juego.
rem Uso, desde la raiz del repo (o doble clic):   tools\pruebas.cmd      (o   tools\pruebas.cmd solo <trozo de nombre> ...   para un subconjunto)
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
rem 19/10: el recuento lo hace tools\resumen_prueba.ps1 (acepta FALLOS: N / FALLOS N / FALLOS <nombre>: N / OK: N fallos / RESULTADO <nombre>: N fallos,
rem descarta el ruido de fugas de Godot, cuenta aparte los "Lambda capture ... was freed" como AVISOS y saca una tabla prueba / fallos / avisos / veredicto).
rem Uso:   tools\pruebas.cmd                    todas
rem        tools\pruebas.cmd solo golpe hechizo  solo las que contengan alguno de esos trozos de nombre (golpe, hechizo_vivo, prueba_hechizo...)
set "PATRON="
set "ARGS=%*"
if /i "%~1"=="solo" set "PATRON=!ARGS:~5!"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resumen_prueba.ps1" -Godot "!GODOT!" -Patron "!PATRON!"
pause
endlocal
exit /b 0
