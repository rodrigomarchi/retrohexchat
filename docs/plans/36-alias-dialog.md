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
- 2026-06-28 — **COMPLETE** (batch com 37 + 38; padrao "inline-edit-list"). `Components.AliasDialog` (LiveComponent). Escape-managed → parent mantem `show_alias_dialog`, passado como `visible`; `aliases` (struct `AliasList`) passado por passthrough (o componente computa `AliasList.entries/1` e faz `find_entry` no edit). Componente dono de selected/editing/draft_name/draft_expansion/warning/error. Eventos de UI pura (select/add/edit/cancel) sao **component-local** (`JS.push(..., target: @myself)`); save/delete sobem pro parent carregando `selected` via `JS.push(value:)` — no `phx-submit` o value se MESCLA com os campos do form. Parent faz `AliasList` add/update/remove + persist e reflete via `send_update` (`{:saved, name, warning}` / `{:error, msg}` / `:deleted` / `:reset` no close). `alias_warning`/`alias_error_msg` ficam no parent. `close_alias_dialog` (events module + `keyboard_events.ex`) fazem `send_update :reset`. Removidos do parent 6 assigns de draft. Validacao: `make ci` **9/9**; `alias_dialog_test` 3/0; E2E `chat-alias-dialog` verde (edges U10 = flake pre-existente de abertura de menu, falha igual no main limpo via stash baseline).
