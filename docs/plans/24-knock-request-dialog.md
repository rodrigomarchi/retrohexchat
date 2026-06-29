# Knock Request Dialog Migration

## Objetivo

Migrar dialog de knock para componente stateful com draft de mensagem e erro local.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:505`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/knock_request_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/invite_events.ex`
- State atual: `show_knock_request_dialog`, `knock_request_channel`, `knock_request_message`, `knock_request_error`, `knock_timestamps`.

## Tecnica

Use LiveComponent stateful para form. Rate limit/timestamps devem ficar no parent ou contexto de dominio, nao no dialog, se afetam regra global.

## Tasks

- [ ] Criar `KnockRequestDialogComponent`.
- [ ] Mover channel/message/error para o componente.
- [ ] Manter `knock_timestamps` fora do UI se for regra de negocio.
- [ ] Emitir `{:knock, channel, message}` ao parent.
- [ ] Resetar form ao fechar.

## Validacao

- [ ] Abrir a partir de channel list preenche canal.
- [ ] Alterar mensagem atualiza localmente.
- [ ] Erro de rate limit aparece no dialog.
- [ ] Sucesso fecha e limpa state.

## Prompt de execucao

Separe draft de UI de politica de knock. O componente nao deve conhecer rate-limit alem de exibir erro.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **COMPLETE** (batch com 23 + 29). `Components.KnockRequestDialog` (LiveComponent). Escape-managed → parent mantem `show_knock_request_dialog`; componente recebe como `visible` e e dono do draft `channel`/`message`/`error` via `send_update` (`{:open, channel}`, `{:change, message}`, `{:error, message, msg}`, `:close`). O form ja submete `channel` (hidden) + `message`, entao `knock_request_channel/message/error` sairam TODOS do parent. Submit (validacao de 200 chars + `Core.knock_channel`) fica no parent (adapter) em `channel_list_events.ex`; `close_knock_request_dialog` no events module E no `keyboard_events.ex` fazem `send_update`. 3 asserts em `channel_membership_feature_test.exs` precisaram de flush `render(view)` pos-evento (send_update async). Validacao: `make ci` **9/9**; `knock_request_dialog_test` 4/0; E2E `chat-channel-knock` I15/I16 + Feature 06 verdes.
