@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
rem ============================================================================
rem  BAJAR_DE_ONEDRIVE.cmd  --  trae la copia de OneDrive a la carpeta de trabajo
rem
rem  Se lanza AL EMPEZAR a trabajar en un ordenador. Antes, comprueba que el
rem  icono de OneDrive esta en verde (sincronizado): si baja a medias, Godot
rem  vera archivos que faltan.
rem
rem  Aviso: si tienes archivos locales MAS NUEVOS que los de OneDrive (trabajaste
rem  y no subiste), te lo dice y te deja elegir. Lo que no subiste se pierde al
rem  bajar: OneDrive manda.
rem ============================================================================

set "ORIGEN=%OneDrive%\Documentos\magic-symbols"
set "DESTINO=%USERPROFILE%\Documents\magic-symbols"
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
    echo [ERROR] No encuentro el proyecto en "%ORIGEN%". ^(Si OneDrive aun sincroniza, espera.^)
    goto :fin
)

rem --- Godot abierto sobre la carpeta de trabajo ---
tasklist /fi "imagename eq Godot*" 2>nul | find /i "Godot" >nul && (
    echo [PARADO] Godot esta abierto. Cierralo antes de bajar: sobrescribir el proyecto con el editor
    echo          abierto corrompe la cache y los .import.
    goto :fin
)

rem --- quien subio por ultima vez ---
set "SUBIDA_REMOTA=desconocida"
if exist "%ORIGEN%\ULTIMA_SUBIDA.txt" set /p SUBIDA_REMOTA=<"%ORIGEN%\ULTIMA_SUBIDA.txt"
echo Ultima subida a OneDrive: %SUBIDA_REMOTA%

rem --- archivos locales mas nuevos que OneDrive (trabajo sin subir) ---
if exist "%DESTINO%\project.godot" (
    set "N=0"
    for /f "tokens=*" %%l in ('robocopy "%DESTINO%" "%ORIGEN%" /L /E /XO /COPY:DT /DCOPY:T /NJH /NJS /NDL /NP /NS /NC /FFT /XD %EXCLUIR_DIRS% /XF %EXCLUIR_FICH% 2^>nul ^| findstr /r /c:"[^ ]"') do set /a N+=1
    if !N! GTR 0 (
        echo.
        echo [AVISO] Tienes !N! archivo^(s^) locales MAS NUEVOS que OneDrive. Si bajas, se pierden.
        echo         Lista ^(primeros 20^):
        set "K=0"
        for /f "tokens=*" %%l in ('robocopy "%DESTINO%" "%ORIGEN%" /L /E /XO /COPY:DT /DCOPY:T /NJH /NJS /NDL /NP /NS /NC /FFT /XD %EXCLUIR_DIRS% /XF %EXCLUIR_FICH% 2^>nul ^| findstr /r /c:"[^ ]"') do (
            set /a K+=1
            if !K! LEQ 20 echo           %%l
        )
        echo.
        echo   Si ese trabajo es tuyo y lo quieres, pulsa Ctrl+C y ejecuta SUBIR_A_ONEDRIVE.cmd /f
        echo   Si es basura ^(cache, pruebas^), sigue.
        pause
    )
)

echo.
echo Bajando "%ORIGEN%"  -->  "%DESTINO%"
rem --- la carpeta destino la crea este script, no robocopy: con un origen en OneDrive,
rem     robocopy intenta clonar el atributo de "punto de reanalisis" de la raiz, deja un
rem     stub de 64 bytes que no es carpeta y falla con ERROR 267.
if exist "%DESTINO%" if not exist "%DESTINO%\" (
    echo [AVISO] "%DESTINO%" existe como archivo, no como carpeta: lo quito.
    del /f /q "%DESTINO%" 2>nul
    if exist "%DESTINO%" rmdir "%DESTINO%" 2>nul
)
if not exist "%DESTINO%\" mkdir "%DESTINO%"
if not exist "%DESTINO%\" (
    echo [ERROR] No he podido crear la carpeta "%DESTINO%".
    goto :fin
)
robocopy "%ORIGEN%" "%DESTINO%" /E /PURGE /COPY:DT /DCOPY:T /XJ /R:2 /W:2 /FFT /NFL /NDL /NP /XD %EXCLUIR_DIRS% /XF %EXCLUIR_FICH%
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 (
    echo [ERROR] robocopy devolvio %RC%: algo no se copio. Revisa arriba. ^(Archivos "solo en la nube"?^)
    goto :fin
)

>"%DESTINO%\ULTIMA_BAJADA.txt" echo %SUBIDA_REMOTA%
echo.
echo [OK] Carpeta de trabajo al dia con OneDrive ^(%SUBIDA_REMOTA%^).
echo      Abre Godot desde "%DESTINO%": la primera vez reimporta ^(.godot no viaja^).

:fin
echo.
pause
endlocal
