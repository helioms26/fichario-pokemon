# Servidor local do fichário — só responde em http://localhost:8765 (não é acessível de fora do seu PC).
# Serve os arquivos da pasta, grava data\colecao.json (POST /api/salvar) e roda a atualização de preços (POST /api/atualizar-precos).
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
    if ($path -eq "/api/atualizar-precos" -and $method -eq "POST") {
      Write-Host ("[{0}] atualizando preços..." -f (Get-Date).ToString("HH:mm:ss"))
      $qs = [System.Web.HttpUtility]::ParseQueryString($ctx.Request.Url.Query); $setq = $qs["set"]; if (-not $setq) { $setq = "ALL" }; if ($setq -notmatch "^[A-Z]{3}$" -and $setq -ne "ALL") { $setq = "ALL" }
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
