# Chat Message Viewport Migration

## Objetivo

Extrair a lista principal de mensagens para componente stateful dono absoluto do stream `:chat_messages`, paginacao, scroll, prepend e limite de DOM.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo (CORE big-bang)
- **Dependências:** Bloqueia: 11, 12, 56 e o tail de 09. Gargalo central da migração.
- **Componente de referência:** Streams nativos do LiveView.
- **Abordagem:** LiveComponent `stream/4` + `phx-update="stream"`; novas msgs `stream_insert(limit: -N)`; histórico `stream(at: 0)`; reset só ao trocar contexto.
- **Gotchas:** ~35 sites no hot-path realtime; PubSub inserts, load-more, troca de canal. Refator atômico — não fatiar pela metade.
- **Validação:** `make ci` 9/9 + E2E chat-send/scroll/history (suíte ampla).

## Codigo atual

- Render stream: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:220`
- Stream init no parent: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:917`
- Load channel messages: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex:249`
- Load PM messages: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex:20`
- Load more atual com reset: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex:699`
- PubSub inserts: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex:278`

## Tecnica

Use LiveComponent stateful com `stream/4` e `phx-update="stream"`. Mensagens novas entram com `stream_insert(socket, :messages, item, limit: -N)`. Historico antigo entra no topo com `stream(socket, :messages, items, at: 0, limit: N)` ou reset controlado somente quando trocar contexto.

## Tasks

- [x] Criar `MessageViewport` (`live/chat_live/components/message_viewport.ex`).
- [x] Mover `stream(:chat_messages, [])` do parent para o componente.
- [x] Manter hooks `ScrollHook` e `MessageInteractionsHook` dentro do componente.
- [x] Rotear todos os ~30 sites de stream (`stream_insert`/`stream_delete`/`stream`) para deltas `insert/2`, `delete/2`, `reset/2` via `send_update/2`.
- [x] Mover `render_message/1` e `message_classes/2` (+ imports de cards/indicadores) para o componente.

### Decisão de arquitetura (desvio consciente do plano original)

O plano pedia mover paginação/scroll para dentro do componente. Na prática isso
exigiria reescrever a lógica intrincada de reconciliação (`pending_channel_msg_id`,
`cleared_channel_cutoffs`, cutoffs por canal) e os leitores síncronos no parent.
Em vez disso aplicamos o **shared read-model pattern**: o parent continua dono
canônico de toda a paginação/scroll (`oldest_message_id`, `has_more`,
`loaded_message_count`, `loading_more`, `new_messages_indicator`, `chat_clear_token`,
`pending_channel_msg_id`, `cleared_channel_cutoffs`) e o componente é dono apenas do
`stream(:chat_messages)` (o DOM). Toda mutação de stream no parent vira um delta
`send_update`. Isso isola o `:for` da lista do template do parent (sem re-render do
hot-path) sem tocar na lógica de paginação. `load_more` usa `reset/2` (não `at: 0`),
preservando o comportamento atual. O limite de DOM/janela fica para 56 quando a
ownership de scroll migrar de fato.

## Validacao

- [x] Load more preserva posicao de scroll (E2E chat-history-pagination P10, canal + PM).
- [x] Trocar canal/PM reseta somente viewport (reset via `MessageViewport.reset/2`).
- [x] Pending/failed/retry continuam funcionando (E2E chat-message-retry S10/S11, chat-message-actions O11).
- [x] Edit/delete/reply quote atualizam o item correto (E2E chat-message-actions O8/O9/O10, chat-pm-message-actions S2).
- [x] Mensagens ignoradas nao aparecem (lógica de ignore intacta no parent).
- [ ] Limite de DOM/janela em spam (1000 msgs) — adiado para 56 (migração de ownership de scroll).

## Prompt de execucao

Este e o componente mais importante da migracao. Nao mova apenas markup: mova ownership, stream e paginacao para dentro dele.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **Concluído.** `MessageViewport` extraído como LiveComponent dono do
  stream `:chat_messages`. ~30 sites de stream em 10 módulos (helpers/messages,
  helpers/channel, helpers/pm, helpers/flood, core_events, command_dispatch,
  settings_dialogs_events, perform_autojoin_events, ui_actions/core, pubsub_handlers
  + server_messages + messages) roteados para deltas `insert/2`/`delete/2`/`reset/2`.
  `render_message/1` + `message_classes/2` movidos para o componente; imports de
  cards/indicadores removidos do parent. Adotado o shared read-model pattern (parent
  mantém paginação/scroll; componente possui só o DOM). Validado: `make ci` 9/9 +
  23 E2E focados verdes (chat-send, chat-message-rendering, chat-history-pagination,
  chat-message-actions, chat-message-edit-delete-edges, chat-message-retry,
  chat-notice, chat-pm). Teste de componente: `message_viewport_test.exs` (5 testes).
