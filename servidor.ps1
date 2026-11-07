# Servidor local do fichário — só responde em http://localhost:8765 (não é acessível de fora do seu PC).
# Serve os arquivos da pasta, grava data\colecao.json (POST /api/salvar), recebe os preços da página da Liga aberta pelo usuário
# (POST /api/importar-precos?set=XXX, chamado pelo favorito "Enviar preços ao fichário" ou pelo painel colar), informa a situação dos
# históricos (GET /api/precos-status), atualiza a série automática do Deck Certo (POST /api/atualizar-deckcerto) e publica no GitHub Pages (POST /api/publicar). /api/atualizar-precos (Chrome oculto) ficou
# apenas por compatibilidade — a Liga bloqueia esse modo desde out/2026.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web
$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$port = 8765
$url  = "http://localhost:$port/"
$utf8 = New-Object Text.UTF8Encoding($false)

$mime = @{ ".html"="text/html; charset=utf-8"; ".js"="text/javascript; charset=utf-8"; ".json"="application/json; charset=utf-8"; ".css"="text/css"; ".webp"="image/webp"; ".png"="image/png"; ".jpg"="image/jpeg"; ".svg"="image/svg+xml"; ".md"="text/plain; charset=utf-8"; ".ico"="image/x-icon" }

function Send-Text($ctx, $code, $text, $type="application/json; charset=utf-8") {
  $b = $utf8.GetBytes($text); $ctx.Response.StatusCode = $code; $ctx.Response.ContentType = $type
  $ctx.Response.ContentLength64 = $b.Length; $ctx.Response.OutputStream.Write($b, 0, $b.Length); $ctx.Response.OutputStream.Close()
}
# Permite que o favorito, rodando na página da Liga, envie os preços para cá (CORS). Só origens da Liga e do próprio localhost.
function Add-Cors($ctx) {
  $origin = $ctx.Request.Headers["Origin"]
  if ($origin -and ($origin -match "^https://(www\.)?ligapokemon\.com\.br$" -or $origin -match "^https?://(localhost|127\.0\.0\.1)(:\d+)?$")) {
    $ctx.Response.Headers["Access-Control-Allow-Origin"] = $origin
    $ctx.Response.Headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    $ctx.Response.Headers["Access-Control-Allow-Headers"] = "Content-Type"
    $ctx.Response.Headers["Access-Control-Allow-Private-Network"] = "true"   # Chrome/Edge exigem isto para um site público falar com localhost
    $ctx.Response.Headers["Access-Control-Allow-Local-Network"] = "true"
    $ctx.Response.Headers["Vary"] = "Origin"
  }
}
function Read-Body($ctx) { $sr = New-Object IO.StreamReader($ctx.Request.InputStream, $utf8); $t = $sr.ReadToEnd(); $sr.Close(); return $t }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
try { $listener.Start() } catch { Write-Host "Não consegui abrir a porta $port (já está em uso?). Se o fichário já estiver aberto em outra janela, use ela."; Start-Sleep 5; exit 1 }

Write-Host ""
Write-Host "  Meu Fichário rodando em $url"
Write-Host "  Pasta: $base"
Write-Host "  Feche esta janela para encerrar. (As marcações já estão salvas em data\colecao.json)"
Write-Host ""
Start-Process $url
# Deck Certo (série automática, estimativa): ao abrir o fichário, atualiza em segundo plano se o dado de hoje ainda não foi lido.
try {
  $dcJs = Join-Path $base "data\historico-precos-deckcerto-CRI.json"
  $precisa = -not (Test-Path $dcJs) -or ((Get-Item $dcJs).LastWriteTime.Date -lt (Get-Date).Date)
  if ($precisa) {
    Write-Host "  Deck Certo: atualizando a série automática em segundo plano..."
    Start-Process -WindowStyle Hidden -FilePath "powershell" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $base "atualizar_precos_deckcerto.ps1")) | Out-Null
  } else { Write-Host "  Deck Certo: já lido hoje." }
} catch { Write-Host "  Deck Certo: não consegui iniciar a atualização automática ($($_.Exception.Message))" }

