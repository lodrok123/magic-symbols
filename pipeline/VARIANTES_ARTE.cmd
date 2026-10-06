@echo off
setlocal
cd /d "%~dp0.."
set "ID=%~1"
if "%ID%"=="" set /p ID=Id del personaje (con arte ya procesado): 
set "ST=%~2"
if "%ST%"=="" set "ST=base,anime_a,anime_b"
where py >nul 2>nul && (py -3 pipeline\tools\variantes.py "%ID%" "%ST%") || (python pipeline\tools\variantes.py "%ID%" "%ST%")
echo.
pause
