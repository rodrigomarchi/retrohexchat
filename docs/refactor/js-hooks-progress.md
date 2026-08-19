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
### W4 — negociação WebRTC compartilhada · CONCLUÍDO

**Feito**
- `lib/p2p/negotiation.js`: `ownsDescription`, `canApplyDescription`,
  `normalizeEpoch`, `nextConnectionEpoch`, `advanceEpoch`, `isStaleEpoch` —
  regras puras sobre (role, signalingState, epoch), extraídas do lobby copiando
  os corpos sem mudar condição.
- Lobby religado: folhas puras (`_isOwnDescription`, `_normalizeEpoch`,
  `_nextConnectionEpoch`) deletadas e inlinadas; `_canApplyDescription` (tem
  log) e `_advanceSignalingEpoch` (muta estado) mantidos usando a lib;
  `_isStaleEpoch` vira adaptador de uma linha. Os testes de negociação existentes
  (via `_handleSignal`/`_maybeOffer`) seguem verdes sem edição.
- Conferência passa a criar a conexão por
  `createPeerConnection(iceServers, { turnOnly: false })` — um só caminho de
  criação de `RTCPeerConnection` no repo. (turn_only é conceito só da sessão P2P;
  a conferência é SFU.)
- +12 casos de lib cobrindo a matriz 2 papéis × tipos × todos os signalingState.
  Reversão OK (lib + hook reagem).

**Aprendizados**
- Distinguir folha pura de adaptador com estado: `_normalizeEpoch(value)` não usa
  `this` → pass-through puro, inlinar nos 9 sites. `_isStaleEpoch(epoch)` liga
  `this.signalingEpoch` → adaptador legítimo (tem callers de produção reais), não
  é alias-só-de-teste que R6 proíbe.
- Os testes de negociação chamam métodos de **alto nível** (`_handleSignal`),
  não as folhas — então extrair/deletar as folhas não os quebra, e eles ficam
  como a prova de que o comportamento composto foi preservado (reescrita contra a
  lib fica para W8).
### W5 — fatiar a conferência · CONCLUÍDO (extração de decisões)

group_call_webrtc_hook: 2414 → 2165 linhas até agora. Uma fatia = um commit;
o hook fica funcional (40 testes verdes) antes e depois de cada uma.

- **W5.1 quality** ✓ → `lib/group_call/quality.js` (collectQualitySnapshot,
  deriveParticipantQuality, participantQualityLevel/Label/Title). `resolveParticipantId`
  e `now` injetados. +11 casos.
- **W5.2 payload** ✓ → `lib/group_call/payload.js` (stringOrNull, idsFromValue,
  payloadValue, normalizeLayoutMode, normalizeSelfView, tileDensity, hasOwn +
  LAYOUT_MODES/SELF_VIEW_MODES). 7 métodos-sem-`this` deletados. +12 casos.
- **W5.3 reactions** ✓ → `lib/group_call/reactions.js` (reactionEmoji,
  ensureReactionStack, reactionIconNode, buildReactionBubble, REACTION_TTL_MS).
  Timers e resolução de tile ficam no hook. +7 casos.
- **W5.4 layout** ✓ → `lib/group_call/layout.js` (tileIsVisible, focusedTileIndex,
  isTilePinned). Decisão de foco vira índice sobre descritores puros; aplicação
  ao DOM fica no hook. +11 casos. Reversão OK.
- **W5.5 tiles** ✓ → `lib/group_call/tiles.js` (localEmptyState, localEmptyStateCopy,
  participantTileMedia). O plumbing DOM de tiles/tracks fica no hook. +11 casos.
- **W5.6 media-state** ✓ → `lib/group_call/media_state.js` (mediaStateFromDataset,
  hasLiveTrack, needsOnDemandMedia, actualMediaState). +6 casos.

**Resultado do W5:** god-hook 2414 → 2134 linhas; 6 módulos `lib/group_call/*`;
58 casos novos cobrindo a lógica de decisão antes intestável.

