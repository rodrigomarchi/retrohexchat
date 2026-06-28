# Chat Event Routing Migration

## Objetivo

Trocar a pipeline linear de hooks de eventos por roteamento explicito por dono do evento. Eventos locais devem ir direto ao componente stateful com `phx-target={@myself}`. Eventos globais devem ficar no parent.

## Codigo atual

- Dispatcher geral: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:281`
- Catch-all de eventos: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:317`
- Lista linear de handlers: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:517`
- Attach hooks duplicando a lista: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:571`
- Event modules em `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/*_events.ex`

## Tecnica

Use roteamento por dominio:

- Eventos de componente: `phx-target={@myself}`.
- Eventos cross-component: componente envia `send(self(), {:chat_action, ...})` ao parent ou usa callback/evento padronizado.
- Eventos globais: `window_keydown`, reconnect, PubSub e takeover ficam no parent.
- Eventos legados: manter adaptador temporario ate todos os componentes sairem do hook pipeline.

## Tasks

- [ ] Criar tabela `@global_events` no parent somente para eventos realmente globais.
- [x] Mapear cada evento de `@event_hook_fns` para dono final. Ver `02-event-ownership-map.md` (artefato derivado do codigo, com classificacao global/→plano e adaptadores).
- [ ] Migrar primeiro eventos quentes: `input_changed`, `send_input`, autocomplete, load_more, scroll, context menu.
- [ ] Adicionar `phx-target={@myself}` nos componentes stateful.
- [ ] Criar callbacks claros: `on_send`, `on_command`, `on_switch_channel`, `on_open_dialog`.
- [ ] Remover `dispatch_to_hooks/3` quando a ultima rota local migrar.
- [ ] Evitar nomes genericos como `close_dialog`; usar eventos por componente.

## Validacao

- [ ] Nenhum evento local percorre 30 modulos ate encontrar handler.
- [x] Eventos desconhecidos ficam visiveis em log de dev, sem crashar usuario.
- [ ] Testes de input, autocomplete, teclado, context menus e dialogs passam.
- [ ] A contagem de chamadas ao dispatcher cai em cenarios de digitacao e hover.
- [ ] Nao ha regressao em menu toolbar e shortcuts globais.

## Prompt de execucao

Trate evento como ownership: se um componente renderiza o botao/input/menu, ele deve ser o primeiro candidato a processar o evento. O parent so deve saber o resultado semantico.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.

### 2026-06-27 — Ownership map + dev visibility de eventos nao roteados

Escopo: deliverable de mapeamento (sem mover handlers ainda) + tornar a
fall-through do dispatcher observavel.

Arquivos tocados:

- `docs/plans/02-event-ownership-map.md` (novo) — mapa autoritativo derivado do
  codigo: todos os eventos por modulo, classificacao global/→plano, lista de
  adaptadores em `chat_live.ex`, e comando de regeneracao.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex` —
  `dispatch_to_hooks/3`: ramo "nenhum hook reivindicou o evento" agora emite
  `Logger.debug` em vez de engolir silenciosamente. Socket retornado intacto;
  nunca derruba a sessao.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/event_routing_test.exs`
  (novo) — regressao: evento desconhecido mantem a sessao viva e renderizavel.

Validacao executada:

- `mix compile --warnings-as-errors` — limpo.
- `mix format` + `mix credo` no `chat_live.ex` — sem issues.
- `mix test .../chat_live/ messaging_ui_feature_test keyboard_shortcuts_test`
  (`--include liveview_feature --include liveview`) — 22 testes, 0 falhas.

Nota de contrato: nenhum `data-testid`/id/evento publico mudou. Adaptadores v1
(`toolbar_action`, `switch_tab`, `*_context_action`) preservados — Playwright
nao impactado neste slice.

Pendente: criar o atributo `@global_events` em codigo (so quando o roteamento
realmente consumir), migrar eventos quentes para `phx-target={@myself}`,
introduzir callbacks (`on_send`, `on_command`, ...) e retirar `close_dialog`
generico. Esses passos dependem da extracao dos componentes stateful (plano 01
+ planos por componente).
