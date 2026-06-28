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