**Decisão sobre `rtc_media_hook_factory` (item fora-de-escopo do §00):** a conferência
NÃO adota a fábrica. A fábrica modela mídia P2P bilateral (request/consent, um peer);
a conferência é SFU (multi-participante, self-controlled). Fazer a conferência adotá-la
seria reescrita comportamental, não movimento — proibido pelo contrato §00. Os ramos
mortos da fábrica (`upgradeMode:"request"`, `!autoJoin`, `statsUpdate`) viram limpeza
separada na lista fora-de-escopo, não parte do W5.

**Resíduo assumido (override documentado no guard):** o group_call_webrtc_hook segue
> 200 linhas. O que sobra é plumbing de `RTCPeerConnection` ao vivo (getUserMedia,
screen capture, offer watchdog, recovery, stats polling, connection-state handlers) e
sync DOM de tiles/tracks — extrair para controladores Forma B seria reescrever
sinalização de tempo real, cujo teste de hook atual (40 casos) cobre só parcialmente.
Isso é trabalho separado, com testes de integração dedicados, não seguro dentro de um
refactor "não muda comportamento". Registrado como follow-up no ledger.

**Aprendizados**
- Fatiar um god-hook por descritor: passar `tiles.map(t => ({participantId,
  streamId, isLocal}))` para a função pura e mapear o índice de volta ao elemento
  é o que torna a decisão de foco testável sem grid — sem arrastar DOM para a lib.
- `mkdir -p test/lib/<área>` antes do primeiro heredoc de cada área nova.
> **Nota (flaky pré-existente):** no `make ci` após W5, 1 falha em
> `RetroHexChat.Lobby.SessionServerTest` "concurrent features … full game cycle"
> — teste de concorrência do servidor, passa isolado e no arquivo inteiro (18/18).
> Nenhum `.ex/.exs` foi tocado no refactor; é flakiness pré-existente, não regressão.

### W6 — file_transfer como redutor · CONCLUÍDO

**Feito**
- `lib/p2p/transfer_session.js`: `step(session, event) → {session, effects}` —
  redutor puro das transições discretas de protocolo (peer_accept/reject,
  sender/receiver hash_result, local/incoming cancel, channel_close,
  incoming_have_chunks, retry_request, incoming_retry). Efeitos declarativos
  (`SEND_CONTROL` com `requireOpen`, `PUSH`, `START/STOP_PROGRESS`,
  `START_SENDING`, `PROCESS_QUEUE`, `DOWNLOAD`).
- Hook: `_applyStep(event)` roda o redutor e executa efeitos via `_applyEffects`.
  Os 10 handlers discretos viraram uma linha cada. Os fluxos de I/O assíncrono
  (loop de envio com backpressure, hash, assemble, download, timers) ficam no
  hook — são efeito, não decisão. 663→586 linhas.
- Redutor com 18 casos. **Teste white-box do hook (14) segue verde sem edição =
  prova de equivalência.** Reescrita black-box do teste do hook fica para o W8
  (mesma tática do W4 com os testes de negociação).
- O reason `"Integrity check failed"` continua via `t()` (importado no redutor)
  — o valor do payload não muda.

**Aprendizado — o snapshot ganhou fidelidade:** ao mover `pushEvent("ft_accepted")`
para `push("ft_accepted")` no redutor, o grep do snapshot deixou de ver 5 eventos
(indireção `eff.event`). Corrigido estendendo o grep de `liveview-events` para
reconhecer o helper `push("...")` de `js/lib/` (sem confundir com `channel.push`,
via `[^.]push\(`). De quebra, o snapshot parou de capturar `"--"` (valor de
payload `eta`, não evento) que o grep antigo pegava por imprecisão. Verificado que
ainda pega rename real de evento (exit 1).
### W7 — composer de chat · W7.1/W7.2 CONCLUÍDOS (W7.3/W7.4 → W8)

