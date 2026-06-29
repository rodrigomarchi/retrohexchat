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

- [x] Criar `SearchComponent` (`ChatLive.Components.SearchBar`, primeiro LiveComponent stateful do app).
- [x] Mover todos os `search_*` assigns de **conteudo** para o componente (query, results, filtros, indice, error, history_count, last_query). `search_visible` permanece no parent **por design** — o mapa de Escape-dismissal e o stacking de overlays em `KeyboardEvents` coordenam sobre assigns do parent.
- [x] Debounce input de busca no HEEx (`phx-debounce="300"`, preservado no primitivo `search_bar`).
- [x] Executar busca pesada com async (history `count_matches` via `start_async/3` no componente, com stale-guard por query; `search_messages`/`results` — estado morto, nunca renderizado — removido junto).
- [ ] Enviar resultados ao `MessageViewportComponent` por mensagem/update (viewport ainda nao extraido; highlight continua via `push_event` para o JS hook).
- [ ] Mover `SearchHighlightHook` para search ou viewport (hook ainda na message list do parent).
- [ ] Remover `search_events.ex` da pipeline global (mantido como **adaptador** que faz `send_update` ao componente, preservando contratos de evento legados).

## Validacao

- [x] Abrir/fechar busca nao altera mensagens nem composer.
- [x] Filtros case/regex/mentions funcionam.
- [x] Navegacao next/prev rola para o resultado (`push_event("search_scroll_to")` preservado, agora emitido pelo componente).
- [x] Busca grande nao congela LiveView (history search agora async; digitacao nunca bloqueia no DB).
- [x] Erros de regex aparecem localmente.

## Prompt de execucao

Primeiro preserve comportamento com LiveComponent stateful. Depois torne a busca async e desacoplada do parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **Fase 1+2: ownership do conteudo extraido para o primeiro LiveComponent stateful do app.**
  - Escopo: mover o estado de conteudo da busca para um LiveComponent stateful, preservando 100% dos contratos publicos (data-testids, nomes de eventos legados). `search_visible` fica no parent por design (coordenacao de Escape/overlay).
  - Arquivos tocados:
    - `live/chat_live/components/search_bar.ex` (novo) — LiveComponent stateful; dono de query/results/filtros/indice/error/history_count/last_query; emite `push_event` (`search_highlight`, `search_scroll_to`, `search_clear_highlights`) e roda a busca de historico (`Chat.Search`). Protocolo de acao dirigido por `send_update` do parent (`:open`/`:close`/`{:input,q}`/`:next`/`:prev`/`{:navigate,k}`/`{:toggle_filter,f}`/`{:highlight_count,c,err}`).
    - `live/chat_live/search_events.ex` — reescrito como **adaptador**: nomes de evento legados continuam disparando no parent e sao encaminhados ao componente via `send_update`. `open/1` e `close/1` expostos e reutilizados por keyboard/menu/core.
    - `live/app/chat_live.ex` — removidos 10 assigns `search_*` de conteudo do `assign_defaults` (resta `search_visible`); removido `import ...UI.SearchBar` (nao usado).
    - `live/app/chat_live.html.heex` — `<.search_bar>` (function component) -> `<.live_component module={Components.SearchBar} ...>` sempre montado (para `send_update` funcionar mesmo fechado); recebe `visible`, `nickname`, `active_channel`.
    - `live/chat_live/core_events.ex` (`clear_search_on_switch`), `keyboard_events.ex` (`:toggle_search` + Escape `clear_search_state`), `menu_toolbar_events.ex` (`open_search`) — agora delegam a `SearchEvents.open/close`.
    - `test/.../live/search_highlight_test.exs` — atualizado: assercoes de estado do componente leem via `render(view)` (flush da mensagem de `send_update`, que e processada apos o `render_*` que a disparou). Comportamento testado identico.
    - `test/.../live/chat_live/components/search_bar_test.exs` (novo) — teste de componente (smoke de markup: visivel/oculto, root estavel para `send_update`).
  - Descoberta tecnica: `send_update/2` dentro de `handle_event` e processado de forma assincrona; `render_click/render_change` retornam antes do update do componente. Sob `LiveViewTest`, um `render(view)` subsequente faz o flush (mailbox FIFO: a msg de send_update e processada antes do novo render). E2E nao e afetado (cliente real aplica os diffs). Padrao registrado para os proximos componentes stateful.
  - Validacao: `make ci` **9/9** (compile, JS lint/test, format, credo, css, tests, **feature tests**, dialyzer). `search_highlight_test` 17/0; `search_bar_test` 3/0; `keyboard_shortcuts_test` + `window_display_edit_menu_feature_test` verdes. E2E focado (`chat-search*`): 5 falhas, **todas pre-existentes em `main` limpo** (provado via `git stash` baseline) — O6/O7 (view-menu stale, ja documentado) + S7/S8/S9 (history/navigation/window-state, agora confirmados como baseline). **Zero regressao nova.** Page Object inalterado (contratos preservados) — `tsc` nao necessario.
  - Status: `in_progress`. Falta a parte async (history search) e a coordenacao com o `MessageViewportComponent` (mover `SearchHighlightHook`, remover o adaptador `search_events.ex`), que dependem da extracao do viewport (plano 10/11).
- 2026-06-28 (cont.) — **History search async + limpeza de estado morto.**
  - `Search.count_matches` agora roda via `start_async(:history_count, ...)` no componente, com guarda de resultado obsoleto (tag por query; aplica so se `query`/`history` ainda batem). DOM highlight continua sincrono (rapido). `result_count = max(dom_count, history_count)` derivado em `recount/1` tanto no `handle_async` quanto no `{:highlight_count}`.
  - Removido estado morto: `search_messages`/`results` nunca eram renderizados (provado por grep) — eliminada a query inutil (ganho de perf).
  - Testes: 2 novos feature tests (`render_async`) — count resolve via DB async (`1/2`) e stale-guard (`0/0` apos limpar query). `make ci` **9/9** novamente.
  - **Itens 2/3/4 do checklist sao bloqueados por dependencia real do viewport (plano 10/11)**, nao escolha: `SearchHighlightHook` vive no DOM da lista de mensagens; remover o adapter exige `phx-target` + hook no viewport. Extrair o viewport DESBLOQUEIA o fechamento do plano 09.
  - **Aprendizados desta rodada destilados em `docs/plans/STATEFUL-COMPONENT-PLAYBOOK.md`** (receita para os 50+ pontos restantes).
