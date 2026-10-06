@echo off
cd /d "%~dp0.."
set LOG=pipeline_output\arte_QA\noche_log.txt
echo === INICIO %date% %time% === > "%LOG%"
echo [%time%] hero ... & echo [%time%] hero >> "%LOG%"
call pipeline\PROCESAR.cmd rapido hero todas >> "%LOG%" 2>&1
echo    fin hero (codigo %errorlevel%) >> "%LOG%"
echo [%time%] goblin_archer ... & echo [%time%] goblin_archer >> "%LOG%"
call pipeline\PROCESAR.cmd rapido goblin_archer todas >> "%LOG%" 2>&1
echo    fin goblin_archer (codigo %errorlevel%) >> "%LOG%"
echo [%time%] goblin_warrior ... & echo [%time%] goblin_warrior >> "%LOG%"
call pipeline\PROCESAR.cmd rapido goblin_warrior todas >> "%LOG%" 2>&1
echo    fin goblin_warrior (codigo %errorlevel%) >> "%LOG%"
echo [%time%] bookseller_woman ... & echo [%time%] bookseller_woman >> "%LOG%"
call pipeline\PROCESAR.cmd rapido bookseller_woman todas >> "%LOG%" 2>&1
echo    fin bookseller_woman (codigo %errorlevel%) >> "%LOG%"
echo [%time%] ranger_human ... & echo [%time%] ranger_human >> "%LOG%"
call pipeline\PROCESAR.cmd rapido ranger_human todas >> "%LOG%" 2>&1
echo    fin ranger_human (codigo %errorlevel%) >> "%LOG%"
echo [%time%] master_elf ... & echo [%time%] master_elf >> "%LOG%"
call pipeline\PROCESAR.cmd rapido master_elf todas >> "%LOG%" 2>&1
echo    fin master_elf (codigo %errorlevel%) >> "%LOG%"
echo === FIN %date% %time% === >> "%LOG%"
echo Terminado. Log en %LOG%
pause
