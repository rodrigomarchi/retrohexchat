# Ledger — refactor de padronização dos hooks JS

Uma linha por hook de implementação. Atualizado **no mesmo commit** do pacote
que mexe no hook. Ver [`js-hooks-progress.md`](js-hooks-progress.md) para o
diário e os aprendizados.

**Colunas:** linhas medidas no baseline · tem teste de hook · importa de `lib/` ·
faz `pushEvent` · pacote responsável · estado · módulos `lib/` criados · achados
adiados (a válvula que permite não corrigir nada de passagem — ao final do W8
precisa estar vazia).

Baseline: main @ a1c9376e, 18/08/2026.

## Hooks

| Hook | Linhas | Teste | Usa lib | pushEvent | Pacote | Estado | Módulos lib criados | Achados adiados |
|---|---|---|---|---|---|---|---|---|
| `group_call/group_call_webrtc_hook.js` | 2414→2035 | sim | sim | sim | W4·W5·W-E | **decisões + 3 controladores (track/participant/tile)** | p2p/negotiation, group_call/{quality,payload,reactions,layout,tiles,media_state,track_registry,participant_registry,tile_view} | resíduo: pc ao vivo (irredutível) + attach de `<video>` + mutação de dataset (bind de registros já decididos aos tiles) |
| `lobby/lobby_webrtc_hook.js` | 1164→**40** | sim | sim | sim | W4·W-D·W-H·W-H2 | **W-H2: casca real sobre controlador framework-free** | p2p/negotiation, p2p/signaling_session, **p2p/lobby_connection** (`createLobbyConnection(el, ports)`, 1155 linhas, dono do pc; 0 `this.pushEvent`/`this.el`/`this.handleEvent`/`mounted`) | — (part B feita: teste em `test/lib/p2p/lobby_connection.test.js`, 31 casos black-box; fake W-H corrigido) |
| `p2p/file_transfer_hook.js` | 663→580 | sim | sim | sim | W6·W-C | **W-C feito** | p2p/transfer_session (redutor); p2p/file_transfer.{frame,unframe}HaveChunks/isBackpressured/hashMatches | resíduo: laço de envio async + hash/assemble/download/timers (I/O) |
| `chat/autocomplete_hook.js` | 631→406 | sim | sim | sim | W7·W-A | **W-A feito** | chat/{composer,input,history_search,typing_indicator,tab_cycle,dropdown_position} | tab-cycle do cliente é dead code (ver Achados adiados) |
| `ui/retro_table_hook.js` | 586→32 | sim | sim | — | W1 | **concluído** | ui/retro_table{,_layout,_selection} | — |
| `chat/chat_viewport_hook.js` | 462 | sim | sim | sim | W2·W7 | **W2 feito** | — | input/long_press (W2) |
| `space/space_canvas_hook.js` | 412→364 | sim | sim | sim | W-B | **W-B feito** | space/{canvas_point,space_overlays,canvas_resizer} | — (saiu do override de primitiva: ResizeObserver foi pro resizer) |
| `chat/format_toolbar_hook.js` | 317 | sim | sim | — | W2 | **W2 feito** | — | chat/markdown_format |
| `group_call/group_call_prejoin_hook.js` | 316 | sim | sim | sim | W2·W8 | **W2 feito** | — | p2p/device_constraints+device_errors |
| `ui/contextual_tips_hook.js` | 229 | sim | sim | sim | W8 | pendente | — | — |
| `ui/preserve_scroll_hook.js` | 217→32 | sim | não | — | W3 | **W3 feito** | — | ui/scroll_preservation |
| `system/metric_chart_hook.js` | 217→35 | não | não | sim | W3 | **W3 feito** | — | system/metric_chart |
| `connection/connection_status_hook.js` | 212→187→109 | sim | sim | sim | W8·W-G | **W-G feito** | connection/{connection_view,connection_status_view} | — (controlador escondido extraído; 8→4 métodos privados) |
| `ui/conversations_hook.js` | 189 | sim | sim | sim | W2 | **W2 feito** | — | input/long_press |
| `ui/nicklist_hook.js` | 173 | sim | sim | sim | W2 | **W2 feito** | — | input/long_press |
| `ui/infinite_scroll_hook.js` | 149 | sim | sim | sim | — | pendente | — | — |
| `p2p/p2p_diagram_hook.js` | 146→ | não | não | — | W3 | **W3 feito** | — | p2p/diagram |
| `connection/connect_form_hook.js` | 138 | sim | sim | — | W8 | pendente | — | — |
| `chat/search_highlight_hook.js` | 137 | sim | sim | sim | W8 | pendente | — | — |
| `games/retro_game_canvas_hook.js` | 135 | sim | sim | sim | referência | pendente | — | — |
| `ui/viewport_detect_hook.js` | 115→ | sim | não | sim | W3 | **W3 feito** | — | ui/viewport |
| `lobby/lobby_game_canvas_hook.js` | 115 | não | sim | sim | W8 | pendente | — | — |
| `lazy_feature_hook.js` | 99 | sim | não | — | infra | pendente | — | — |
| `games/arcade_session_hook.js` | 93 | sim | não | sim | W8 | pendente | — | — |
| `ui/context_menu_hook.js` | 80 | sim | sim | sim | — | pendente | — | — |
| `chat/chat_pagination_hook.js` | 69 | sim | não | sim | W8 | pendente | — | — |
| `ui/char_counter_hook.js` | 62 | sim | sim | — | — | pendente | — | — |
| `input/shortcut_dispatcher_hook.js` | 61 | sim | sim | sim | W2 | **W2 feito** | — | ui/dom.isEditableTarget |
| `ui/toolbar_group_hook.js` | 50 | não | não | — | W8 | pendente | — | — |
| `lobby/lobby_media_hook.js` | 50 | sim | sim | — | — | pendente | — | — |
| `connection/lag_hook.js` | 50 | sim | sim | sim | — | pendente | — | — |
| `input/sound_hook.js` | 49 | sim | sim | — | — | pendente | — | — |
| `notifications/document_title_hook.js` | 46 | sim | sim | sim | — | pendente | — | — |
| `chat/paste_hook.js` | 42 | sim | sim | sim | — | pendente | — | — |
| `ui/window_manager_hook.js` | 37 | sim | sim | sim | referência | pendente | — | — |
| `ui/public_window_manager_hook.js` | 37 | não | sim | sim | W8 | pendente | — | — |
| `chat/emoji_picker_hook.js` | 35 | sim | não | sim | — | pendente | — | — |
| `showcase/highlight_hook.js` | 34 | não | não | — | W8 | pendente | — | — |
| `help/help_nav_hook.js` | 33 | não | não | — | W8 | pendente | — | — |
| `input/keyboard_hook.js` | 29 | sim | sim | sim | — | pendente | — | — |
| `connection/clock_hook.js` | 26 | sim | sim | — | — | pendente | — | — |
| `ui/menu_bar_hook.js` | 24 | sim | sim | — | referência | pendente | — | — |
| `ui/menu_reposition_hook.js` | 21 | não | sim | — | W8 | pendente | — | — |
| `ui/focus_chat_input_on_click_hook.js` | 21 | não | não | — | W8 | pendente | — | — |
| `ui/url_catcher_hook.js` | 18 | sim | sim | — | — | pendente | — | — |
| `notifications/notify_list_hook.js` | 18 | sim | sim | sim | — | pendente | — | — |
| `chat/nick_change_form_hook.js` | 14 | sim | não | — | — | pendente | — | — |

