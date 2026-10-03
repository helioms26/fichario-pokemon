# Baixa as imagens do set que faltarem em img\<SET>\ (nomes de data\nomes-imagens-<SET>.json). Uso: baixar_imagens.ps1 [-Set CRI|PRE|ALL]
param([string]$Set = "ALL")
$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$fontes = @{ "CRI" = "https://deckcerto.com/wp-content/uploads/2026/05/carta-caos-ascendente-{n}-deck-certo.webp"; "PRE" = "https://deckcerto.com/wp-content/uploads/2026/05/carta-evolucoes-prismaticas-{n}-deck-certo.webp"; "MEG" = "https://deckcerto.com/wp-content/uploads/2026/07/carta-megaevolucao-{n}-deck-certo.webp"; "30C" = "{url}" }
$lista = if ($Set -eq "ALL") { @($fontes.Keys | Sort-Object) } else { @($Set.ToUpper()) }
foreach ($id in $lista) {
  $dir = Join-Path $base "img\$id"; New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $mapFile = Join-Path $base $(if ($id -eq "CRI") { "data\nomes-imagens.json" } else { "data\nomes-imagens-$id.json" })
  $map = Get-Content $mapFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $ok=0; $fail=@()
  foreach ($p in $map.PSObject.Properties) { $dest = Join-Path $dir "$($p.Value).webp"; if (Test-Path $dest) { $ok++; continue }
    $url = if ($fontes[$id] -eq "{url}") { $p.Value } else { $fontes[$id].Replace("{n}", $p.Name) }
    if ($fontes[$id] -eq "{url}") { $dest = Join-Path $dir "$($p.Name).webp"; if (Test-Path $dest) { $ok++; continue } }
    try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -Headers @{ "User-Agent"="Mozilla/5.0" } -TimeoutSec 30; $ok++ } catch { $fail += $p.Value } }
  Write-Host "[$id] Imagens ok: $ok / $($map.PSObject.Properties.Count)"; if ($fail.Count) { Write-Host "[$id] Falharam: $($fail -join ', ')" }
}