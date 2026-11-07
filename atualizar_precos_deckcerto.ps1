# Deck Certo — série AUTOMÁTICA de preços (estimativa), separada da série da LigaPokémon.
# Uso: atualizar_precos_deckcerto.ps1 [-Set CRI|PRE|MEG|30C|DEL|ALL]   (padrão ALL)
# Grava data\historico-precos-deckcerto-<SET>.json (fonte da verdade) e .js (window.HISTORICO_DC_<SET>, lido pelo fichário).
# NUNCA escreve em historico-precos-<SET>.* — esses são da Liga (referência de negociação). O Deck Certo é agregador e, medido em
# set/2026 e nov/2026, fica ~13% abaixo do piso da Liga nos hits (e igual nas comuns); o fichário mostra isso explicitamente.
# O site expõe data-sparkline com o próprio histórico diário desde jul/2026: na primeira execução a série inteira é reconstruída.
param([string]$Set = "ALL")
$ErrorActionPreference = "Stop"
$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$utf8 = New-Object Text.UTF8Encoding($false)
$fontes = [ordered]@{
  "CRI" = "https://deckcerto.com/pokemon-tcg/todas-cartas-caos-ascendente/"
  "PRE" = "https://deckcerto.com/pokemon-tcg/todas-cartas-escarlate-e-violeta-evolucoes-prismaticas/"
  "MEG" = "https://deckcerto.com/pokemon-tcg/todas-cartas-megaevolucao/"
  "30C" = "https://deckcerto.com/pokemon-tcg/todas-cartas-celebracao-30-anos/"
  "DEL" = "https://deckcerto.com/pokemon-tcg/todas-cartas-reinado-delta/"
}
$hoje = (Get-Date).ToString("yyyy-MM-dd")
$lista = if ($Set -eq "ALL") { @($fontes.Keys) } else { @($Set.ToUpper()) }
$falhas = 0
foreach ($id in $lista) {
  if (-not $fontes.Contains($id)) { Write-Host "Set desconhecido: $id"; continue }
  try {
    $url = $fontes[$id]
    $jsonPath = Join-Path $base "data\historico-precos-deckcerto-$id.json"
    $jsPath   = Join-Path $base "data\historico-precos-deckcerto-$id.js"
    Write-Host "[$id] Deck Certo: baixando $url ..."
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 90 -Headers @{ "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120"; "Accept"="text/html" }
    $h = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
    $cards = [regex]::Matches($h, '<button[^>]*class="g-card"[^>]*>')
    if ($cards.Count -lt 50) { throw "só encontrei $($cards.Count) cartas; a estrutura do site pode ter mudado." }
    $dataSite = $hoje
    $md = [regex]::Match($h, '(\d{2}/\d{2}/\d{4})[\s\S]{0,160}?ltima atualiza')
    if ($md.Success) { $p = $md.Groups[1].Value.Split('/'); $dataSite = "$($p[2])-$($p[1])-$($p[0])" }
    $hist = [ordered]@{}
    if (Test-Path $jsonPath) {
      $old = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($p in $old.cartas.PSObject.Properties) { $serie=[ordered]@{}; foreach ($q in $p.Value.serie.PSObject.Properties) { $serie[$q.Name]=[double]$q.Value }; $hist[$p.Name]=[ordered]@{ nome=$p.Value.nome; serie=$serie } }
    }
    $novos = 0
    foreach ($c in $cards) {
      $t=$c.Value; $n=[int][regex]::Match($t,'data-numint="(\d+)"').Groups[1].Value; $nome=[System.Net.WebUtility]::HtmlDecode([regex]::Match($t,'data-name="([^"]*)"').Groups[1].Value)
      $preco=[double]([regex]::Match($t,'data-price="([\d\.]+)"').Groups[1].Value); $spk=[regex]::Match($t,"data-sparkline='([^']*)'").Groups[1].Value; $key="{0:000}" -f $n
      if (-not $hist.Contains($key)) { $hist[$key]=[ordered]@{ nome=$nome; serie=[ordered]@{} } }
      $hist[$key].nome=$nome
      foreach ($m in [regex]::Matches($spk,'\["(\d{4}-\d{2}-\d{2})",\s*([\d\.]+)\]')) { $d=$m.Groups[1].Value; $v=[double]$m.Groups[2].Value; if (-not $hist[$key].serie.Contains($d)) { $novos++ }; $hist[$key].serie[$d]=$v }
      if (-not $hist[$key].serie.Contains($dataSite)) { $novos++ }; $hist[$key].serie[$dataSite]=$preco
    }
    $out=[ordered]@{ fonte="Deck Certo (agregador BR; estimativa automática — costuma ficar ~13% abaixo do piso da Liga nos hits)"; set=$id; atualizadoEm=$dataSite; coletadoEm=$hoje; cartas=[ordered]@{} }
    foreach ($k in ($hist.Keys | Sort-Object)) { $s=[ordered]@{}; foreach ($d in ($hist[$k].serie.Keys | Sort-Object)) { $s[$d]=$hist[$k].serie[$d] }; $out.cartas[$k]=[ordered]@{ nome=$hist[$k].nome; serie=$s } }
    $json = $out | ConvertTo-Json -Depth 6 -Compress
    [IO.File]::WriteAllText($jsonPath, $json, $utf8)
    [IO.File]::WriteAllText($jsPath, "window.HISTORICO_DC_$id = $json;", $utf8)
    Write-Host "[$id] Deck Certo salvo: $($out.cartas.Count) cartas, $novos pontos novos, dado do site de $dataSite."
  } catch { $falhas++; Write-Host "[$id] FALHOU: $($_.Exception.Message)" }
}
if ($falhas -gt 0) { exit 1 }
