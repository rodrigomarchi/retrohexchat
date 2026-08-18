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
| `group_call/group_call_webrtc_hook.js` | 2414 | sim | sim | sim | W4·W5 | pendente | — | — |
| `lobby/lobby_webrtc_hook.js` | 1152 | sim | sim | sim | W4 | pendente | — | — |
| `p2p/file_transfer_hook.js` | 663 | sim | sim | sim | W6 | pendente | — | — |
| `chat/autocomplete_hook.js` | 631 | sim | sim | sim | W7 | pendente | — | — |
| `ui/retro_table_hook.js` | 586→32 | sim | sim | — | W1 | **concluído** | ui/retro_table{,_layout,_selection} | — |
| `chat/chat_viewport_hook.js` | 462 | sim | sim | sim | W2·W7 | pendente | — | — |
| `space/space_canvas_hook.js` | 408 | sim | sim | sim | W8 | pendente | — | — |
| `chat/format_toolbar_hook.js` | 317 | sim | sim | — | W2 | pendente | — | — |
| `group_call/group_call_prejoin_hook.js` | 316 | sim | sim | sim | W2·W8 | pendente | — | — |
| `ui/contextual_tips_hook.js` | 229 | sim | sim | sim | W8 | pendente | — | — |
| `ui/preserve_scroll_hook.js` | 217 | sim | não | — | W3 | pendente | — | — |
| `system/metric_chart_hook.js` | 217 | não | não | sim | W3 | pendente | — | — |
| `connection/connection_status_hook.js` | 212 | sim | sim | sim | W8 | pendente | — | — |
| `ui/conversations_hook.js` | 189 | sim | sim | sim | W2 | pendente | — | — |
| `ui/nicklist_hook.js` | 173 | sim | sim | sim | W2 | pendente | — | — |
| `ui/infinite_scroll_hook.js` | 149 | sim | sim | sim | — | pendente | — | — |
| `p2p/p2p_diagram_hook.js` | 146 | não | não | — | W3 | pendente | — | — |
| `connection/connect_form_hook.js` | 138 | sim | sim | — | W8 | pendente | — | — |
| `chat/search_highlight_hook.js` | 137 | sim | sim | sim | W8 | pendente | — | — |
| `games/retro_game_canvas_hook.js` | 135 | sim | sim | sim | referência | pendente | — | — |
| `ui/viewport_detect_hook.js` | 115 | sim | não | sim | W3 | pendente | — | — |
| `lobby/lobby_game_canvas_hook.js` | 115 | não | sim | sim | W8 | pendente | — | — |
| `lazy_feature_hook.js` | 99 | sim | não | — | infra | pendente | — | — |
| `games/arcade_session_hook.js` | 93 | sim | não | sim | W8 | pendente | — | — |
| `ui/context_menu_hook.js` | 80 | sim | sim | sim | — | pendente | — | — |
| `chat/chat_pagination_hook.js` | 69 | sim | não | sim | W8 | pendente | — | — |
| `ui/char_counter_hook.js` | 62 | sim | sim | — | — | pendente | — | — |
| `input/shortcut_dispatcher_hook.js` | 61 | sim | sim | sim | W2 | pendente | — | — |
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
| `rtc_media_hook_factory.js`: 1 consumidor, ramos mortos — decidir adotar na conferência ou des-parametrizar | pendente (decidir em W5.6) |
| 9 hooks sem teste | pendente (consequência de W1–W7; resto em W8) |

## Legenda de pacote

W1 RetroTable · W2 duplicações · W3 os quatro sem seam · W4 negociação WebRTC ·
W5 fatiar a conferência · W6 file_transfer · W7 composer · W8 varredura.
Hooks sem pacote atribuído já estão finos (≤ ~150 linhas, delegam a `lib/`) e
ficam como estão; `n/a` em "usa lib" = pequeno demais para precisar de um.
