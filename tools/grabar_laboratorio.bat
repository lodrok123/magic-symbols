@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0.."

REM ===============================================
REM   Graba el laboratorio de VFX con el modo de
REM   grabacion de Godot (Movie Maker).
REM
REM   Uso:   tools\grabar_laboratorio.bat [nombre]
REM   Sale:  videos\[nombre].avi  (+ .mp4 y .gif si hay ffmpeg)
REM
REM   Godot se busca solo: variable GODOT_EXE, el archivo
REM   tools\godot_ruta.txt, el PATH y carpetas habituales.
REM   Si no aparece, te pide la ruta y la recuerda.
REM ===============================================

set "NOMBRE=%~1"
if "%NOMBRE%"=="" set "NOMBRE=lab"

REM --- 1. Localizar Godot -------------------------------------------------
set "GODOT="

if defined GODOT_EXE if exist "%GODOT_EXE%" set "GODOT=%GODOT_EXE%"

if not defined GODOT if exist "%~dp0godot_ruta.txt" (
    set /p GODOT=<"%~dp0godot_ruta.txt"
    if not exist "!GODOT!" set "GODOT="
)

if not defined GODOT (
    for /f "delims=" %%G in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%G"
)

if not defined GODOT (
    echo Buscando Godot en Descargas, Escritorio y otras carpetas...
    for %%D in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "C:\Godot" "C:\Tools" "%ProgramFiles%" "%USERPROFILE%\Documents") do (
        if not defined GODOT if exist "%%~D" (
            for /f "delims=" %%G in ('dir /s /b "%%~D\Godot*.exe" 2^>nul ^| findstr /v /i "_console"') do if not defined GODOT set "GODOT=%%G"
        )
    )
)

if not defined GODOT (
    echo.
    echo No encuentro Godot solo. Arrastra aqui su .exe y pulsa Enter
    echo ^(o pega la ruta completa^):
    set /p "GODOT="
)

set "GODOT=!GODOT:"=!"
if not exist "!GODOT!" (
    echo.
    echo [X] Esa ruta no existe: !GODOT!
    pause
    exit /b 1
)

> "%~dp0godot_ruta.txt" echo !GODOT!
echo Usando Godot: !GODOT!

REM --- 2. Grabar ----------------------------------------------------------
if not exist videos mkdir videos

echo.
echo Grabando el laboratorio ^(unos 25 segundos, se cierra solo^)...
REM  --fixed-fps: cada fotograma dura lo mismo aunque el equipo vaya lento.
REM  --quit-after: red de seguridad, por si el guion no llegara a cerrar.
"!GODOT!" --path . --write-movie "videos\%NOMBRE%.avi" --fixed-fps 30 --resolution 1280x720 --quit-after 1200 res://VfxLab.tscn -- --grabar
if errorlevel 1 goto :fallo

if not exist "videos\%NOMBRE%.avi" goto :fallo
echo [ok] videos\%NOMBRE%.avi

REM --- 3. Convertir -------------------------------------------------------
where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo.
    echo [aviso] No hay ffmpeg, asi que me quedo en el .avi ^(pesa mucho y no
    echo         se puede mandar por chat^). Para convertirlo:
    echo             winget install Gyan.FFmpeg
    echo         y vuelve a lanzar este archivo.
    pause
    exit /b 0
)

echo Convirtiendo a mp4 ^(para mandar, con sonido^)...
ffmpeg -y -loglevel error -i "videos\%NOMBRE%.avi" -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac "videos\%NOMBRE%.mp4"
echo [ok] videos\%NOMBRE%.mp4

echo Convirtiendo a gif ^(sin sonido^)...
ffmpeg -y -loglevel error -i "videos\%NOMBRE%.avi" -vf "fps=20,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "videos\%NOMBRE%.gif"
echo [ok] videos\%NOMBRE%.gif

echo.
echo Listo. Todo esta en la carpeta videos.
pause
exit /b 0

:fallo
echo.
echo [X] Algo fallo. El mensaje de Godot esta justo arriba.
pause
exit /b 1
