# URL Catcher Dialog Migration

## Objetivo

Migrar URL Catcher para componente stateful com lista, filtros, ordenacao, busca e previews/cache isolados.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:858`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/url_catcher.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/url_catcher_events.ex`
- URL capture helper: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex:73`
- State atual: `show_url_catcher`, `url_catcher_entries`, `url_catcher_filter_channel`, `url_catcher_search_query`, `url_catcher_sort_column`, `url_catcher_sort_direction`, `link_previews`.

## Tecnica

Use LiveComponent stateful com stream ou pagination para entries. Captura de URL deve ser evento de dominio que adiciona entry ao componente quando aberto e/ou cache persistente. Filtros e ordenacao ficam locais.

## Tasks

- [ ] Criar `UrlCatcherDialogComponent`.
- [ ] Mover filter/search/sort para o componente.
- [ ] Decidir se `url_catcher_entries` fica em componente, ETS/cache ou session context.
- [ ] Usar stream para rows se muitas URLs.
- [ ] Mover `URLCatcherHook` para o componente.
- [ ] Manter preview fetch async sem capturar socket.
- [ ] Emitir open URL/copy localmente quando possivel.

## Validacao

- [ ] URLs capturadas de canal e PM aparecem.
- [ ] Sort/filter/search funcionam.
- [ ] Lista grande nao re-renderiza chat inteiro.
- [ ] Previews nao duplicam fetch.
- [ ] Fechar/reabrir preserva entradas conforme regra escolhida.

## Prompt de execucao

URL Catcher e historico derivado de mensagens. Evite guardar tudo no parent; escolha componente com cache ou contexto dedicado.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **COMPLETE** (batch com 34 + 48). `Components.UrlCatcherDialog` (LiveComponent; padrao filter/sort/search). Escape-managed → parent mantem `show_url_catcher` (`visible`). O log de captura `url_catcher_entries` NAO e estado de UI do dialog — e acumulado no parent (de mensagens via `helpers/session.ex` + add manual via `context_menu_events.ex`), entao FICA no parent e vai por passthrough. O componente e dono so do estado de view: `sort_column`/`sort_direction`/`filter_channel`/`search_query` (eventos component-local `@myself`); os helpers `filtered_url_catcher_entries` + `url_catcher_channels` migraram pra DENTRO do componente. Close NAO reseta (comportamento legado: a view persiste entre aberturas) → sem `:reset`. `url_catcher_events.ex` ficou so com toggle/close (flip do show). Removidos 4 assigns de view + 2 helpers + alias `CapturedURL` do parent. Validacao: `make ci` **9/9**; `url_catcher_dialog_test` 3/0; E2E `chat-url-catcher` O15 verde.
