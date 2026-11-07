@echo off
cd /d "%~dp0"
echo Cria (ou atualiza) a tarefa do Windows "Fichario - Deck Certo" que le os precos do Deck Certo
echo todo dia as 07:40, sem voce precisar fazer nada (o PC precisa estar ligado; se estiver desligado, roda ao ligar).
echo.
schtasks /Create /F /TN "Fichario - Deck Certo" /SC DAILY /ST 07:40 /RL LIMITED ^
  /TR "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0atualizar_precos_deckcerto.ps1\""
if %errorlevel%==0 (
  echo.
  echo Tarefa criada. Ajustando para rodar assim que o PC ligar, se perdeu o horario...
  powershell -NoProfile -Command "$t=Get-ScheduledTask -TaskName 'Fichario - Deck Certo'; $t.Settings.StartWhenAvailable=$true; $t.Settings.ExecutionTimeLimit='PT10M'; Set-ScheduledTask -InputObject $t | Out-Null"
  echo Rodando uma vez agora para testar...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0atualizar_precos_deckcerto.ps1"
) else (
  echo.
  echo Nao consegui criar a tarefa. Tente clicar com o botao direito e "Executar como administrador".
)
echo.
pause
