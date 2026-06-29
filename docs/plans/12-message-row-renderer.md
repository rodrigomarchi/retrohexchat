# Message Row Renderer Migration

## Objetivo

Extrair `render_message/1` do `ChatLive` para componente dedicado de mensagens, com assigns minimos e sem capturar helpers globais desnecessarios.

## Classificação para execução (agentes)

- **Tier:** 🔴→🟡
- **Dependências:** Depende de: 10 (que decide o stream).
- **Componente de referência:** Function component puro por linha.
- **Abordagem:** Precompute campos caros no item do stream (timestamp, nick color, html seguro, flags). Determinístico, sem efeitos.
- **Gotchas:** Não fazer I/O nem assigns no renderer.
- **Validação:** `make ci` 9/9.

## Codigo atual

- Render private function: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:335`
- Usado no stream: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:252`
- Components usados: `chat_message.ex`, `message_reply_block.ex`, `inline_help_card.ex`, `arcade_session_link.ex`, `p2p_invite_card.ex`
- `MessageIndicators` importado em `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:49`

## Tecnica

Use function component puro para cada linha. O componente de viewport decide stream; o row renderer deve ser deterministico. Precompute campos caros no item de stream quando possivel: timestamp formatado, nick color, html seguro ou flags.

## Tasks

- [x] Criar `MessageRow` em `ChatLive.Components`.
- [x] Mover `render_message/1`, `message_classes/2` e helpers relacionados para modulo proprio.
- [x] Evitar passar `Session`; passar `strip_formatting`, `timezone`, `timestamp_format`, `nick_color_fn`.
- [ ] Considerar preformatar timestamp e content ao inserir no stream para reduzir CPU por render. (Não feito — manteria o campo cru no stream item; otimização separada, sem ganho de correção. Renderer já é determinístico/sem I/O.)
- [x] Validar uso de `raw(ChatHelpers.format_content(...))` e sanitizacao. (Inalterado — movido verbatim; `format_content` sanitiza no `ChatHelpers`.)
- [x] Decidir se `MessageIndicators` deve ser usado ou removido do import. (Usado: `deleted_placeholder`/`edited_tag`/`retry_button` no `MessageRow`; import saiu do `MessageViewport`.)

## Validacao

- [x] Todos os tipos renderizam: normal, action, system, service, error, notice, inline_help, arcade_link, p2p_invite, deleted, edited, failed. (`message_row_test.exs` cobre cada um; E2E chat-message-rendering verde.)
- [x] Reply block e retry button continuam acionando eventos. (Eventos `scroll_to_reply_parent`/`retry_message` inalterados; E2E chat-message-actions O8/O11 verde.)
- [x] Snapshot/component tests cobrem tipos principais. (`message_row_test.exs`, 11 testes.)
- [x] Novo renderer nao depende de assigns do parent. (Function component puro; só recebe `dom_id`/`msg`/`nick_color_fn`/`timestamp_format`/`timezone`/`strip_formatting`/`edit_mode_message_id` — nunca `Session`.)

## Prompt de execucao

Nao transforme linha de mensagem em LiveComponent por default. Para milhares de mensagens, function component + stream e mais barato, salvo se cada linha tiver estado proprio real.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: `in_progress`. Extraindo `render_message/1` + `message_classes/2` do `MessageViewport` para um function component puro `Components.MessageRow` (a linha inteira: wrapper `<div>` com classes/`data-*` + corpo por tipo). MessageViewport passa a iterar o stream chamando `<MessageRow.message_row .../>`.
- 2026-06-29: `complete`. `Components.MessageRow` é function component PURO (`use RetroHexChatWeb, :html` — dá `raw/1` + `~p`, que `RetroHexChatWeb.Component` não dá). `message_row/1` renderiza a LINHA inteira: o `<div id={@dom_id}>` (wrapper que o stream usa como dom_id) + classes (`message_classes/2` agora privado aqui) + `data-*` + o `case` por tipo. `MessageViewport` ficou só dono do stream + container `chat_message_list`; importava 6 módulos de UI (chat_message/reply_block/inline_help/p2p_invite/arcade_link/indicators) → agora só `ChatMessage` (p/ `chat_message_list`); os outros 5 + `alias ChatHelpers` migraram p/ `MessageRow`. `:for` do stream chama `<MessageRow.message_row dom_id={dom_id} msg={msg} .../>` — a raiz `<div id={@dom_id}>` do function component vira o filho direto do `phx-update="stream"` (id no lugar certo). **Validação:** `make ci` **9/9**; `message_row_test.exs` (11 — todos os tipos via `render_component(&MessageRow.message_row/1, assigns)`); E2E focado 8/8 (chat-message-rendering, chat-message-actions O8–O11, chat-notice). Zero mudança de comportamento (renderer movido verbatim) → sem baseline-check.