**Feito**
- **W7.1 resolveComposerKey** → `lib/chat/composer.js`: o bloco `keydown` de ~230
  linhas virou `resolveComposerKey(event, state) → intents[]` puro (padrão do W6:
  intenções declarativas `preventDefault/stopPropagation/push/setState/action`).
  O hook monta o estado, chama o resolver e interpreta via `_applyComposerIntents`
  + `_runComposerAction`. Ordem dos ramos replicada fielmente (Escape → Enter →
  Ctrl+R → Ctrl+Arrow → Arrow → Tab → Ctrl+Shift IRC). 20 casos de lib.
- **W7.2 parseSlashCommand** → `lib/chat/input.js`: o parsing de `/cmd args` do
  `checkSyntaxTooltip` (none/pending/query). 5 casos.
- **5 compat aliases mortos removidos** (loadPersistedHistory, saveToPersistedHistory,
  saveRecentCommand, computeMaxHeight, autoResize — 0 chamadores). `loadRecentCommands`
  sobrevive com 2 testes → sai no W8 junto da reescrita black-box.
- autocomplete 631→538. Teste black-box (38) verde sem edição = equivalência.
  Reversão OK.
- **W7.3** (painel Ctrl+R como hook/controlador próprio) e **W7.4** (split do
  chat_viewport em scroll/reader) ficam para o W8 — são fatias grandes adicionais,
  não bloqueiam o valor entregue.

**Aprendizado:** mesmo padrão de fidelidade do snapshot do W6 — `up`/`down` eram
valores de payload (`direction`), não eventos, capturados por imprecisão do grep
antigo. Ao mover para `push("...", { direction })` no resolver (direction virou
variável), sumiram do snapshot; os nomes de evento reais seguem rastreados.
### W8 — varredura · CONCLUÍDO (com follow-ups rastreados)

**Feito**
- **Padrão documentado:** `AGENT-GUIDE.md §15.1` ("What may live inside a hook")
  — as quatro coisas, as três formas, o par de referência, o teste operacional
  (Object.create/hook._private = lógica no lugar errado), as quatro catracas.
  `.claude/rules/assets-js.md` aponta para lá.
- **R5:** `file_transfer.js` `idCounter` → closure. Os 3 estados de módulo
  restantes (`public_manager`, `interactive`, `tips`) são singletons deliberados
  — override com razão escrita, não lógica presa.
- **Teste do file_transfer reescrito black-box** (protocolo coberto pelo redutor
  do W6): −17 white-box calls; catraca 201→184.
- **i18n (fora-de-escopo, commits próprios):** 5 strings de loading do space +
  badge "Speaking"/"Not speaking" → `t()`.

**Follow-ups — TODOS RESOLVIDOS depois (2ª rodada):**
- ✅ **W7.3** painel Ctrl+R → `lib/chat/history_search.js` (autocomplete 538→440, +7 testes).
- ✅ **W7.4** split do chat_viewport → `lib/chat/viewport_scroll.js` (437→365; saiu do override de primitivas via `copyText`).
- ✅ **#4 i18n labels de qualidade** → `t()` + re-derivação local por viewer.
- ✅ **#5 factory des-parametrizado** (ramos mortos removidos, lobby é único consumidor).
- ✅ **#6** alias `loadRecentCommands` removido + `toolbar_group` → `lib/ui/toolbar_group.js`.
- ✅ **#1 resíduo WebRTC:** toda decisão limpa já extraída (quality/layout/tiles/media-state/
  payload/reactions/negotiation). O que resta (recovery de 2 linhas + timers/pc/DOM) é
  plumbing irredutível — extrair seria box-checking sem valor. Override permanente com razão.

