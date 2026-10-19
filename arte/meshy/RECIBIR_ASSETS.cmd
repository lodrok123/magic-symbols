@echo off
rem Recepcion de objetos 3D (Pipeline). Uso:  RECIBIR_ASSETS.cmd ver entrada\hoja.glb
rem                                           RECIBIR_ASSETS.cmd lote entrada\hoja.glb
rem                                           RECIBIR_ASSETS.cmd instalar <lote> [--solo id,id]
rem Necesita Python con numpy, scipy y Pillow (si no, se ejecuta en el entorno de Claude: en el chat basta "hay nuevos").
cd /d "%~dp0"
python recibir_assets.py %*
pause
