# Channel List Dialog Migration

## Objetivo

Migrar Channel List para componente stateful com busca/filtro/loading e resultado local.

## Classificação para execução (agentes)

- **Tier:** ✅ Mecânico (PRIORIDADE 1)
- **Dependências:** Independente.
- **Componente de referência:** `Components.UrlCatcherDialog` (42, filter/sort/search).
- **Abordagem:** 0 sub-forms. Busca CONTROLADA; channels/filtered/loading = PASSTHROUGH (carregados por comando/PubSub no parent); select/join sobem como adapters; Escape-managed → `visible` passthrough.
- **Gotchas:** Não mover o carregamento async — só passthrough da lista.
- **Validação:** `make ci` 9/9 + E2E channel-list.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:631`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_list.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/channel_list_events.ex`
- State atual: `show_channel_list`, `channel_list_channels`, `channel_list_filtered`, `channel_list_selected`, `channel_list_search`, `channel_list_loading`, `channel_list_count`.

## Tecnica

Use LiveComponent stateful com async para carregar canais. Use stream para lista se houver muitos canais. Debounce busca local.

## Tasks

- [x] Criar `Components.ChannelListDialog`.
- [x] Mover state de filtro/selecao para o componente; lista/loading = passthrough.
- [~] Carregar canais com `start_async/3` — N/A: o carregamento é síncrono/barato (`Autocomplete.list_visible_channels`) e já vem do parent (passthrough); não foi movido (gotcha do plano: "não mover o carregamento async").
- [~] Stream/virtualizacao — N/A nesta fatia (lista pequena; sem mudança de perf necessária).
- [x] Emitir `join`/`knock` ao parent (adapters carregando `phx-value-channel`).
- [x] Resetar selecao/busca ao abrir (`send_update :open`); view não persiste entre aberturas.

## Validacao

- [ ] Abrir mostra loading e depois canais.
- [ ] Busca filtra rapido sem patch global.
- [ ] Join/knock funciona.
- [ ] Lista grande nao degrada DOM.
- [ ] Fechar/reabrir nao deixa loading preso.

## Prompt de execucao

Este dialog e candidato forte a async + stream. Nao carregue lista inteira no parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE** (17º LiveComponent stateful). `Components.ChannelListDialog`.
  - **Ownership:** parent mantém `show_channel_list` (Escape `secondary_dismissals` → `visible`), `channel_list_channels` (lista crua, passthrough) e `channel_list_loading` (passthrough). Componente é dono de `search` + `selected` e deriva `filtered` (a lógica de filtro/select migrou pra dentro). Removidos do parent: `channel_list_filtered`, `channel_list_selected`, `channel_list_search`, `channel_list_count` (count era morto — não renderizado).
  - **Eventos = ADAPTERS string** (preserva contratos LiveViewTest disparados por nome + selectors E2E). `channel_list_filter`/`channel_list_select` viram `send_update` async pro componente; `channel_list_join`/`channel_list_knock`/`close_channel_list` sobem pro parent (precisam de session / abrem knock / Escape-managed). `join`/`knock` leem `channel` de params (`phx-value-channel={@selected}`).
  - **3 caminhos de abertura unificados** em `ChannelListEvents.open/1` (menu/toolbar `channel_list`, `/list` via `UiActions.Core`, conversations "browse all"); `close/1` exposto e usado pelo `keyboard_events` (delegação). `conversations_events.filter_channels/2` removido (morto); `Autocomplete` alias removido de `core.ex`.
  - **Testes:** `channel_list_dialog_test` (componente, novo, 4 tests `@moduletag :unit`); os filter/select tests do `ChannelListDialogTest` (liveview) + 1 ponto do `channel_membership_feature_test` ajustados pro flush `render(view)` (send_update async §2). `make ci` **9/9**; E2E `chat-channel-list` H8 green.