**Grupo C — hooks médios com lógica presa: AGORA TODOS FINOS.**
- ✅ `contextual_tips` 229→35 → `lib/ui/tip_queue.js` (fila+toast+idle como controlador).
- ✅ `connection_status` 212→187 → `lib/connection/connection_view.js` (mapeamento estado→view).
- ✅ `format_toolbar` 261→27 → `lib/chat/format_toolbar.js` (controlador do popover/cores).
- ✅ `group_call_prejoin` 278→29 → `lib/group_call/prejoin.js` (preview de device; saiu dos 2 overrides).

**Estado dos hooks: 41/47 finos (≤200).** Os 6 restantes: 3 são plumbing WebRTC/Socket
irredutível (group_call_webrtc 2136, lobby_webrtc 1136, space_canvas 409, override
permanente); 3 têm a decisão já extraída e testada, sobrando I/O async ou binding de
listeners (file_transfer 586 — loop de envio/hash/download; autocomplete 440 — wiring de
input/keyup + handleEvents; chat_viewport 362 — reader-interactions pushEvent-coupled).

**Nota histórica — o que era follow-up e virou feito:**
- **Resíduo WebRTC (override de linha permanente):** `group_call_webrtc` (2134),
  `lobby_webrtc` (1136), `space_canvas` (408) seguem > 200. O que sobra é
  plumbing de `RTCPeerConnection` ao vivo + sync DOM de tiles. Extrair para
  controladores Forma B = reescrever sinalização de tempo real; os testes de
  negociação atuais (`lobby_webrtc_negotiation`, `group_call_negotiation`) dirigem
  `_handleSignal`/`_maybeOffer` para cobrir glare/épocas/desync — cobertura de
  integração legítima, não acessor de folha. Precisa de testes de integração
  dedicados antes; não é seguro dentro de "não muda comportamento".
- **W7.3** (painel Ctrl+R como hook próprio) e **W7.4** (split do chat_viewport
  em scroll-controller + reader-interactions): fatias grandes. chat_viewport tem
  comportamento de scroll delicado (scroll-yank; ver memória) com cobertura
  limitada — precisa de teste de scroll dedicado antes de mover os observers.
- **i18n dos labels de qualidade** (`participantQualityLabel/Title` em
  `lib/group_call/quality.js`): NÃO wrap simples. O label viaja no payload de
  qualidade broadcast; traduzir certo = re-derivar no ponto de display, na locale
  de cada viewer, e não transmitir texto traduzido. É decisão de payload/display.
- **`rtc_media_hook_factory` des-parametrização:** remover os ramos mortos
  (`upgradeMode:"request"`, `!autoJoin`, `statsUpdate`) de um arquivo de 1466
  linhas com 1 consumidor — cleanup separado.
- **`loadRecentCommands`** (último alias do autocomplete) + seus 2 testes:
  migrar o teste para `lib/chat/history.js` e remover o alias.
- **Hooks finos sem teste** (menu_reposition, public_window_manager,
  focus_chat_input, help_nav, highlight, toolbar_group): a lógica que tinham já
  está testada em `lib/`; teste da casca é de baixo valor.

**Balanço do refactor (W0–W8):** god-hook da conferência 2414→2134; ~20 módulos
`lib/` novos com ~330 casos de teste cobrindo decisões antes intestáveis;
snapshot da superfície + 4 catracas em CI segurando a linha; padrão escrito no
AGENT-GUIDE. Nenhum comportamento observável mudou (commits de refactor); os
poucos commits comportamentais (i18n) são isolados e marcados.

---

## Segunda onda (pós-W8) — fechar a punch-list restante

O W8 fechou o bloco mas deixou 6 hooks > 200 linhas com resíduo real (não só
irredutível). Uma segunda leva de commits atacou isso; **os cinco commits
`5b615b77`…`9622d3d5` não atualizaram este diário na época** — reconciliados aqui:

- `5b615b77` recovery/watchdog da conferência → `lib/p2p/recovery.js` (+testes).
- `42820f13` search_highlight, connect_form, p2p_diagram → controladores em
  `lib/{chat,connection,p2p}/*` (os "três sub-200 que o guard não via").
