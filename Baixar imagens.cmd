@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\baixar_imagens.ps1"
echo.
pause
