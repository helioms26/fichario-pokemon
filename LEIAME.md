# Meu Fichário — Caos Ascendente (CRI) e Evoluções Prismáticas (PRE)

Fichário digital multi-set (PT-BR) com histórico de preços. As abas no topo trocam de set; cada set tem coleção, imagens, promos e histórico próprios, tudo gravado no mesmo `data\colecao.json`.

## Sets
- **Caos Ascendente (CRI)** — `data\caos-ascendente.js`: 122 cartas + 8 promos (074–081 Megaevolução Promos). Imagens em `img\CRI\`.
- **Evoluções Prismáticas (PRE)** — `data\evolucoes-prismaticas.js`: 180 cartas (131 base + 49 secretas; inclui ACE SPEC e Hiper Rara) + 8 promos SVP 167–174 (Flareon/Vaporeon/Jolteon = blister quádruplo; Leafeon/Glaceon/Sylveon = blister triplo; Eevee = ETB). Master set inclui reverse foil e padrão Poké Ball para comuns/incomuns/raras (Master Ball ainda não modelado). Imagens em `img\PRE\`.
- Para adicionar outro set: criar `data\<set>.js` no mesmo formato, incluir o `<script>` e o id em `SET_IDS` no index.html, baixar imagens para `img\<ID>\` e incluir a URL da fonte em `atualizar_precos.ps1` e `baixar_imagens.ps1`.
- Histórico de preços: `data\historico-precos-<SET>.json` / `.js` (CRI também mantém `historico-precos.*` por compatibilidade).

## Como abrir
**Recomendado:** dois cliques em `Abrir Fichario.cmd`. Ele sobe um servidor local (só na sua máquina, http://localhost:8765) e abre o álbum no navegador padrão. Nesse modo o botão **Salvar** grava direto na pasta sem pedir permissão e o botão **Atualizar preços** funciona. Feche a janela preta para encerrar (as marcações já estão salvas).

Alternativa: dois cliques em `index.html` — funciona sem servidor; o Salvar pede permissão da pasta a cada sessão e o Atualizar preços só orienta a rodar o .cmd.

## Arquivos
- `index.html` — o app (álbum, busca, filtros, dashboard, preços, detalhe da carta).
- `data\caos-ascendente.js` — banco de dados: 122 cartas + 8 promos (074–081 da série Megaevolução Promos), raridade, tipo, preço de referência.
- `data\historico-precos.json` / `.js` — histórico diário de preços (fonte da verdade / cópia lida pelo app). Nunca apaga pontos antigos.
- `data\nomes-imagens.json` — mapa número → nome de arquivo das imagens.
- `img\NNN_nome_da_carta.webp` — imagens oficiais em PT-BR (ex.: `001_weedle.webp`). Promos: `img\P078_toxel.webp` (versão em inglês por enquanto; 081 ainda sem imagem pública).
- `Abrir Fichario.cmd` (+ `servidor.ps1`) — abre o fichário com o servidor local.
- `Atualizar precos.cmd` (+ `atualizar_precos.ps1`) — baixa os preços do dia e acrescenta ao histórico (o botão Atualizar preços faz o mesmo quando aberto pelo servidor).
- `Baixar imagens.cmd` (+ `baixar_imagens.ps1`) — rebaixa imagens do set que faltarem.

Os `.cmd` existem porque o Windows bloqueia `.ps1` com dois cliques; o `.cmd` roda o script só naquela execução, sem mudar configuração do sistema.

## Como usar
- **Master set** (padrão) = 198 espaços do set (as 76 comuns/incomuns/raras também em reverse foil) + 8 promos = 206. **Set base** = 122 + 8. O app lembra o modo escolhido.
- Página única com rolagem, 3 cartas por linha. Na vista padrão (ordem do set, sem filtro) há divisórias "Página N do fichário" a cada 9 cartas, para bater com o fichário físico. Botão "↑ Topo" aparece ao rolar.
- Marque "Tenho" embaixo da carta ou dentro do detalhe. O dashboard atualiza na hora e a rolagem não se perde.
- Busque por nome, número (`116`) ou `promo`. Filtre por raridade (inclui "Promo") e por tenho/falta. Ordene por número, nome ou valor.
- Clique na imagem para ver: raridade explicada, como guardar (sleeve/toploader), preço com gráfico e variação (15/30 dias/desde o início), origem (promos), links para cartinha.gg e LigaPokémon, e anotações.
- Botão **Preços** (amarelo, no topo): gráfico do valor do set e da sua coleção, mais valorizadas e mais desvalorizadas na janela escolhida (15/30/60 dias/tudo).

## Onde ficam os dados
Em dois lugares:
1. `data\colecao.json` (e `colecao.js`) — gravado na pasta a cada marcação, **quando a pasta está conectada**. É o que faz Chrome, Edge e outros PCs verem a mesma coleção (via OneDrive).
2. Armazenamento do navegador (localStorage) — cópia local, usada se a pasta não estiver conectada.

Ao abrir, o app compara os dois e usa o mais recente. O painel "Sincronização com a pasta" no topo do dashboard mostra o estado:
- **Conectar pasta do fichário** (primeira vez em cada navegador): escolha a pasta `pokemon` e permita a gravação.
- **Autorizar pasta**: o navegador pede isso a cada sessão, por segurança. Sem autorizar, as marcações ficam só no localStorage até a próxima autorização (e podem ser sobrescritas se outro navegador gravar depois).
- Requer Chrome ou Edge. Em outros navegadores, use Exportar/Importar JSON.

O backup manual (Exportar JSON) continua disponível e é uma boa cópia extra.

## Atualizar preços
Dois cliques em `Atualizar precos.cmd`. Ele baixa a galeria do Deck Certo (preço do dia + histórico diário que o site expõe), acrescenta ao `historico-precos.json` e imprime as maiores altas e quedas de 15 dias. O app usa o preço mais recente do histórico automaticamente; os preços em `caos-ascendente.js` são só o fallback.
Cadência: a cada 15 dias é seguro (a fonte mostra ~60 dias; rodar a cada 15 dá folga). Rodar mais vezes não atrapalha: pontos repetidos são ignorados.
Confira no cartinha.gg ou LigaPokémon antes de comprar/vender — o Deck Certo é agregador, não vendedor.

## Limitações conhecidas desta versão
- Preço só da versão normal; reverse foil e promos sem referência (não entram nos totais).
- Imagens das promos são da versão em inglês; a 081 (Mega Greninja ex) ainda não tem imagem pública.
- Tipos (Planta, Fogo…) foram inferidos do Pokémon — confira na carta se algo parecer errado.
- O link do cartinha.gg abre a página da carta (me04-NNN / mep-NNN para promos); o da LigaPokémon é uma busca por nome e pode pedir ajuste lá.
- Não há sincronização entre dispositivos além do backup JSON.
