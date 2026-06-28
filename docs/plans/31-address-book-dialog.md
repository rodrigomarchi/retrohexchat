# Address Book Dialog Migration

## Objetivo

Migrar Address Book para LiveComponent stateful com tabs internas, selecoes e subdialogs proprios.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:585`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/address_book.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/address_book_events.ex`
- State atual: `show_address_book`, `address_book_tab`, `contacts_selected`, `nick_colors_selected`, `control_selected`, `selected_contact_note`, `selected_notify_note`, `show_contact_*`, `show_notify_*`, `show_nick_color_*`, `show_control_add_dialog`, `nick_palette_editing_index`.

## Tecnica

Use LiveComponent stateful montado sob demanda. Cada tab deve ser subcomponente ou funcao pura, mas a selecao/drafts ficam no AddressBookComponent. Para listas grandes, use streams por tab.

## Tasks

- [ ] Criar `AddressBookDialogComponent`.
- [ ] Mover tab ativa, selecoes e subdialog state.
- [ ] Separar notify state do `NotifyListDialogComponent`.
- [ ] Receber snapshots de contacts/notify/nick_colors/control.
- [ ] Emitir comandos add/edit/remove por tipo.
- [ ] Atualizar local state apos sucesso ou via update do parent.
- [ ] Avaliar streams em contacts/notify/control.
- [ ] Remover `address_book_events.ex` da pipeline global apos migrar.

## Validacao

- [ ] Contacts add/edit/remove passam.
- [ ] Notify tab nao interfere no Notify List dialog.
- [ ] Nick colors alteram mensagens/nicklist/sidebar.
- [ ] Control/ignore add/remove afeta filtros.
- [ ] Subdialogs travam dialog pai corretamente.
- [ ] Fechar limpa drafts e selecoes transientes.

## Prompt de execucao

Address Book e um mini-app. Nao tente manter todos os drafts no parent; mova o workflow inteiro.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