## Fora de escopo (commits próprios, nunca dentro de um pacote)

| Item | Estado |
|---|---|
| 6 strings visíveis sem `t()` (space loading; `_participantQualityLabel`, `_participantQualityTitle`, badge Speaking) | pendente |
| `enforce_hooks_contract.cjs:8` doc ref quebrada | **feito** (commit d3e0a9c1) |
| `rtc_media_hook_factory.js`: 1 consumidor, ramos mortos | **des-parametrizado** (commit 7fa139d8); **teste de lib direto black-box feito (W-F2b, 8 casos, zero private)**. O `lobby_media_hook.test.js` ainda alcança 6 privados p/ o watchdog e o fallback recvonly (não alcançáveis black-box) → alvo do W-F1/F3 é reduzir os OUTROS, não zerar |
| Testes de lib diretos p/ format_toolbar, menu_bar, prejoin | **feito (W-F2a)** — antes só via hook (mas já black-box); agora `createX` de `lib/` testado direto |
| 9 hooks sem teste | pendente (consequência de W1–W7; resto em W8) |

## Achados adiados (bugs/gaps fora do escopo do movimento)

A válvula que permite não corrigir nada de passagem: um achado vira linha aqui e
o refactor segue sem embrulhar a correção no movimento. Cada item vira tarefa
própria ou é descartado com justificativa.

