@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0.."

echo ===============================================
echo   Magic Symbols  ^|  subida a GitHub
echo ===============================================
echo.
echo Carpeta: %CD%
echo.

REM --- 1. Esta git instalado? -------------------------------------------
git --version >nul 2>&1
if errorlevel 1 (
    echo [X] No encuentro git en este ordenador.
    echo.
    echo     Instalalo desde https://git-scm.com/download/win
    echo     Deja todas las opciones por defecto y vuelve a ejecutar
    echo     este archivo.
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('git --version') do echo [ok] %%v

REM --- 2. Quien firma los commits? --------------------------------------
REM Sin nombre y correo configurados, "git commit" falla con un error
REM que no dice gran cosa. Mejor preguntarlo ahora.
for /f "tokens=*" %%n in ('git config --global user.name 2^>nul') do set GITNAME=%%n
if "!GITNAME!"=="" (
    echo.
    echo Git todavia no sabe quien eres.
    set /p GITNAME="   Tu nombre: "
    set /p GITMAIL="   Tu correo de GitHub: "
    git config --global user.name "!GITNAME!"
    git config --global user.email "!GITMAIL!"
    echo [ok] Guardado.
) else (
    echo [ok] Firmaras como: !GITNAME!
)

REM --- 3. Repositorio local ---------------------------------------------
echo.
if exist ".git" (
    echo [ok] Ya habia un repositorio aqui.
) else (
    git init -b main >nul
    if errorlevel 1 (
        REM Git antiguo: -b no existe hasta la version 2.28
        git init >nul
        git checkout -b main >nul 2>&1
    )
    echo [ok] Repositorio creado.
)

echo.
echo Anadiendo archivos...
git add -A
if errorlevel 1 goto :fallo

git diff --cached --quiet
if errorlevel 1 (
    git commit -m "Magic Symbols: runas de rayo, hielo y tiempo" >nul
    if errorlevel 1 goto :fallo
    echo [ok] Commit hecho.
) else (
    echo [ok] No habia cambios nuevos que guardar.
)

REM --- 4. Subida ---------------------------------------------------------
echo.
git remote get-url origin >nul 2>&1
if not errorlevel 1 (
    echo Ya hay un remoto configurado. Subiendo...
    git push -u origin main
    if errorlevel 1 goto :fallo_push
    goto :hecho
)

REM Sin remoto todavia: probamos con el CLI de GitHub, que crea el repo
REM y lo sube de una vez.
gh --version >nul 2>&1
if errorlevel 1 goto :sin_gh

gh auth status >nul 2>&1
if errorlevel 1 (
    echo Necesitas identificarte en GitHub una sola vez.
    echo Se abrira el navegador; yo no veo ni toco tus credenciales.
    echo.
    gh auth login
    if errorlevel 1 goto :fallo
)

echo.
echo Creando el repositorio PRIVADO 'magic-symbols' y subiendo...
gh repo create magic-symbols --private --source=. --remote=origin --push
if errorlevel 1 goto :fallo
goto :hecho

:sin_gh
echo -----------------------------------------------
echo  Falta el paso final: crear el repo en GitHub.
echo -----------------------------------------------
echo.
echo  Opcion A (mas comoda): instala el CLI de GitHub
echo     https://cli.github.com
echo     y vuelve a ejecutar este archivo. Se encarga de todo.
echo.
echo  Opcion B (a mano):
echo     1. Entra en https://github.com/new
echo     2. Nombre: magic-symbols
echo     3. NO marques "Add a README" ni ".gitignore":
echo        ya los tienes, y chocarian con lo que acabas de guardar.
echo     4. Copia la URL que te da y ejecuta aqui:
echo.
echo        git remote add origin https://github.com/TU_USUARIO/magic-symbols.git
echo        git push -u origin main
echo.
pause
exit /b 0

:fallo_push
echo.
echo [X] La subida fallo. Lo mas comun es que el repositorio remoto
echo     tenga commits que tu no tienes. Prueba con:
echo         git pull --rebase origin main
echo         git push -u origin main
echo.
pause
exit /b 1

:fallo
echo.
echo [X] Algo fallo en el paso anterior. El mensaje de git esta justo
echo     arriba; copialo tal cual si quieres que le echemos un ojo.
echo.
pause
exit /b 1

:hecho
echo.
echo ===============================================
echo   Listo. El proyecto esta en GitHub.
echo ===============================================
echo.
echo En el otro ordenador:
echo    1. Instala Godot 4.7
echo    2. git clone  (la URL de tu repo)
echo    3. Abre la carpeta desde el gestor de proyectos de Godot
echo.
echo La primera apertura tarda: Godot reconstruye la cache de
echo importacion. Es normal y solo pasa una vez.
echo.
pause
