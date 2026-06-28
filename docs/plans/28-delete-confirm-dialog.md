# Delete Confirm Dialog Migration

## Objetivo

Migrar confirmacao de delete de mensagem para componente local ao MessageViewport.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:546`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/delete_confirm_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- State atual: `delete_confirm`.

## Tecnica

Como delete nasce de uma mensagem, o estado `message_id` deve ficar no `MessageViewportComponent` ou em um dialog filho dele. Parent recebe apenas `{:delete_message, id}`.

## Tasks

- [ ] Mover `delete_confirm` para MessageViewport.
- [ ] Abrir por evento do context menu/message row.
- [ ] Confirmar envia comando ao parent/contexto.
- [ ] Atualizar stream com mensagem deletada apos resultado.
- [ ] Fechar limpa target.

## Validacao

- [ ] Delete em canal e PM funciona.
- [ ] Cancelar nao altera stream.
- [ ] Confirmar atualiza a linha deletada sem resetar lista.
- [ ] Sem assign `delete_confirm` no parent.

## Prompt de execucao

Delete confirm pertence ao viewport porque o target e uma mensagem renderizada ali.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
