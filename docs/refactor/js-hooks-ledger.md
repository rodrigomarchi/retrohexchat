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
| `group_call/group_call_webrtc_hook.js` | 2414→2134 | sim | sim | sim | W4·W5 | **decisões extraídas** | p2p/negotiation, group_call/{quality,payload,reactions,layout,tiles,media_state} | resíduo: plumbing RTCPeerConnection+tile-DOM (controller Forma B = follow-up c/ testes de integração) |
| `lobby/lobby_webrtc_hook.js` | 1152 | sim | sim | sim | W4 | **W4 feito** | p2p/negotiation | ainda >200; épocas+timers no hook |
| `p2p/file_transfer_hook.js` | 663→586 | sim | sim | sim | W6 | **W6 feito** | p2p/transfer_session (redutor) | teste white-box reescrito p/ black-box no W8 |
| `chat/autocomplete_hook.js` | 631→406 | sim | sim | sim | W7·W-A | **W-A feito** | chat/{composer,input,history_search,typing_indicator,tab_cycle,dropdown_position} | tab-cycle do cliente é dead code (ver Achados adiados) |
| `ui/retro_table_hook.js` | 586→32 | sim | sim | — | W1 | **concluído** | ui/retro_table{,_layout,_selection} | — |
| `chat/chat_viewport_hook.js` | 462 | sim | sim | sim | W2·W7 | **W2 feito** | — | input/long_press (W2) |
| `space/space_canvas_hook.js` | 412→364 | sim | sim | sim | W-B | **W-B feito** | space/{canvas_point,space_overlays,canvas_resizer} | — (saiu do override de primitiva: ResizeObserver foi pro resizer) |
| `chat/format_toolbar_hook.js` | 317 | sim | sim | — | W2 | **W2 feito** | — | chat/markdown_format |
| `group_call/group_call_prejoin_hook.js` | 316 | sim | sim | sim | W2·W8 | **W2 feito** | — | p2p/device_constraints+device_errors |
| `ui/contextual_tips_hook.js` | 229 | sim | sim | sim | W8 | pendente | — | — |
| `ui/preserve_scroll_hook.js` | 217→32 | sim | não | — | W3 | **W3 feito** | — | ui/scroll_preservation |
| `system/metric_chart_hook.js` | 217→35 | não | não | sim | W3 | **W3 feito** | — | system/metric_chart |
| `connection/connection_status_hook.js` | 212 | sim | sim | sim | W8 | pendente | — | — |
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
| `rtc_media_hook_factory.js`: 1 consumidor, ramos mortos | **des-parametrizado** (commit 7fa139d8); teste de lib direto black-box = W-F2b (o `lobby_media_hook.test.js` ainda alcança 6 privados) |
| Testes de lib diretos p/ format_toolbar, menu_bar, prejoin | **feito (W-F2a)** — antes só via hook (mas já black-box); agora `createX` de `lib/` testado direto |
| 9 hooks sem teste | pendente (consequência de W1–W7; resto em W8) |

## Achados adiados (bugs/gaps fora do escopo do movimento)

A válvula que permite não corrigir nada de passagem: um achado vira linha aqui e
o refactor segue sem embrulhar a correção no movimento. Cada item vira tarefa
própria ou é descartado com justificativa.

| Achado | Onde | Estado |
|---|---|---|
| **Tab-cycle do cliente é dead code.** O echo síncrono de `dispatchEvent("input")` zera `tabCycleState` antes de o `setTimeout(0)` capturar `preserved`, então `tabCycleActive` é sempre `false` e o ciclo roda no servidor via `tab_complete` repetido. `createTabCycle.advance()` nunca é alcançado no browser. | `lib/chat/tab_cycle.js` + `autocomplete_hook.js` input listener | **aberto** — corrigir (capturar `preserved` antes do dispatch, ou guardar o echo) muda comportamento observável → commit próprio, não dentro de um movimento |

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

Follow-ups rastreados em [`js-hooks-progress.md`](js-hooks-progress.md) (seção W8):
resíduo WebRTC (>200, controladores Forma B precisam de testes de integração),
W7.3/W7.4, i18n dos labels de qualidade (design payload/display),
des-parametrização do `rtc_media_hook_factory`, alias `loadRecentCommands`,
cobertura de hooks finos.
