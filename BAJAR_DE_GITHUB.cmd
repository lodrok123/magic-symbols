@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
rem ============================================================================
rem  BAJAR_DE_GITHUB.cmd  --  trae lo ultimo del repositorio a la carpeta de trabajo
rem
rem  Se lanza AL EMPEZAR a trabajar. Si la carpeta no es un repositorio todavia
rem  (ordenador nuevo), clona. Si lo es, hace pull --rebase.
rem  Con Godot abierto se niega: pisar el proyecto con el editor abierto corrompe
rem  la cache y los .import.
rem ============================================================================

set "REPO=https://github.com/lodrok123/magic-symbols.git"
set "CARPETA=%USERPROFILE%\Documents\magic-symbols"

git --version >nul 2>&1 || (echo [ERROR] No encuentro git. Instalalo: https://git-scm.com/download/win & goto :fin)

tasklist /fi "imagename eq Godot*" 2>nul | find /i "Godot" >nul && (
    echo [PARADO] Godot esta abierto. Cierralo antes de bajar.
    goto :fin
)

if not exist "%CARPETA%\.git\HEAD" (
    if exist "%CARPETA%\project.godot" (
        echo [PARADO] "%CARPETA%" existe pero no es un repositorio git.
        echo          Si es la copia buena, ejecuta SUBIR_A_GITHUB.cmd desde ella ^(recupera .git de OneDrive^).
        echo          Si es una copia vieja, renombrala y vuelve a ejecutar esto para clonar.
        goto :fin
    )
    echo Clonando %REPO% en "%CARPETA%"...
    git clone "%REPO%" "%CARPETA%" || goto :fallo
    echo [OK] Clonado. Abre Godot desde "%CARPETA%": la primera vez reimporta todo.
    goto :fin
)

cd /d "%CARPETA%"

rem --- cambios locales sin commit: no se pisan ---
git diff --quiet && git diff --cached --quiet
if errorlevel 1 (
    echo.
    echo [AVISO] Tienes cambios sin guardar en esta carpeta:
    git status --short | findstr /r "^.[MADRC?]" | more
    echo.
    echo   Si son tuyos y los quieres, pulsa Ctrl+C y ejecuta SUBIR_A_GITHUB.cmd primero.
    echo   Si es basura, sigue: se guardan aparte ^(git stash^) y se pueden recuperar con "git stash pop".
    pause
    git stash push -u -q -m "BAJAR_DE_GITHUB %DATE% %TIME%"
)

echo Trayendo lo ultimo de GitHub...
git pull --rebase origin main
if errorlevel 1 (
    echo.
    echo [PARADO] Conflictos al traer cambios. Abre los archivos marcados "CONFLICT", deja la version
    echo          buena y luego:  git add -A  ^&  git rebase --continue.  Para deshacer: git rebase --abort
    goto :fin
)
echo.
echo [OK] Carpeta de trabajo al dia. Abre Godot desde "%CARPETA%".
goto :fin

:fallo
echo.
echo [X] Algo fallo. El mensaje de git esta justo arriba.

:fin
echo.
pause
endlocal
