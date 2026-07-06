# Prompt de implementação — Elfic Forest fiel à referência

Prompt auto-suficiente para reconstruir o mapa `elfic_forest` fiel à referência,
executável **com contexto limpo** numa sessão nova. Reconstrói todo o contexto a
partir dos arquivos do repo. Não pare até o mapa renderizar como terreno em
camadas (não campo plano) e o `make ci` fechar 9/9.

## Como rodar

Sessão nova do Claude Code na raiz do repo:

```text
Leia docs/plans/espaco.virtual/12-prompt-mapa.md e execute a implementação
completa do mapa Elfic Forest fiel à referência.
```

---

## 1. Objetivo (o quê + definição de pronto)

Reconstruir o mapa `RetroHexChat.VirtualSpace.Maps.ElficForest` para **bater a
referência** analisada em `11-mapa-referencia.md`: uma **bacia de floresta em
níveis** — vale de grama aberto no centro (onde se anda), cercado/terraceado por
**terreno alto florestado**, com a elevação desenhada por **cliffs rochosos que
serpenteiam e descem em escada**; cabana no canto, lago na base de um cliff,
caminhos ligando os níveis. Tudo com o **atlas autoral de pixels traçados** (sem
PNG em runtime).

**Pronto quando**, verificado no browser (screenshot real via Playwright
descartável):

- Os cliffs **viram cantos e correm na vertical** (autotile completo), formando
  terraços/escada — não barras horizontais isoladas.
- O chão tem **textura**: manchas de **grama escura** (sutis, arredondadas,
  espalhadas), trevos e trechos de **terra/caminho**.
- **Gradiente de densidade**: floresta grossa e sobreposta nas bordas/alto →
  vale central vazio.
- **Props motivados**: logs **nas ledges** dos cliffs, boulder **no topo** de um
  cliff, tocos no vale, pedrinhas nas bordas, lago na base de um cliff.
- `map_test` verde e `make ci` 9/9; um commit do bloco na `main`.

---

## 2. Por que (o problema e o insight)

O mapa atual é **grama plana + barras marrons isoladas**. A referência é
**terreno em camadas**: a diferença de altura (vale baixo × floresta alta) é o
que dá profundidade, caminhos e enquadramento. O erro recorrente foi tratar
cliff como decoração horizontal e espalhar props no grid. O caminho certo é
**modelar o terreno primeiro** (onde é alto, onde é baixo, onde a parede corre e
vira) e só então soltar props nas prateleiras resultantes.

O passo decisivo — sem ele nada parece a referência — é o **autotile de cliff**:
extrair o set completo (cantos internos/externos + faces laterais) e um pequeno
**autotiler** que, a partir de uma máscara de "terreno alto", escolhe o tile de
cliff certo por célula pelos vizinhos.

Leia `11-mapa-referencia.md` inteiro antes de tocar em código — é o spec.

---

## 3. Contexto obrigatório (leia nesta ordem)

1. `docs/plans/espaco.virtual/11-mapa-referencia.md` — a análise da referência
   (o spec: elevação, cliffs, caminhos, textura, densidade, props, inventário de
   tiles, requisitos de autotile, ordem de build).
2. `docs/plans/espaco.virtual/gfx/tools/README.md` + `manifest.json` — o pipeline
   de sprites.
3. `apps/retro_hex_chat/lib/retro_hex_chat/virtual_space/maps/elfic_forest.ex` —
   o mapa atual (ponto de partida).
4. `apps/retro_hex_chat_web/assets/js/lib/space/{sprite_atlas,renderer,map}.js` —
   como os tiles são decodificados e desenhados.
5. A sheet-fonte `docs/plans/espaco.virtual/gfx/Overworld.png` e os contact-sheets
   em `gfx/sliced/` (rode `slice.py` se não existirem).

---

## 4. Arquitetura técnica (para não re-descobrir)

**Pipeline de sprites** (`gfx/tools/`, Python + Pillow num venv):
- `slice.py` → fatia as sheets em `gfx/sliced/<sheet>/cCC_rRR.png` + contact-sheets
  (derivado, gitignored).
- `manifest.json` → **fonte única** de `nome_semântico → {sheet, col, row, [w, h]}`.
  Nomes SEMÂNTICOS sempre (nunca `c00_r03` no código). `w`/`h` (em tiles) para
  sprites multi-tile (casa, boulder, árvore, caverna).
- `migrate.py` → lê o manifest, gera `assets/js/lib/space/sprites/tiles/<nome>.js`
  + regenera `sprites/index.js` (registry `TILES`).
- `png2js.py` → converte um PNG num módulo `{ w, h, p:[hex...], d:"<índices>" }`
  (paleta hex sem `#`, `d` = índices row-major, `.` = transparente). Alfabeto de
  índices SEM `#` (evita o audit de cor JS). Arquivos minúsculos, pixel-perfect.
- Fluxo p/ um tile novo: achar no contact-sheet → add linha no manifest → rodar
  `migrate.py`. Verifique o `_verify_tiles`/decode antes de usar.

**Atlas** (`sprite_atlas.js`): `tile(id)` decodifica o módulo traçado (cache por
canvas escalado) e cai no painter procedural legado se o id não existir. Suporta
qualquer `w`/`h`. `ALPHA` deve espelhar o do `png2js.py`. Cor = `HASH + hex`
(nunca `#hex` literal em JS).

**Renderer** (`renderer.js`): por frame desenha VOID_BG → **base `map.ground`**
sob cada célula (para props transparentes comporem sobre a grama) → tiles do
`layers.floor` → **`map.decor`** (sprites multi-tile em `{x,y,tile}`) → avatares
(Y-sorted). `map.js` expõe `ground` e `decor`.

