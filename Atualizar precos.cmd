@echo off
cd /d "%~dp0"
echo  Deck Certo (serie automatica, estimativa): lendo agora os 4 sets...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\atualizar_precos_deckcerto.ps1"
echo.
echo  LigaPokemon (referencia de negociacao): a Liga bloqueia a leitura automatica desde out/2026.
echo  Para atualizar: abra o fichario pelo "Abrir Fichario.cmd", clique em "Atualizar precos" e use o favorito
echo  "Enviar precos ao fichario" na pagina da Liga aberta no seu Chrome.
echo.
pause
