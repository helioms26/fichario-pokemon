@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\atualizar_precos.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\publicar.ps1" -Mensagem "precos"
echo.
pause
