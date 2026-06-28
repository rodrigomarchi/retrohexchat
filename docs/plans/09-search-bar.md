# Search Bar Migration

## Objetivo

Migrar busca para componente stateful dono de query, filtros, indice atual, resultados e erro.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:186`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/search_bar.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/search_events.ex`
- State atual: `search_visible`, `search_query`, `search_result_count`, `search_current_index`, `search_error`, `search_case_sensitive`, `search_regex`, `search_my_mentions`, `search_history`.

## Tecnica

Use LiveComponent stateful. Para busca em historico/DB, use `start_async/3` no componente ou parent com resposta para componente; nao bloquear evento de digitacao. Para highlight no DOM, coordene com `MessageViewportComponent`.

## Tasks

- [ ] Criar `SearchComponent`.
- [ ] Mover todos os `search_*` assigns para o componente.
- [ ] Debounce input de busca no HEEx.
- [ ] Executar busca pesada com async.
- [ ] Enviar resultados ao `MessageViewportComponent` por mensagem/update.
- [ ] Mover `SearchHighlightHook` para search ou viewport.
- [ ] Remover `search_events.ex` da pipeline global.

## Validacao

- [ ] Abrir/fechar busca nao altera mensagens nem composer.
- [ ] Filtros case/regex/mentions funcionam.
- [ ] Navegacao next/prev rola para o resultado.
- [ ] Busca grande nao congela LiveView.
- [ ] Erros de regex aparecem localmente.

## Prompt de execucao

Primeiro preserve comportamento com LiveComponent stateful. Depois torne a busca async e desacoplada do parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
