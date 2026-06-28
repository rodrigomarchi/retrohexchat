# Alias Dialog Migration

## Objetivo

Migrar Alias dialog para componente stateful com edicao inline/draft local.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:696`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/alias_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/alias_events.ex`
- State atual: `show_alias_dialog`, `alias_dialog_selected`, `alias_dialog_editing`, `alias_dialog_draft_name`, `alias_dialog_draft_expansion`, `alias_dialog_warning`, `alias_dialog_error`.

## Tecnica

Use LiveComponent stateful. Draft e warnings ficam locais; parent atualiza session aliases no save/delete.

## Tasks

- [ ] Criar `AliasDialogComponent`.
- [ ] Mover selecao/editing/drafts/errors.
- [ ] Validar nome/expansion localmente quando possivel.
- [ ] Emitir save/delete ao parent.
- [ ] Atualizar entries apos sucesso.

## Validacao

- [ ] Add/edit/delete alias funciona.
- [ ] Warning/error aparecem localmente.
- [ ] Cancel edit restaura estado.
- [ ] Aliases continuam expandindo no command dispatch.

## Prompt de execucao

O dialog deve ser dono do modo de edicao; o parent so persiste a lista final.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
