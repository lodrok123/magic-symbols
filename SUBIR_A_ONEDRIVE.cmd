@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
rem ============================================================================
rem  SUBIR_A_ONEDRIVE.cmd  --  copia la carpeta de trabajo (Documents) a OneDrive
rem
rem  Se lanza AL TERMINAR de trabajar. OneDrive es la copia que viaja entre
rem  ordenadores; Documents es la unica en la que se trabaja.
rem
rem  Pestillo: si el OTRO ordenador subio despues de tu ultima bajada, se niega
rem  (si no, pisarias su trabajo). Baja primero (BAJAR_DE_ONEDRIVE.cmd) o fuerza
rem  con:  SUBIR_A_ONEDRIVE.cmd /f
rem ============================================================================

set "ORIGEN=%USERPROFILE%\Documents\magic-symbols"
set "DESTINO=%OneDrive%\Documentos\magic-symbols"
set "EXCLUIR_DIRS=.godot .git pipeline_output _to_delete"
set "EXCLUIR_FICH=ULTIMA_BAJADA.txt *.tmp *.bak Thumbs.db desktop.ini"

if "%OneDrive%"=="" (
    echo [ERROR] La variable OneDrive no existe: OneDrive no esta instalado o no ha iniciado sesion.
    goto :fin
)

rem --- guardas: la carpeta de trabajo NUNCA puede estar dentro de OneDrive -----
rem     (si Windows tiene activada "Copia de seguridad de carpetas", Documents ES
rem     OneDrive y este script copiaria la carpeta sobre si misma)
set "DOCS_CMP=%USERPROFILE%\Documents\magic-symbols"
echo %DOCS_CMP% | find /i "%OneDrive%" >nul && (
    echo [PARADO] La carpeta Documents de este ordenador esta dentro de OneDrive:
    echo          %DOCS_CMP%
    echo          Desactiva "Copia de seguridad de carpetas > Documentos" en OneDrive, o
    echo          cambia ORIGEN/DESTINO en este script a una carpeta fuera de OneDrive.
    goto :fin
)
if /i "%ORIGEN%"=="%DESTINO%" (echo [PARADO] Origen y destino son la misma carpeta. & goto :fin)
if not exist "%ORIGEN%\project.godot" (
    echo [ERROR] No encuentro el proyecto en "%ORIGEN%".
    goto :fin
)
if not exist "%DESTINO%" mkdir "%DESTINO%"

rem --- fecha ISO (ordenable como texto) ---
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format s"') do set "AHORA=%%i"

rem --- pestillo ---
set "SUBIDA_REMOTA=" & set "BAJADA_LOCAL="
if exist "%DESTINO%\ULTIMA_SUBIDA.txt" set /p SUBIDA_REMOTA=<"%DESTINO%\ULTIMA_SUBIDA.txt"
if exist "%ORIGEN%\ULTIMA_BAJADA.txt" set /p BAJADA_LOCAL=<"%ORIGEN%\ULTIMA_BAJADA.txt"

if not "%SUBIDA_REMOTA%"=="" (
    for /f "tokens=1,2 delims=|" %%a in ("%SUBIDA_REMOTA%") do (set "REM_FECHA=%%a" & set "REM_PC=%%b")
    if /i not "!REM_PC!"=="%COMPUTERNAME%" (
        set "LOC_FECHA="
        for /f "tokens=1 delims=|" %%a in ("%BAJADA_LOCAL%") do set "LOC_FECHA=%%a"
        if "!LOC_FECHA!"=="" set "LOC_FECHA=0000"
        if "!REM_FECHA!" GTR "!LOC_FECHA!" (
            if /i not "%~1"=="/f" (
                echo.
                echo [PARADO] !REM_PC! subio a OneDrive el !REM_FECHA! y tu ultima bajada es de !LOC_FECHA!.
                echo          Si subes ahora pisas su trabajo. Ejecuta BAJAR_DE_ONEDRIVE.cmd primero,
                echo          o fuerza con:  SUBIR_A_ONEDRIVE.cmd /f
                goto :fin
            ) else (
                echo [AVISO] Forzando la subida por encima de lo que subio !REM_PC!.
            )
        )
    )
)

rem --- Godot abierto: los .import y .uid pueden estar a medias ---
tasklist /fi "imagename eq Godot*" 2>nul | find /i "Godot" >nul && (
    echo [AVISO] Godot esta abierto. Cierralo antes de subir para no copiar archivos a medias.
    pause
)

echo.
echo Subiendo "%ORIGEN%"  -->  "%DESTINO%"
if not exist "%DESTINO%\" mkdir "%DESTINO%"
robocopy "%ORIGEN%" "%DESTINO%" /E /PURGE /COPY:DT /DCOPY:T /XJ /R:2 /W:2 /FFT /NFL /NDL /NP /XD %EXCLUIR_DIRS% /XF %EXCLUIR_FICH%
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 (
    echo [ERROR] robocopy devolvio %RC%: algo no se copio. Revisa arriba.
    goto :fin
)

rem --- marcadores: OneDrive sabe quien subio; local sabe que esta al dia ---
>"%DESTINO%\ULTIMA_SUBIDA.txt" echo %AHORA%^|%COMPUTERNAME%
>"%ORIGEN%\ULTIMA_BAJADA.txt"  echo %AHORA%^|%COMPUTERNAME%
echo.
echo [OK] Subido el %AHORA% desde %COMPUTERNAME%. Espera a que el icono de OneDrive este en verde
echo      antes de bajar en el otro ordenador.

:fin
echo.
pause
endlocal
