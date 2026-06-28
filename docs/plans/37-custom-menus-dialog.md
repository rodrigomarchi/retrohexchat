# Custom Menus Dialog Migration

## Objetivo

Migrar Custom Menus para componente stateful com tabs por contexto e draft local.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:715`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/custom_menus_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/custom_menus_events.ex`
- State atual: `show_custom_menus_dialog`, `custom_menus_dialog_tab`, `custom_menus_dialog_selected`, `custom_menus_dialog_editing`, `custom_menus_dialog_draft_label`, `custom_menus_dialog_draft_command`, `custom_menus_dialog_error`.

## Tecnica

Use LiveComponent stateful. Context menu definitions sao settings; draft local e commit explicito.

## Tasks

- [ ] Criar `CustomMenusDialogComponent`.
- [ ] Mover tab, selected, editing e drafts.
- [ ] Carregar entries por tab dentro do componente.
- [ ] Validar label/command.
- [ ] Emitir save/delete ao parent.
- [ ] Notificar context menu components apos alteracao.

## Validacao

- [ ] Add/edit/delete em cada tab funciona.
- [ ] Custom menu aparece em chat/conversations/nicklist.
- [ ] Cancel edit nao altera session.
- [ ] Erros ficam locais.

## Prompt de execucao

Como Custom Menus afeta outros componentes, padronize evento de broadcast interno apos salvar.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