while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    $method = $ctx.Request.HttpMethod
    if ($path -eq "/api/status") { Send-Text $ctx 200 '{"ok":true,"server":true}'; continue }
    if ($path -eq "/api/salvar" -and $method -eq "POST") {
      $body = Read-Body $ctx
      try { $null = $body | ConvertFrom-Json } catch { Send-Text $ctx 400 '{"ok":false,"erro":"JSON inválido"}'; continue }
      New-Item -ItemType Directory -Force -Path (Join-Path $base "data") | Out-Null
      [IO.File]::WriteAllText((Join-Path $base "data\colecao.json"), $body, $utf8)
      [IO.File]::WriteAllText((Join-Path $base "data\colecao.js"), "window.COLECAO = $body;", $utf8)
      Send-Text $ctx 200 ('{"ok":true,"quando":"' + (Get-Date).ToString("HH:mm:ss") + '"}')
      Write-Host ("[{0}] coleção salva" -f (Get-Date).ToString("HH:mm:ss")); continue
    }
    if ($path -like "/api/*" -and $method -eq "OPTIONS") { Add-Cors $ctx; $ctx.Response.StatusCode = 204; $ctx.Response.OutputStream.Close(); continue }
    if ($path -eq "/api/precos-status" -and $method -eq "GET") {
      Add-Cors $ctx
      $st = [ordered]@{}
      foreach ($id in @("CRI","PRE","MEG","30C","DEL")) {
        $f = Join-Path $base "data\historico-precos-$id.json"
        if (Test-Path $f) { $raw = [IO.File]::ReadAllText($f, $utf8); $st[$id] = [ordered]@{ atualizadoEm = [regex]::Match($raw, '"atualizadoEm":"([^"]*)"').Groups[1].Value; cartas = ([regex]::Matches($raw, '"nome":')).Count } }
        else { $st[$id] = $null }
      }
      Send-Text $ctx 200 ($st | ConvertTo-Json -Compress); continue
    }
    if ($path -eq "/api/importar-precos" -and $method -eq "POST") {
      Add-Cors $ctx
      $qs = [System.Web.HttpUtility]::ParseQueryString($ctx.Request.Url.Query); $setq = "$($qs["set"])".ToUpper(); if ($setq -eq "DLR") { $setq = "DEL" }
      if ($setq -notmatch "^[A-Z0-9]{3}$") { Send-Text $ctx 400 '{"ok":false,"erro":"informe ?set=CRI|PRE|MEG|30C|DEL"}'; continue }
      $body = Read-Body $ctx
      try { $arr = $body | ConvertFrom-Json } catch { Send-Text $ctx 400 '{"ok":false,"erro":"JSON inválido — copie o texto inteiro"}'; continue }
      if (-not ($arr -is [array]) -or $arr.Count -lt 50 -or -not $arr[0].PSObject.Properties["sN"] -or -not $arr[0].PSObject.Properties["p1a"]) { Send-Text $ctx 400 '{"ok":false,"erro":"não parece a lista de cartas da Liga (esperado: array com sN e p1a)"}'; continue }
      Write-Host ("[{0}] recebendo preços de {1} ({2} cartas)..." -f (Get-Date).ToString("HH:mm:ss"), $setq, $arr.Count)
      $ent = Join-Path $base "data\_entrada-precos-$setq.json"
      [IO.File]::WriteAllText($ent, $body, $utf8)
      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $base "atualizar_precos.ps1") -Set $setq -Entrada $ent 2>&1 | Out-String
      $okp = $LASTEXITCODE -eq 0 -and $out -match "pontos novos"
      Remove-Item $ent -ErrorAction SilentlyContinue
      $json = @{ ok = $okp; set = $setq; cartas = $arr.Count; saida = $out } | ConvertTo-Json -Compress
      Send-Text $ctx 200 $json; Write-Host $out; continue
    }
    if ($path -eq "/api/publicar" -and $method -eq "POST") {
      Write-Host ("[{0}] publicando no GitHub Pages..." -f (Get-Date).ToString("HH:mm:ss"))
      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $base "publicar.ps1") -Mensagem "precos" 2>&1 | Out-String
      $okp = $out -match "publicado|nada novo"
      Send-Text $ctx 200 (@{ ok = $okp; saida = $out } | ConvertTo-Json -Compress); Write-Host $out; continue
    }
    if ($path -eq "/api/atualizar-deckcerto" -and $method -eq "POST") {
      Write-Host ("[{0}] Deck Certo: atualizando..." -f (Get-Date).ToString("HH:mm:ss"))
      $qs = [System.Web.HttpUtility]::ParseQueryString($ctx.Request.Url.Query); $setq = $qs["set"]; if (-not $setq) { $setq = "ALL" }; if ($setq -notmatch "^[A-Z0-9]{3}$" -and $setq -ne "ALL") { $setq = "ALL" }
      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $base "atualizar_precos_deckcerto.ps1") -Set $setq 2>&1 | Out-String
      $okp = $LASTEXITCODE -eq 0 -and $out -match "Deck Certo salvo"
      Send-Text $ctx 200 (@{ ok = $okp; saida = $out } | ConvertTo-Json -Compress); Write-Host $out; continue
    }
    if ($path -eq "/api/atualizar-precos" -and $method -eq "POST") {
      Write-Host ("[{0}] atualizando preços..." -f (Get-Date).ToString("HH:mm:ss"))
      $qs = [System.Web.HttpUtility]::ParseQueryString($ctx.Request.Url.Query); $setq = $qs["set"]; if (-not $setq) { $setq = "ALL" }; if ($setq -notmatch "^[A-Z0-9]{3}$" -and $setq -ne "ALL") { $setq = "ALL" }
      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $base "atualizar_precos.ps1") -Set $setq 2>&1 | Out-String
      $okp = $LASTEXITCODE -eq 0 -and $out -match "Histórico salvo"
      $json = @{ ok = $okp; saida = $out } | ConvertTo-Json -Compress
      Send-Text $ctx 200 $json; Write-Host $out; continue
    }
    if ($method -ne "GET") { Send-Text $ctx 405 '{"ok":false}'; continue }
    if ($path -eq "/") { $path = "/index.html" }
    $full = [IO.Path]::GetFullPath((Join-Path $base ($path.TrimStart('/') -replace '/', '\')))
    if (-not $full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $full -PathType Leaf)) { Send-Text $ctx 404 "não encontrado" "text/plain"; continue }
    $ext = [IO.Path]::GetExtension($full).ToLower()
    $bytes = [IO.File]::ReadAllBytes($full)
    $ctx.Response.StatusCode = 200
    $ctx.Response.ContentType = $(if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" })
    $ctx.Response.Headers["Cache-Control"] = "no-cache"
    $ctx.Response.ContentLength64 = $bytes.Length; $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length); $ctx.Response.OutputStream.Close()
  } catch { try { Send-Text $ctx 500 ('{"ok":false,"erro":"' + ($_.Exception.Message -replace '"',"'") + '"}') } catch {} }
}
