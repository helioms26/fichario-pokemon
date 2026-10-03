# Atualiza o histórico de preços a partir da LigaPokémon (marketplace), usando o Chrome da máquina em modo oculto.
# Uso: atualizar_precos.ps1 [-Set CRI|PRE|ALL]   (padrão ALL)
# Grava data\historico-precos-<SET>.json (fonte da verdade) e .js (lido pelo fichário).
#   serie = menor preço (piso) por data · med / max = preço médio e maior anunciado por data.
# Pontos antigos nunca são apagados. O histórico anterior a 18/09/2026 veio do Deck Certo, que acompanhava o piso da Liga.
param([string]$Set = "ALL")
$ErrorActionPreference = "Stop"
$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$utf8 = New-Object Text.UTF8Encoding($false)
$chrome = @("C:\Program Files\Google\Chrome\Application\chrome.exe","C:\Program Files (x86)\Google\Chrome\Application\chrome.exe","C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) { throw "Não encontrei o Chrome/Edge para abrir a LigaPokémon." }
$siglas = @{ "CRI"="edid=773 ed=CRI"; "PRE"="edid=649 ed=PRE"; "MEG"="edid=730 ed=MEG"; "30C"="edid=804 ed=30C" }   # id da edição na Liga + sigla
$hoje = (Get-Date).ToString("yyyy-MM-dd")
$lista = if ($Set -eq "ALL") { @($siglas.Keys | Sort-Object) } else { @($Set.ToUpper()) }
foreach ($id in $lista) {
  if (-not $siglas.ContainsKey($id)) { Write-Host "Set desconhecido: $id"; continue }
  $url = "https://www.ligapokemon.com.br/?view=cards/search&card=" + [Uri]::EscapeDataString($siglas[$id])
  Write-Host "[$id] abrindo LigaPokémon ($url) ..."
  $prevEA=$ErrorActionPreference; $ErrorActionPreference="Continue"
  $html = (cmd /c "`"$chrome`" --headless=new --disable-gpu --virtual-time-budget=20000 --dump-dom `"$url`" 2>nul") -join "`n"
  $ErrorActionPreference=$prevEA
  $m = [regex]::Match($html, 'var cardsjson = (\[[\s\S]*?\]);\s*')
  if (-not $m.Success) { throw "[$id] não achei os dados na página da Liga (bloqueio ou mudança de layout)." }
  $arr = $m.Groups[1].Value | ConvertFrom-Json
  if ($arr.Count -lt 100) { throw "[$id] só vieram $($arr.Count) cartas." }
  $jsonPath = Join-Path $base "data\historico-precos-$id.json"; $jsPath = Join-Path $base "data\historico-precos-$id.js"
  $hist = [ordered]@{}; $origem = $null
  if (Test-Path $jsonPath) {
    $old = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($old.PSObject.Properties["origemAnterior"]) { $origem = $old.origemAnterior } elseif ($old.fonte -match "Deck Certo") { $origem = "Deck Certo (piso de mercado) até $hoje" }
    foreach ($p in $old.cartas.PSObject.Properties) {
      $serie=[ordered]@{}; foreach ($q in $p.Value.serie.PSObject.Properties) { $serie[$q.Name]=[double]$q.Value }
      $med=[ordered]@{}; if ($p.Value.PSObject.Properties["med"]) { foreach ($q in $p.Value.med.PSObject.Properties) { $med[$q.Name]=[double]$q.Value } }
      $max=[ordered]@{}; if ($p.Value.PSObject.Properties["max"]) { foreach ($q in $p.Value.max.PSObject.Properties) { $max[$q.Name]=[double]$q.Value } }
      $hist[$p.Name]=[ordered]@{ nome=$p.Value.nome; serie=$serie; med=$med; max=$max }
    }
  }
  $novos=0
  foreach ($c in $arr) {
    $key = $c.sN; $nome = [System.Net.WebUtility]::HtmlDecode($c.nPT); $mn=[double]$c.p1a; $md=[double]$c.p1b; $mx=[double]$c.p1c
    if (-not $hist.Contains($key)) { $hist[$key]=[ordered]@{ nome=$nome; serie=[ordered]@{}; med=[ordered]@{}; max=[ordered]@{} } }
    $hist[$key].nome=$nome
    if (-not $hist[$key].serie.Contains($hoje)) { $novos++ }
    $hist[$key].serie[$hoje]=$mn; $hist[$key].med[$hoje]=$md; $hist[$key].max[$hoje]=$mx
  }
  $out=[ordered]@{ fonte="LigaPokémon (menor preço anunciado; médio e maior no detalhe)"; set=$id; atualizadoEm=$hoje; origemAnterior=$origem; cartas=[ordered]@{} }
  foreach ($k in ($hist.Keys | Sort-Object)) { $s=[ordered]@{}; foreach ($d in ($hist[$k].serie.Keys | Sort-Object)) { $s[$d]=$hist[$k].serie[$d] }
    $md=[ordered]@{}; foreach ($d in ($hist[$k].med.Keys | Sort-Object)) { $md[$d]=$hist[$k].med[$d] }
    $mx=[ordered]@{}; foreach ($d in ($hist[$k].max.Keys | Sort-Object)) { $mx[$d]=$hist[$k].max[$d] }
    $out.cartas[$k]=[ordered]@{ nome=$hist[$k].nome; serie=$s; med=$md; max=$mx } }
  $json = $out | ConvertTo-Json -Depth 6 -Compress
  [IO.File]::WriteAllText($jsonPath, $json, $utf8)
  [IO.File]::WriteAllText($jsPath, "window.HISTORICO_$id = $json;", $utf8)
  if ($id -eq "CRI") { [IO.File]::WriteAllText((Join-Path $base "data\historico-precos.json"), $json, $utf8); [IO.File]::WriteAllText((Join-Path $base "data\historico-precos.js"), "window.HISTORICO_CRI = $json; window.HISTORICO = window.HISTORICO_CRI;", $utf8) }
  $lim=(Get-Date).AddDays(-15).ToString("yyyy-MM-dd"); $mov=@()
  foreach ($k in $out.cartas.Keys) { $s=$out.cartas[$k].serie; $ds=@($s.Keys); $ant=$null; foreach ($d in $ds) { if ($d -le $lim) { $ant=$s[$d] } }; if ($null -eq $ant) { $ant=$s[$ds[0]] }; $atual=$s[$ds[-1]]
    if ($ant -ge 2 -and $atual -gt 0) { $mov += [pscustomobject]@{ n=$k; nome=$out.cartas[$k].nome; de=$ant; para=$atual; var=[math]::Round(100*($atual-$ant)/$ant,1) } } }
  Write-Host "[$id] Liga: $($arr.Count) cartas lidas; $novos pontos novos; histórico de $(@($out.cartas[$out.cartas.Keys[0]].serie.Keys)[0]) a $hoje"
  Write-Host "[$id] Mais valorizadas (15 dias, piso):"; $mov | Sort-Object var -Descending | Select-Object -First 5 | ForEach-Object { "  {0} {1}: R$ {2:N2} -> R$ {3:N2} ({4:+0.0;-0.0}%)" -f $_.n,$_.nome,$_.de,$_.para,$_.var }
  Write-Host "[$id] Mais desvalorizadas (15 dias, piso):"; $mov | Sort-Object var | Select-Object -First 5 | ForEach-Object { "  {0} {1}: R$ {2:N2} -> R$ {3:N2} ({4:+0.0;-0.0}%)" -f $_.n,$_.nome,$_.de,$_.para,$_.var }
  Write-Host ""
}