| Achado | Onde | Estado |
|---|---|---|
| **Tab-cycle do cliente é dead code.** O echo síncrono de `dispatchEvent("input")` zera `tabCycleState` antes de o `setTimeout(0)` capturar `preserved`, então `tabCycleActive` é sempre `false` e o ciclo roda no servidor via `tab_complete` repetido. `createTabCycle.advance()` nunca é alcançado no browser. | `lib/chat/tab_cycle.js` + `autocomplete_hook.js` input listener | **aberto** — corrigir (capturar `preserved` antes do dispatch, ou guardar o echo) muda comportamento observável → commit próprio, não dentro de um movimento |
| **`end_call` server event com payload vazio NÃO empurra `call_ended`.** O handler passa `{notify: payload.notify === true}`; um `end_call` do servidor com `{}` encerra em silêncio (assimetria vs. o botão DOM, que notifica). | `lib/p2p/rtc_media_hook_factory.js` handler de `endCall` | **aberto** — comportamento existente, não regressão; validar se é intencional antes de mexer |
| **A fábrica de mídia despacha 2 CustomEvents com nome literal** (`lobby_media_recover`, `lobby_media_source_changed`) hardcoded, enquanto todo o resto é derivado de `config`. Pequeno acoplamento ao consumidor lobby. | `lib/p2p/rtc_media_hook_factory.js:727,1127` | **aberto** — mover p/ `config.clientEvents` seria mudança comportamental (nomes de evento) → commit próprio |
| **E2E pré-existente vermelho na `main`:** `chat-call-fault-injection.spec.ts:348` ("P2P answerer reloads while applying the initial offer and reconnects media") falha no código ORIGINAL (HEAD), antes de qualquer mudança minha — confirmado via baseline. `chat-p2p.spec.ts:616` é flaky (passa no re-run). | `e2e/tests/` | **aberto** — não é regressão do refactor; é dívida de teste/timing de E2E pré-existente, tarefa própria |
| **W-E slice 3 (criação/lifecycle de tiles) — FEITA** (revertida a decisão de descartar). Depois de rodar o E2E de group-call e ver que serve de gate (N1/N4/N5/N12/N14/N15/N6 verdes), extraí o mapa `remoteTiles` + `_createRemoteTile`/queries pra `lib/group_call/tile_view.js` (Forma B, DOM num controlador, porta `onToggleFocus`). Provado com o E2E RE-rodado verde após a extração. | `tile_view.js` | **feito** — o "risco" era exagerado meu; com o E2E como rede, era extraível. Sobra no hook o attach de `<video>` e a mutação de dataset (bind), não decisão |

## Legenda de pacote

W1 RetroTable · W2 duplicações · W3 os quatro sem seam · W4 negociação WebRTC ·
W5 fatiar a conferência · W6 file_transfer · W7 composer · W8 varredura.
Hooks sem pacote atribuído já estão finos (≤ ~150 linhas, delegam a `lib/`) e
ficam como estão; `n/a` em "usa lib" = pequeno demais para precisar de um.

## Estado ao fim do W8

Catracas em CI (só descem): teto 200 linhas/hook (overrides: os 10 hooks ainda
grandes, cada um com o pacote ou a razão do resíduo) · `MAX_HOOK_PRIVATE_CALLS=184`
· primitivas proibidas (5 hooks WebRTC/canvas, override) · estado de módulo em
`lib/` (3 singletons deliberados). Superfície observável pinada por
`scripts/surface_snapshot.sh --check`.

## Estado ao fim da segunda onda (W-A…W-G, W-F2, W-F3)

Hooks > 200 linhas restantes (6), cada um com override cujo motivo descreve resíduo
de I/O, sem decisão presa: `group_call_webrtc` (2106 — pc ao vivo + bind de tiles),
`lobby_webrtc` (1164 — pc ao vivo + timers/ICE), `file_transfer` (580 — loop async +
hash/download), `autocomplete` (406 — binding de input + plumbing de history),
`chat_viewport` (362 — binding de reader-interactions), `space_canvas` (363 —
Socket/pointer I/O).

Catracas em CI (só descem):
- teto 200 linhas/hook (6 overrides, cada um com resíduo de I/O descrito);
- **`MAX_HOOK_PRIVATE_METHODS = 7`** (NOVA, W-F3) — pega controlador escondido em
  hook curto; 4 overrides (os hooks WebRTC/canvas grandes);
- `MAX_HOOK_PRIVATE_CALLS = 150` — abaixado de 184 no W-F1 (migração lobby_media + group_call para black-box via superfície real de eventos). Baixar exige migrar os testes
  de integração WebRTC (`group_call`, `lobby_media`) para black-box; o watchdog de
  mídia parada e a negociação/stats genuinamente precisam de white-box (ver progresso
  W-F2b), então 184 é o piso real sem uma reescrita de teste dedicada;
- primitivas proibidas — só `group_call_webrtc` agora (space_canvas saiu no W-B);
- estado de módulo em `lib/` (3 singletons deliberados).

Superfície: `custom-events` agora varre `js/` (W-G), acompanhando eventos que se
mudam pra controladores de `lib/`.

Follow-ups rastreados em [`js-hooks-progress.md`](js-hooks-progress.md) (seção W8):
resíduo WebRTC (>200, controladores Forma B precisam de testes de integração),
W7.3/W7.4, i18n dos labels de qualidade (design payload/display),
des-parametrização do `rtc_media_hook_factory`, alias `loadRecentCommands`,
cobertura de hooks finos.
