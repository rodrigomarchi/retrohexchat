# Notify List Dialog Migration

## Objetivo

Migrar Notify List para componente stateful dono de selecao, add/edit subdialogs e toggles.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:566`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/notify_list.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/notify_events.ex`
- State atual: `show_notify_list`, `notify_selected`, `selected_note`, `show_notify_add_dialog`, `show_notify_edit_dialog`.

## Tecnica

Use LiveComponent stateful. Lista pode ser normal se pequena; se notify list puder crescer, use stream para rows. Add/edit subdialogs devem ser estado interno, nao assigns do parent.

## Tasks

- [ ] Criar `NotifyListDialogComponent`.
- [ ] Mover selecao, note draft e add/edit visibility.
- [ ] Receber entries como snapshot inicial ou updates.
- [ ] Emitir add/edit/remove/toggle ao parent/contexto.
- [ ] Atualizar localmente apos sucesso.
- [ ] Remover compartilhamento acidental com AddressBook notify state.

## Validacao

- [ ] Add/edit/remove notify funciona.
- [ ] Auto whois e auto add PM persistem.
- [ ] Selecao nao vaza para AddressBook.
- [ ] Fechar/reabrir nao preserva subdialog aberto.

## Prompt de execucao

Notify List e um dialog proprio; nao reutilize assigns globais compartilhados com AddressBook.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
