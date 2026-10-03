# Atualiza o histórico de preços (fonte: Deck Certo, mercado BR, versão Normal).
# Uso: atualizar_precos.ps1 [-Set CRI|PRE|ALL]   (padrão ALL)
# Gera/atualiza data\historico-precos-<SET>.json (fonte da verdade) e .js (lido pelo fichário). CRI também grava os nomes antigos (historico-precos.*).
param([string]$Set = "ALL")
$ErrorActionPreference = "Stop"
$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$utf8 = New-Object Text.UTF8Encoding($false)
$fontes = @{
  "CRI" = "https://deckcerto.com/pokemon-tcg/todas-cartas-caos-ascendente/"
  "PRE" = "https://deckcerto.com/pokemon-tcg/todas-cartas-escarlate-e-violeta-evolucoes-prismaticas/"
}
$hoje = (Get-Date).ToString("yyyy-MM-dd")
$lista = if ($Set -eq "ALL") { @($fontes.Keys | Sort-Object) } else { @($Set.ToUpper()) }
foreach ($id in $lista) {
  if (-not $fontes.ContainsKey($id)) { Write-Host "Set desconhecido: $id"; continue }
  $url = $fontes[$id]
  $jsonPath = Join-Path $base "data\historico-precos-$id.json"
  $jsPath   = Join-Path $base "data\historico-precos-$id.js"
  if ($id -eq "CRI" -and -not (Test-Path $jsonPath) -and (Test-Path (Join-Path $base "data\historico-precos.json"))) { $jsonPath = Join-Path $base "data\historico-precos.json" }
  Write-Host "[$id] baixando $url ..."
  $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 90 -Headers @{ "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120"; "Accept"="text/html" }
  $h = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
  $cards = [regex]::Matches($h, '<button[^>]*class="g-card"[^>]*>')
  if ($cards.Count -lt 100) { throw "[$id] só encontrei $($cards.Count) cartas; a estrutura do site pode ter mudado." }
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
    if (-not $hist[$key].serie.Contains($hoje)) { $novos++ }; $hist[$key].serie[$hoje]=$preco
  }
  $out=[ordered]@{ fonte="Deck Certo (mercado BR, versão Normal)"; set=$id; atualizadoEm=$hoje; cartas=[ordered]@{} }
  foreach ($k in ($hist.Keys | Sort-Object)) { $s=[ordered]@{}; foreach ($d in ($hist[$k].serie.Keys | Sort-Object)) { $s[$d]=$hist[$k].serie[$d] }; $out.cartas[$k]=[ordered]@{ nome=$hist[$k].nome; serie=$s } }
  $json = $out | ConvertTo-Json -Depth 6 -Compress
  [IO.File]::WriteAllText((Join-Path $base "data\historico-precos-$id.json"), $json, $utf8)
  [IO.File]::WriteAllText($jsPath, "window.HISTORICO_$id = $json;", $utf8)
  if ($id -eq "CRI") { [IO.File]::WriteAllText((Join-Path $base "data\historico-precos.json"), $json, $utf8); [IO.File]::WriteAllText((Join-Path $base "data\historico-precos.js"), "window.HISTORICO_CRI = $json; window.HISTORICO = window.HISTORICO_CRI;", $utf8) }
  $lim=(Get-Date).AddDays(-15).ToString("yyyy-MM-dd"); $mov=@()
  foreach ($k in $out.cartas.Keys) { $s=$out.cartas[$k].serie; $ds=@($s.Keys); $ant=$null; foreach ($d in $ds) { if ($d -le $lim) { $ant=$s[$d] } }; if ($null -eq $ant) { $ant=$s[$ds[0]] }; $atual=$s[$ds[-1]]
    if ($ant -ge 2 -and $atual -gt 0) { $mov += [pscustomobject]@{ n=$k; nome=$out.cartas[$k].nome; de=$ant; para=$atual; var=[math]::Round(100*($atual-$ant)/$ant,1) } } }
  Write-Host "[$id] Histórico salvo: $($out.cartas.Count) cartas, $novos pontos novos. Datas: $(@($out.cartas[$out.cartas.Keys[0]].serie.Keys)[0]) a $hoje"
  Write-Host "[$id] Mais valorizadas (15 dias):"; $mov | Sort-Object var -Descending | Select-Object -First 5 | ForEach-Object { "  {0} {1}: R$ {2:N2} -> R$ {3:N2} ({4:+0.0;-0.0}%)" -f $_.n,$_.nome,$_.de,$_.para,$_.var }
  Write-Host "[$id] Mais desvalorizadas (15 dias):"; $mov | Sort-Object var | Select-Object -First 5 | ForEach-Object { "  {0} {1}: R$ {2:N2} -> R$ {3:N2} ({4:+0.0;-0.0}%)" -f $_.n,$_.nome,$_.de,$_.para,$_.var }
  Write-Host ""
}