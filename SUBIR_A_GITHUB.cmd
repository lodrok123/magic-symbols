@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
rem ============================================================================
rem  SUBIR_A_GITHUB.cmd  --  guarda el trabajo (commit) y lo sube (push)
rem
rem  Se lanza AL TERMINAR de trabajar. Orden: ignorados fuera del indice, add,
rem  commit, traer lo del otro ordenador (pull --rebase), push.
rem  Si el pull encuentra conflictos, se para y te dice que hacer.
rem ============================================================================

git --version >nul 2>&1 || (echo [ERROR] No encuentro git. Instalalo: https://git-scm.com/download/win & goto :fin)

rem --- .git perdido? (la bajada de OneDrive lo excluia) -> recuperarlo de OneDrive
if not exist ".git\HEAD" (
    if exist "%OneDrive%\Documentos\magic-symbols\.git\HEAD" (
        echo [AVISO] Esta carpeta no tiene .git; lo recupero de la copia de OneDrive.
        robocopy "%OneDrive%\Documentos\magic-symbols\.git" ".git" /E /COPY:DT /DCOPY:T /R:2 /W:2 /NFL /NDL /NJH /NJS /NP >nul
    ) else (
        echo [ERROR] Esta carpeta no es un repositorio git y no hay copia de .git en OneDrive.
        echo         Usa BAJAR_DE_GITHUB.cmd para clonar de nuevo.
        goto :fin
    )
)

tasklist /fi "imagename eq Godot*" 2>nul | find /i "Godot" >nul && (
    echo [AVISO] Godot esta abierto: guarda todo en el editor antes de seguir.
    pause
)

rem --- lo que el .gitignore excluye pero ya estaba versionado, fuera del indice ---
set "QUITADOS=0"
for /f "delims=" %%f in ('git ls-files -ci --exclude-standard') do (
    git rm --cached -q "%%f" && set /a QUITADOS+=1
)
if !QUITADOS! GTR 0 echo [ok] !QUITADOS! archivo^(s^) ignorados sacados del repositorio ^(siguen en disco^).

rem --- archivos de mas de 95 MB que SI estarian en el commit: GitHub los rechaza ---
set "GRANDES=0"
for /f "delims=" %%f in ('git ls-files -co --exclude-standard') do (
    if exist "%%f" (
        for %%s in ("%%f") do if %%~zs GTR 99000000 (
            echo [PARADO] "%%f" pesa mas de 95 MB: GitHub lo rechaza. Anadelo a .gitignore.
            set /a GRANDES+=1
        )
    )
)
if !GRANDES! GTR 0 goto :fin

git add -A
git diff --cached --quiet
if errorlevel 1 (
    set "MSG="
    set /p MSG="Que has hecho? (Enter = fecha y ordenador): "
    if "!MSG!"=="" for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format s"') do set "MSG=Trabajo del %%i en %COMPUTERNAME%"
    git commit -q -m "!MSG!" || goto :fallo
    echo [ok] Commit: !MSG!
) else (
    echo [ok] No habia cambios nuevos que guardar.
)

echo.
echo Trayendo lo que haya subido el otro ordenador...
git pull --rebase origin main
if errorlevel 1 (
    echo.
    echo [PARADO] El pull ha encontrado conflictos. Son archivos que cambiaron en los dos ordenadores.
    echo          Abre los que marque "CONFLICT", deja la version buena, y luego:
    echo              git add -A
    echo              git rebase --continue
    echo          y vuelve a ejecutar este script. Para deshacerlo todo: git rebase --abort
    goto :fin
)

echo Subiendo...
git push -u origin main || goto :fallo_push
echo.
echo [OK] Subido. En el otro ordenador: BAJAR_DE_GITHUB.cmd
goto :fin

:fallo_push
echo.
echo [X] El push ha fallado. Si el mensaje de arriba habla de "file size limit" o "larger than 100 MB",
echo     hay un archivo grande en un commit ANTIGUO: no basta con ignorarlo. Avisa y lo limpiamos del
echo     historial con git filter-repo. Si habla de "rejected" o "non-fast-forward", ejecuta el script otra vez.
goto :fin

:fallo
echo.
echo [X] Algo fallo. El mensaje de git esta justo arriba.

:fin
echo.
pause
endlocal