- `955ba202` typing-machine do autocomplete → `lib/chat/typing_indicator.js`;
  fechou um dodge de classificação no guard; overrides honestos.
- `8f799d6c` coordenada do space_canvas → `lib/space/canvas_point.js`; fechou o
  gap de teste do infinite_scroll.
- `9622d3d5` isenção do `audit.styles` seguindo o p2p_diagram pra `lib/`.

### W-A — autocomplete: tab-cycle + reposição do dropdown · CONCLUÍDO

**Feito**
- `lib/chat/tab_cycle.js` (`createTabCycle(el, {setTimeoutFn})`, Forma B): a
  máquina de ciclo de Tab. `start`/`advance`/`reset`/`active`. O handler
  `tab_matches` virou uma linha (`this.tabCycle.start(...)`); o input listener
  chama `reset()`; a action `tabCycle` chama `advance()`; o resolver lê
  `this.tabCycle.active`. `_advanceTabCycle` deletado. 10 casos de lib.
- `lib/chat/dropdown_position.js` (`dropdownMaxHeight(rect)`, Forma A): a decisão
  de `getBoundingClientRect → maxHeight` do `updated()`. O hook faz a leitura de
  rect e o writeback de `.style.maxHeight`; a decisão é pura. 4 casos.
- autocomplete 434 → **406**. Teste black-box do hook verde sem edição =
  equivalência. Override do guard reescrito (resíduo agora é binding de
  listener + handleEvents + plumbing de history/dataset).

**Aprendizado — a máquina de tab-cycle do cliente está MORTA e eu preservei a
morte:** `dispatchEvent(input)` é síncrono, então o próprio echo do write dispara
o input listener do hook, que zera `tabCycleState` **antes** de o `setTimeout(0)`
capturar `preserved` — o restore reescreve `null`. Resultado: `tabCycleActive` é
sempre `false` e o ciclo de Tab acontece no servidor (via `tab_complete`
repetido), não no cliente. Provei isso empiricamente (scratch test: valor nunca
avança de "alice: "). A extração reproduz a ordem exata (captura de `preserved`
DEPOIS do dispatch), então o comportamento é byte-a-byte. **Não corrigi** — corrigir
mudaria comportamento observável (seria commit próprio). Registrado como achado
adiado no ledger. O teste de lib documenta as DUAS faces: a máquina cicla
corretamente isolada (sem o listener do host), e morre quando o host reseta no echo.

### W-B — space_canvas: overlays + resizer · CONCLUÍDO

**Feito**
- `lib/space/space_overlays.js` (`createSpaceOverlays(el, {board})`, Forma B): o
  indicador de loading (`setLoadingText`/`hideLoading` com o latch de
  `loadingHidden`) e o modal do tabuleiro (`renderModal`). O board é desenhado
  pela porta `board` (o atlas continua sendo do hook). 8 casos.
- `lib/space/canvas_resizer.js` (`nextCanvasSize` puro + `createCanvasResizer(el,
  canvas, {onResized})`, Forma B): o `ResizeObserver` + a decisão de re-fit do
  backing store. 6 casos.
- space_canvas 412 → **364**. Teste black-box do hook verde sem edição
  (os testes de loading passam pelo controlador). Override de linha reescrito.

**Aprendizado — o override de primitiva "W8" era DÍVIDA, não justificativa:** o
guard tinha `space_canvas` na `FORBIDDEN_PRIMITIVE_OVERRIDES` com a tag "W8" pelo
`new ResizeObserver`. Um ResizeObserver está na lista proibida justamente porque
é "um controlador disfarçado" — não é irredutível como o `RTCPeerConnection` ao
vivo. A definição-de-pronto exige que overrides descrevam resíduo LITERALMENTE
irredutível, então tirei o ResizeObserver do hook (foi pro `canvas_resizer`) e
**apaguei o override** — o guard confirma (a catraca falha se um override sobra
sem o primitivo correspondente). O que sobra no hook é I/O de Socket/channel e
binding de listeners de ponteiro que fazem `pushEvent` — não decisão presa.

