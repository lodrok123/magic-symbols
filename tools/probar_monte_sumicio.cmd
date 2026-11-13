@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "PROYECTO=%~dp0.."
set "GODOT=%GODOT_EXE%"
if not exist "%GODOT%" set "GODOT="
if not defined GODOT if exist "%~dp0godot_local.txt" set /p "GODOT="<"%~dp0godot_local.txt"
set "GODOT=%GODOT:"=%"
if not exist "%GODOT%" set "GODOT=%~dp0Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
    echo No se encuentra Godot. Revisa tools\godot_local.txt.
    pause
    exit /b 1
)

start "" /wait "%GODOT%" --path "%PROYECTO%" res://escenas/PruebaMonteSumicio.tscn
if errorlevel 1 (
    echo Godot se ha cerrado con un error.
    pause
    exit /b 1
)