**Definição de mapa** (Elixir, `Maps.ElficForest.definition/0`) devolve:
`id, version, width, height, tile_size: 16, ground: "grass",
layers: %{floor: <matriz height×width de tile ids>, decor: [%{x,y,tile}], above: []},
collision: [%{x,y,w,h,kind}], zones, seats, interactables, spawn`.
Registro em `VirtualSpace.Map` (`@maps`); default em `Schema.Session`
(`map_id`) já é `"elfic_forest"`.

**Validação** (durante o loop, SÓ o que tocar — não `make ci` a cada passo):
- `mix test .../virtual_space/map_test.exs` (invariantes: spawns/seats fora de
  colisão, zonas nos bounds, TODO tile do floor no set `known` — atualize-o com
  os tiles novos; tiles multi-tile de `decor` NÃO entram no floor).
- `mix format`/`mix credo` nos arquivos Elixir tocados;
  `npx prettier --write` + `npx eslint` nos JS (rode em `assets/`).
- Browser: `MIX_ENV=e2e mix assets.build` + um spec Playwright DESCARTÁVEL que
  entra no `/space` e tira screenshot (mate a :4003 stale antes). Nunca a suíte
  E2E inteira.

**`make ci` completo (9 checagens)**: rode **só antes de commitar um bloco
acumulado** (é lento; pedido explícito do usuário). Não commite incrementos
minúsculos.

---

## 5. Plano de execução (ordem de build)

Trabalhe em blocos; valide alvo a cada passo; screenshot no browser sempre;
`make ci` + commit só ao fechar um bloco.

**Bloco A — terreno real (o decisivo):**
1. Localizar e extrair o **autotile de cliff completo** do `Overworld.png`:
   edge L/M/R, face, mid, base, **cantos externos (NE/NW/SE/SW)**, **cantos
   internos**, **faces laterais L/R** (verticais). Nomes semânticos
   (`cliff_edge_l`, `cliff_corner_out_ne`, `cliff_side_l`, …). Use os
   contact-sheets; o bloco existe (a referência usa).
2. Implementar um **autotiler** simples: representar o terreno como uma
   **máscara de "terreno alto"** (quais células são nível de cima). Para cada
   célula na fronteira alto/baixo, escolher o tile de cliff pelos 4/8 vizinhos
   (borda superior, face, canto externo, canto interno, lateral). Manter isso
   testável (função pura `cliff_tile_for(mask, x, y)`).
3. Desenhar a **máscara de elevação** do vale (bacia): alto nas bordas/cantos,
   baixo no centro, com a parede serpenteando em escada + **gaps/rampas** de
   passagem. Rodar o autotiler → floor com cliffs de verdade.
4. Colocar a **cabana** no terraço alto e o **lago** na base de um cliff.
5. Screenshot → iterar até os cliffs terracearem/virarem.

**Bloco B — textura de chão:**
6. Extrair o decal de **grama escura** (blob suave; NÃO o patch de borda clara
   de (0,6)) e o **dirt/caminho** (centro (1,30) + bordas). Espalhar grama
   escura sutil por todo o chão; usar dirt nos caminhos entre níveis + trevos
   (`flowers`) em clusters.

**Bloco C — props motivados + densidade:**
7. Extrair **stump** (topo de tronco cortado com anéis) e, se útil, uma árvore
   maior / fill de arbusto denso.
8. Posicionar props pela lógica: **logs nas ledges** dos cliffs, **boulder no
   topo** de um cliff, **stumps** no vale, **pedrinhas** trilhando bordas.
9. **Gradiente de densidade**: treeline grossa e sobreposta nas bordas/alto →
   centro vazio.
10. Screenshot final comparando com a referência; ajustar.

**Fechamento:** `make ci` 9/9 → commit único do bloco na `main` (stage por
caminho explícito). Se acumulou muito, pode ser mais de um commit (um por bloco
A/B/C), cada um com CI verde.

---

## 6. Regras permanentes

- **100% traçado da referência de domínio público** (autorizado pelo usuário):
  nenhum PNG em runtime — tudo vira dado de pixel em JS. `sliced/` é derivado
  (gitignored); só o que o mapa usa vira `.js`, com nome semântico.
- Comentários descrevem **o que é / como funciona**, nunca o porquê/procedência.
- Sem `#hex` hardcoded em JS (use o padrão `HASH + hex`); sem SVG inline; specs
  Elixir com `@spec`; alias no primeiro write (credo-clean de primeira).
- Testes de mecânica do canal/domínio fixam `map_id: "tavern_cafe_v1"` (o layout
  do tavern); o default do produto é `elfic_forest`. Não quebre isso.
- Commit direto na `main`, stage por caminho explícito, nunca `git add -A`.
  Trailer de coautoria do harness.
- Validação alvo durante a iteração; `make ci` completo só no fechamento do
  bloco.

## 7. Critério de conclusão

O `/space` abre no `elfic_forest` e o mapa renderiza como **terreno em camadas
fiel à referência**: vale aberto emoldurado por cliffs que terraceiam/serpenteiam
com cantos, floresta densa com gradiente, chão com grama-escura/trevos/terra,
props motivados (logs em ledges, boulder no alto, tocos, lago na base do cliff),
caminhos entre níveis. `make ci` 9/9 e commit(s) na `main`. Registre no fim um
resumo curto do que ficou e de qualquer tile da referência que não exista na
sheet (e como foi contornado).
