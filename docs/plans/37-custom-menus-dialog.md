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
- 2026-06-28 — **COMPLETE** (batch com 36 + 38; padrao "inline-edit-list"). `Components.CustomMenusDialog` (LiveComponent), isomorfico ao alias mais a dimensao `tab`. Escape-managed → parent mantem `show_custom_menus_dialog` (`visible`); `custom_menus` (struct) passado por passthrough e o componente computa `CustomMenus.entries_for(custom_menus, tab)` — assim o `tab` saiu inteiramente do parent. Componente dono de tab/selected/editing/draft_label/draft_command/error. select/add/edit/cancel/tab component-local; save/delete sobem carregando `selected` + `tab` via `JS.push(value:)`. Parent reflete via `send_update` (`{:saved, label}` / `{:error, msg}` / `:deleted` / `:reset`). `custom_menu_execute` (execucao runtime do menu, nao UI do dialog) ficou intacto no parent. Removidos 6 assigns do parent. Validacao: `make ci` **9/9**; `custom_menus_dialog_test` 3/0; E2E `chat-custom-menus-dialog` verde.
