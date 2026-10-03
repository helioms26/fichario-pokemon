@echo off
cd /d "%~dp0"
rem Se o servidor j? estiver rodando, s? abre o navegador
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri http://localhost:8765/api/status -UseBasicParsing -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
if %errorlevel%==0 (
  start "" http://localhost:8765/
  exit
)
title Meu Fichario - servidor local
powershell -NoProfile -ExecutionPolicy Bypass -File ".\servidor.ps1"
pause