### W-F2a — testes de lib diretos p/ os três controladores · CONCLUÍDO

**Feito**
- `test/lib/chat/format_toolbar.test.js` (7), `test/lib/ui/menu_bar.test.js` (5),
  `test/lib/group_call/prejoin.test.js` (3): importam o controlador de `lib/`
  DIRETO (`createFormatToolbar`/`createMenuBar`/`createGroupCallPreJoin`) e o
  dirigem sem o hook. Reversão OK nos três (quebrar a decisão deixa vermelho).

**Aprendizado — a definição-de-pronto já estava satisfeita para estes três, mas
faltava a letra:** medi os testes de hook desses três com
`grep -oE 'hook\._[a-zA-Z]'` → **zero** acessos white-box. Eles já eram black-box
(dirigem DOM via `mountHook`), então "zero dependência de white-box para provar
lógica" já valia. O gap real era só o acoplamento ao wrapper de hook: nenhum teste
importava o controlador de `lib/`. Os testes diretos fecham isso e, no caso do
`menu_bar`, provam a afirmação do moduledoc de que ele roda em página pública sem
LiveSocket. O gap de verdade (white-box) é o `rtc_media_hook_factory`: o
`lobby_media_hook.test.js` alcança 6 métodos privados (`_startCall`,
`_handlePcReady`, `_handleRemoteTrack`, `_attachMediaElements`, `_sendersPc`,
`_toggleScreenShare`) — esse é o alvo do W-F2b, com teste direto black-box.

### W-C — file_transfer: framing + backpressure + verificação como puras · CONCLUÍDO

**Feito**
- `lib/p2p/file_transfer.js` ganhou 4 funções puras: `frameHaveChunks`/
  `unframeHaveChunks` (o enquadramento binário do have-chunks COM o type byte —
  antes inline no hook em `_sendHaveChunks`/`_handleIncomingHaveChunks`),
  `isBackpressured(bufferedAmount)` (`>= HIGH_WATER_MARK`) e
  `hashMatches(actual, expected)` (`===`). Testadas por bytes (round-trip do frame
  confirma o type byte; +10 casos).
- Hook: as três decisões passam pelas puras; o laço `_startSending` fica no hook
  (I/O). 586 → 580. Teste black-box do hook verde sem edição.
- Override de linha reescrito; `HIGH_WATER_MARK`/`encodeHaveChunks`/
  `decodeHaveChunks` saíram dos imports do hook.

