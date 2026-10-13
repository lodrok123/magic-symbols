@echo off
setlocal
cd /d "%~dp0.."

echo ===============================================
echo   Magic Symbols  ^|  rama de prueba isometrica
echo ===============================================
echo.

git --version >nul 2>&1
if errorlevel 1 (
    echo [X] No encuentro git. Instalalo desde https://git-scm.com/download/win
    pause
    exit /b 1
)

REM --- 1. Guardar lo que hay en main ------------------------------------
REM Primero se cierra el trabajo actual. Si se ramificara con cambios sin
REM guardar, esos cambios se irian con la rama nueva y main se quedaria
REM sin ellos: justo lo que NO queremos de una prueba desechable.
echo Guardando lo que hay ahora en main...
git add -A
git diff --cached --quiet
if errorlevel 1 (
    git commit -m "Capa neutra de fondo y .gdignore de los packs" >nul
    if errorlevel 1 goto :fallo
    echo [ok] Commit hecho.
) else (
    echo [ok] No habia nada pendiente.
)

git push
if errorlevel 1 (
    echo [!] No se pudo subir a GitHub, pero el commit local esta hecho.
    echo     Seguimos: la rama de prueba no depende de eso.
)

REM --- 2. Crear la rama de prueba ---------------------------------------
echo.
git rev-parse --verify prueba-isometrico >nul 2>&1
if errorlevel 1 (
    git checkout -b prueba-isometrico
    if errorlevel 1 goto :fallo
    echo [ok] Rama 'prueba-isometrico' creada.
) else (
    git checkout prueba-isometrico
    if errorlevel 1 goto :fallo
    echo [ok] Vuelto a la rama 'prueba-isometrico', que ya existia.
)

echo.
echo ===============================================
echo   Estas en la rama de prueba.
echo ===============================================
echo.
echo Todo lo que cambiemos a partir de ahora queda AQUI. main sigue
echo intacto con el juego que funciona.
echo.
echo   Para volver al juego de siempre:
echo       git checkout main
echo.
echo   Si la prueba convence, se trae a main con:
echo       git checkout main
echo       git merge prueba-isometrico
echo.
echo   Y si no convence, se tira entera y no ha pasado nada:
echo       git checkout main
echo       git branch -D prueba-isometrico
echo.
pause
exit /b 0

:fallo
echo.
echo [X] Algo fallo. El mensaje de git esta justo arriba.
echo.
pause
exit /b 1
