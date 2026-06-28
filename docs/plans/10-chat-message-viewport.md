# Chat Message Viewport Migration

## Objetivo

Extrair a lista principal de mensagens para componente stateful dono absoluto do stream `:chat_messages`, paginacao, scroll, prepend e limite de DOM.

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

- [ ] Criar `MessageViewportComponent`.
- [ ] Mover `stream(:chat_messages, [])` do parent para o componente.
- [ ] Mover `oldest_message_id`, `has_more`, `loaded_message_count`, `loading_more`, `new_messages_indicator`, `chat_clear_token`.
- [ ] Definir `@message_window_limit`, por exemplo 300 ou configuravel.
- [ ] Troca de canal/PM chama reset do componente com contexto e pagina inicial.
- [ ] Nova mensagem ativa chama append com limite negativo.
- [ ] Mensagem editada/deletada usa `stream_insert` por id.
- [ ] Load more busca pagina anterior e insere no topo sem recarregar todas as mensagens.
- [ ] Manter hooks `ScrollHook` e `MessageInteractionsHook` dentro do componente.
- [ ] Remover `messages: %{}` se nao tiver uso real.

## Validacao

- [ ] DOM de mensagens nao cresce indefinidamente em spam.
- [ ] Load more preserva posicao de scroll.
- [ ] Trocar canal/PM reseta somente viewport.
- [ ] Pending/failed/retry continuam funcionando.
- [ ] Edit/delete/reply quote atualizam o item correto.
- [ ] Mensagens ignoradas nao aparecem.
- [ ] Teste de 1000 mensagens confirma limite de DOM.

## Prompt de execucao

Este e o componente mais importante da migracao. Nao mova apenas markup: mova ownership, stream e paginacao para dentro dele.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
