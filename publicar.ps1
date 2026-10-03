# Publica o fichário (app + dados de cartas + histórico de preços) no GitHub Pages. Imagens e coleção ficam de fora (.gitignore).
param([string]$Mensagem = "atualização")
$ErrorActionPreference = "Continue"
$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
Set-Location $base
if (-not (Test-Path ".git")) { git init -b main | Out-Null; git remote add origin https://github.com/helioms26/fichario-pokemon.git }
git add -A | Out-Null
$st = git status --porcelain
if (-not $st) { Write-Host "[publicar] nada novo para publicar."; exit 0 }
git -c user.name="Fichario" -c user.email="fichario@local" commit -q -m "$Mensagem $(Get-Date -Format 'dd/MM/yyyy HH:mm')" | Out-Null
Write-Host "[publicar] enviando ao GitHub (se abrir uma janela de login do GitHub, autorize)..."
git push -u origin main 2>&1 | ForEach-Object { "  $_" }
if ($LASTEXITCODE -eq 0) { Write-Host "[publicar] publicado. O site atualiza em ~1 minuto: https://helioms26.github.io/fichario-pokemon/" } else { Write-Host "[publicar] falhou ao enviar (código $LASTEXITCODE). Tente de novo ou abra o GitHub Desktop." }