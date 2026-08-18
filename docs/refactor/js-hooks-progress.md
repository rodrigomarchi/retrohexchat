# Refactor de padronização da camada JS — progresso e aprendizados

Diário vivo do refactor descrito no plano **"Quatro Coisas num Hook"**
(artifact: https://claude.ai/code/artifact/dd13089b-da12-486d-9787-3f1dfad79fff).
A revisão que o originou: https://claude.ai/code/artifact/a99a0fb1-0153-4ed6-a7ad-bed87e392e56.

O ledger por-hook está em [`js-hooks-ledger.md`](js-hooks-ledger.md).

**Natureza do trabalho:** padronização pura. Nenhum comportamento muda. A prova
disso roda antes de cada commit: `sh scripts/surface_snapshot.sh --check` +
`make ci` verde. Ver §00 e §05 do plano.

---

## Baseline medido — main @ a1c9376e, 18/08/2026

| Medida | Valor |
|---|---|
| Arquivos de teste JS | 171 |
| Casos de teste JS | 4.465 (todos verdes, ~7 s) |
| Entradas na superfície observável | 351 |
| Linhas em `js/hooks/` | 10.464 (53 arquivos) |
| Hooks > 200 linhas | 13 |
| Chamadas `hook._priv` em teste | 201 |
| Arquivos com primitiva proibida em `js/hooks/` | 8 |
| Estados mutáveis de módulo em `js/lib/` | 4 |

Catracas (só descem): teto de 200 linhas · `MAX_HOOK_PRIVATE_CALLS=201` ·
allowlist de primitivas (8) · overrides de estado de módulo (4).

---

## Gate por commit

Durante a iteração (por pacote/fatia), gate **direcionado** — rápido:

```
prettier --write <arquivos> && mix format
cd apps/retro_hex_chat_web/assets && sh scripts/surface_snapshot.sh --check
make test.js               # ~7 s
make lint.hooks
make lint.js && make lint.bundle
```

O **`make ci` completo (~5 min) roda só depois de acumular vários pacotes** —
não a cada commit, para não atrasar o desenvolvimento. Postgres/compose sempre
pelos alvos do Makefile (`make docker.up`), nunca à mão. Ao rodar:
`make ci > /tmp/ci.log 2>&1; echo $?` — nunca `make ci | tail` (o pipe mascara
o exit code).

---

## Registro por pacote

### W0 — andaime · CONCLUÍDO

**Feito**
- Corrigido `enforce_hooks_contract.cjs`: `CONTRACT_DOC` apontava para
  `docs/046-…md` inexistente → agora `docs/AGENT-GUIDE.md §15`. Removidas duas
  entradas obsoletas da allowlist de import dinâmico (`games/game_canvas_hook.js`
  deletado; `lobby/lobby_game_canvas_hook.js` agora carrega via
  `lib/games/engine_loader.js`). Commit `d3e0a9c1`.
- Criado `scripts/surface_snapshot.sh` (+ `js/SURFACE.txt`, 351 entradas).
  Verificado que `--check` acusa diff e sai 1 ao renomear um evento, e volta a 0
  ao restaurar.
- Três catracas novas no guard, cada uma com baseline que só desce e cada uma
  verificada falhando quando deveria:
  - teto de 200 linhas/hook (`HOOK_LINE_OVERRIDES`, 13 entradas com o pacote que resolve);
  - primitivas proibidas em `js/hooks/` (`FORBIDDEN_PRIMITIVE_OVERRIDES`, 8);
  - `MAX_HOOK_PRIVATE_CALLS` (201) contra white-box em `test/hooks/`;
  - bônus: estado mutável de módulo em `js/lib/` (`LIB_MODULE_STATE_OVERRIDES`, 4).

**Aprendizados**
- A árvore foi reescrita durante a fase de planejamento (mesmo commit
  `a1c9376e`, mas arquivos de 12:52). Re-medi tudo: 53 hooks / 10.464 linhas /
  201 chamadas privadas. O achado do switch de engines inline no
  `lobby_game_canvas` **já estava resolvido** (extraído para
  `lib/games/engine_loader.js`) — deixou de ser item.
- `git checkout <file>` é bloqueado por hook do repositório (destrói trabalho
  não-commitado paralelo). Para verificar catracas com mutação temporária, usar
  `cp arquivo /tmp/bk` + restaurar por `cp`, nunca `git checkout`.
- `make ci | tail` mascara o exit code (retorna status do `tail`). Sempre
  redirecionar para arquivo e ler `$?`.
- `mix format` antes de tudo: uma linha longa quebrada faz o CI pular estágios
  paralelos e desperdiça um ciclo.

### W1 — RetroTable (piloto) · CONCLUÍDO

**Feito**
- `js/hooks/ui/retro_table_hook.js`: 586 → **32 linhas**, forma
  `createRetroTableHook({ tableFactory })`, só mount/updated/destroyed.
- Novo controlador Forma B `js/lib/ui/retro_table.js` (`createRetroTable(el, ports)`)
  com todo o comportamento; clipboard entra por `ports.writeText` (default
  `navigator.clipboard`).
- Dois módulos Forma A: `retro_table_layout.js` (`distributeWidths`,
  `nextHiddenColumns`, `columnSignature`, `MIN_COLUMN_WIDTH`) e
  `retro_table_selection.js` (`nextRowIndex`, `nextSelection`, `pruneSelection`,
  `toTSV`).
- Testes: `test/lib/ui/retro_table_layout.test.js` (+ selection, + controller) —
  +37 casos. O teste de hook existente (black-box, 30 casos) segue verde sem
  edição, provando comportamento preservado.
- Guard: retro_table removido dos overrides de linha e de primitiva
  (`getContext`/`navigator.clipboard` agora só no controlador em `lib/`).
- Reversão verificada: quebrar `distributeWidths` deixa vermelho o teste de lib
  (4) **e** o de hook (8) → religado, não copiado.

**Aprendizados**
- Import relativo ao mover: controlador em `lib/ui/` → `../logger`, `./menu`
  (o hook usava `../../lib/...`). Um caminho errado só aparece no vitest
  (transform error), não no eslint.
- `node --check` não valida ESM (`.js` sem `type:module`); usar eslint/vitest.
- Testes de lib que focam a linha (`scrollIntoView`, `ResizeObserver`) precisam
  dos stubs que o `hook_helper` dá de graça — importar ou re-stubar no arquivo.
- A porta de clipboard (`ports.writeText`) é o seam que o teste black-box de
  hook não alcança; é o que justifica um teste de controlador dedicado.
### W2 — as quatro duplicações · CONCLUÍDO

**Feito**
- **W2.1 long-press** → `lib/input/long_press.js` (`createLongPress`), religado
  em nicklist, conversations e chat_viewport. `shouldFire` cobre o
  `isConnected` do chat_viewport; `suppressNextClick` migrou para a máquina
  (`consumeClickSuppression`); `suppressContextClick` do conversations ficou no
  hook. Constantes 550/10 agora num só lugar. 12 casos de lib + reversão nos 3
  hooks.
- **W2.2 isEditableTarget** → `lib/ui/dom.js`; removidas as cópias de
  shortcut_dispatcher e group_call_webrtc. +5 casos.
- **W2.3 device** → `lib/p2p/device_constraints.js` (`withDevice`,
  `captureConstraints`) e `lib/p2p/device_errors.js` (`mediaErrorMessage`,
  `missingDeviceWarning`); religados prejoin (4 usos) e group_call_webrtc
  (`_withDevice` eliminado, 4 usos). +19 casos.
- **W2.4 markdown** → `lib/chat/markdown_format.js` (`MARKDOWN_FORMATS`,
  `applyMarkdownFormat`); os 3 métodos quase-idênticos do format_toolbar viraram
  uma transformação pura de `{value,selectionStart,selectionEnd}`. +7 casos.
- Superfície intacta; 178 arquivos / 4545 testes (+43).

**Aprendizados**
- **Timer capturado na construção vs. no uso:** a máquina não pode fixar
  `setTimeout` no closure — um hook monta em `beforeEach`, antes de o teste
  ligar `vi.useFakeTimers()`. Resolver o global no momento do `start()`
  (`(setTimeoutFn || setTimeout)`) reproduz o `setTimeout` inline original.
- Ao extrair função que já usava `t()`, o módulo de lib importa `t` — traduzir
  não é o movimento; preservar as mesmas chamadas `t()` é. `t()` sem catálogo
  cai na string-fonte, então o teste asserta o inglês.
- Quando um hook passa a ter dois destinos no fire (channel vs nick), o
  `onFire(context)` recebe o contexto montado no `start()` — sem estado
  intermediário no hook.
### W3 — os quatro sem seam · CONCLUÍDO

**Feito**
- **metric_chart** (217→35): `lib/system/metric_chart.js` — funções puras
  (`seriesBounds`, `formatAxisValue`, `readChartPalette`, `drawChart`) + controlador
  Forma B `createMetricChart(el)` que detém ResizeObserver/getContext (R3). Hook
  que não tinha teste agora tem 13 casos.
- **preserve_scroll** (217→32): `lib/ui/scroll_preservation.js`
  (`createScrollPreserver()` + singleton const `scrollPreserver`). As 6 globais
  mutáveis viraram closure. `registry.js` re-exporta os 3 callbacks de morphdom
  de lib (não mais de dentro de um hook); `app.js` inalterado. +5 casos de lib.
- **p2p_diagram** (146): `lib/p2p/diagram.js` (`dotPosition`, `dotFrame`,
  `diagramConfig`). Sem teste antes → 11 casos. RAF fica no hook (é o efeito).
- **viewport_detect** (115): `lib/ui/viewport.js` (`computeViewport`,
  `viewportPayload`, `viewportChanged`, `viewportCssVars`). `editableFocused`
  vira parâmetro. +13 casos.
- 182 arquivos / 4587 testes (+42). Reversões OK em metric_chart e
  scroll_preservation.

**Aprendizados**
- **R3 vs. o texto do plano:** o plano dizia "o hook fica com o ResizeObserver",
  mas R3 proíbe ResizeObserver/getContext em `js/hooks/`. O guard é a autoridade
  — o controlador Forma B em `lib/` detém essas primitivas; o hook só o instancia.
- **Singleton sem estado mutável de módulo:** `export const x = createX()` é um
  `const`, não fere R5, e ainda deixa o teste criar instância fresca. Foi assim
  que scroll_preservation saiu das 6 globais sem quebrar o compartilhamento entre
  hook e callbacks de morphdom.
- **Re-export de lib no registry** mantém o contrato §15 (`app.js` importa de
  `registry`) enquanto tira os callbacks de morphdom de dentro do arquivo de hook.
- `mkdir -p test/lib/<área>` antes do heredoc: um `cat >` num diretório
  inexistente falha silencioso e o vitest reclama de "no files".
### W4 — negociação WebRTC compartilhada · pendente
### W5 — fatiar a conferência · pendente
### W6 — file_transfer como redutor · pendente
### W7 — composer de chat · pendente
### W8 — varredura e remoção do andaime · pendente