**Aprendizado — a reversão distinguiu "gap de cobertura" de "cópia velha":** quebrar
as 3 puras deixou vermelho só o teste de lib; o teste de hook e o do reducer NÃO
reagiram (os caminhos de resume/backpressure/verify não são exercitados black-box
pelo teste de hook — é caro montar um DataChannel com `bufferedAmount` e um
transfer completo). Isso NÃO é o modo de falha perigoso ("hook chama a cópia
velha"): removi `encodeHaveChunks`/`decodeHaveChunks`/`HIGH_WATER_MARK` dos imports
do hook, então qualquer cópia inline dangling daria `ReferenceError` no load — e o
módulo do hook carrega verde. A prova de wiring é a ausência do símbolo antigo, não
a reação do teste de hook. Grep confirmou zero inline residual.

### W-F2b — teste de lib direto black-box para o rtc_media_hook_factory · CONCLUÍDO

**Feito**
- `test/lib/p2p/rtc_media_hook_factory.test.js` (8 casos): importa
  `createRtcMediaHook` de `lib/` DIRETO e dirige o hook produzido 100% black-box
  (mount + `handleEvent` via `simulateEvent` + `pc.ontrack`/CustomEvent pc-ready +
  cliques DOM), asserta em `pushEvent`, `FakeRTCPeerConnection.getSenders()`,
  `srcObject` e nos CustomEvents despachados. **Zero acesso a `produced._private`.**
  Cobre: mount/ready, start_video publica tracks, auto-start em fila até pc-ready,
  attach de track remoto, adoção multi-stream, screen-share on/off, republish em
  reconexão, end-call. Reversão independente confirmada (quebrar `replaceTrack`
  derruba o teste de screen-share; factory restaurado byte-a-byte).

**Aprendizado — testar uma FÁBRICA parametrizada com config sintético é o certo:**
o teste passa um `CONFIG` com as MESMAS chaves do consumidor real
(`lobby_media_hook.js`) mas VALORES sintéticos (`"test_pc_ready"` vs
`"lobby_media_pc_ready"`). Isso prova que a fábrica honra qualquer config que
receber — não acopla o teste aos nomes de evento do lobby. (Achado de passagem: a
fábrica despacha DOIS CustomEvents com nome literal `"lobby_media_recover"` e
`"lobby_media_source_changed"` — hardcoded, não derivados de config; pequeno cheiro
de acoplamento, registrado no ledger.) **Cobertura que NÃO deu p/ alcançar
black-box** (fica no teste white-box do hook, por isso a catraca de private não vai
a zero p/ o lobby_media): o watchdog de mídia parada (`_startMediaWatchdog` roda em
`setInterval` e depende de estado interno de `remoteStream`/`signalingState`) e o
fallback recvonly do auto-join (asserções são sobre estado interno `callType`/
`inCall`, não sobre push observável).

### W-D — lobby_webrtc: decisões de recuperação de sinalização · CONCLUÍDO

**Feito**
- `lib/p2p/signaling_session.js` (padrão idêntico ao `recovery.js`, funções puras):
  `canScheduleSignalReplay`/`signalReplayDelay`/`needsSignalReplay` (o `_scheduleSignalReplay`
  + `_needsSignalReplay`), `canScheduleRenegotiationRetry`/`renegotiationRetryDelay`/
  `isFinalRenegotiationAttempt` (o `_scheduleRenegotiationRetry`) e
  `canDeferDisconnectedRecovery` (o guard de adiamento do `_startDisconnectedGracePeriod`).
  Só as DECISÕES (backoff, guarda de agendamento, predicados); os `setTimeout`, as
  sondas de `pc` ao vivo e os `pushEvent` ficam no hook. 21 casos de lib.
- Testes black-box do hook (`lobby_webrtc_hook` + `lobby_webrtc_negotiation`, 30)
  verdes sem edição = equivalência. Override de linha reescrito.

**Aprendizado — a reversão do W-D foi a prova de wiring FORTE (ao contrário do W-C):**
quebrar as puras deixou vermelho o teste de lib E dois testes de hook ("requests
signaling replay while startup remains unresolved" → usa
`canScheduleSignalReplay`/`needsSignalReplay`; "enters recovery when renegotiation
requests are not answered" → usa `isFinalRenegotiationAttempt`). O hook realmente
dirige as decisões via as puras — o caminho é exercitado black-box, então a reversão
pega tanto extração incompleta quanto cópia velha. Nota: o hook CRESCEU de 1136 p/
1164 linhas (artefato do prettier quebrando as chamadas de 3-4 args em várias linhas);
o valor do W-D não é encolher (segue >200, resíduo = 1 pc ao vivo + timers + I/O), é
tornar backoff/tentativa/adiamento testáveis sem conexão.

### W-E slice 1 — group_call: registro de tracks · CONCLUÍDO

**Feito**
- `lib/group_call/track_registry.js` (`createTrackRegistry()`, Forma B pura — só
  dados, sem DOM): os 3 mapas de track (`byId`/`byStreamId`/`byWebrtcTrackId`) + a
  normalização (`upsert`, o `stringOrNull(x ?? y)` snake/camel + `source||"camera"`)
  + a precedência de lookup (`forTile` = stream id, senão browser track id) +
  `remove`/`byWebrtcTrackId`/`size`/`clear`. 12 casos de lib.
- Hook: `_syncTrack`/`_removeTrack`/`_applyTrackToTile`/stats/cleanup passam pelo
  registry; os 5 sites de mapa migraram. 2142 → 2111. Override reescrito.

**Aprendizado — o teste do god-hook é WHITE-BOX (fixture manual), então NÃO fica
"verde sem edição":** o `setupHook()` monta o hook à mão (`hook.tracksById = new
Map()` etc.), não via `mounted()`. Trocar a representação interna quebrou 14 testes
(`this.trackRegistry` indefinido) — o que, de quebra, PROVOU o wiring: se o hook não
usasse o registry em toda parte, remover `tracksById` não quebraria nada. A resposta
certa não é reverter: é trocar o scaffold (`hook.trackRegistry = createTrackRegistry()`)
e os 3 sites white-box (`hook.tracksById.set` → `upsert`, `.size` → `.size`) — troca
mecânica de representação, sem mudança de comportamento, e a contagem de `hook._`
(catraca) fica intacta porque `hook.tracksById`/`hook.trackRegistry` não casam `hook\._`.
Regra: teste black-box fica verde sem edição; teste white-box acoplado à representação
DEVE acompanhar a troca — e a quebra dele é o sinal de wiring.

**Slices restantes do W-E (não feitas aqui):** o mapa `participantsById` e o DOM de
tiles (`_createRemoteTile`/`_applyParticipantToTile`/`remoteTiles`) — mais arriscado
(entrelaçado com quality/layout/focus/local-tile). O irredutível continua sendo
`ontrack`/`onicecandidate`/`getUserMedia`.

### W-G — connection_status: controlador escondido num hook curto · CONCLUÍDO

**Feito**
- Medindo definições de método privado por hook (`^\s+_name(...) {`), o
  `connection_status_hook` (187 linhas, **8 métodos privados**) sobressaiu como um
  controlador disfarçado ABAIXO do teto de 200 linhas — o `_render` (estado→DOM),
  `_updateChatInputDisabled`/`_restoreDraftIfNeeded` (DOM + preservação de rascunho
  + RAF/setTimeout), `_updateShellDisabled` (DOM + menu). O W8 tinha extraído só o
  MAPEAMENTO (connection_view); a APLICAÇÃO ao DOM ficou presa.
- Extraído para `lib/connection/connection_status_view.js` (Forma B,
  `createConnectionStatusView(el, {onActionClick})`): mount/render/clearDraft/
  destroy + o rascunho e o shell-disable. Hook 187 → **109** linhas, 8 → 4 métodos
  privados. Teste black-box do hook (16) verde sem edição = equivalência; +8 de lib;
  reversão OK (quebrar o marcador de shell-disable derruba lib E o teste de shell do
  hook).

**Aprendizado — o snapshot pegou o `menubar:close-all` sumindo (fidelidade, não
regressão):** mover o `dispatchEvent("menubar:close-all")` do hook pro controlador
em `lib/` fez o evento SUMIR do snapshot — porque a seção `custom-events` só varria
`js/hooks/`, enquanto o listener dele (`menu_bar.js`) também já vive em `lib/`. A
correção é ESTENDER o grep pra `js/` (as outras 3 seções já varrem `js/`), não
mascarar. Regenerei: **puramente aditivo** (16 eventos de lib/entrypoint agora
rastreados — fullscreenchange, devicechange, etc. — e o `menubar:close-all` de
volta; ZERO remoções). Confirmei que ainda pega um rename real de evento (exit 1) e
volta a 0 restaurado. É a mesma lição do W6 (o grep de `push(...)`), agora para
`custom-events`.
