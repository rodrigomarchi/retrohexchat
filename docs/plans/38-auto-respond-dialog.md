# Auto Respond Dialog Migration

## Objetivo

Migrar Auto Respond para componente stateful com lista de regras e draft local.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:735`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/auto_respond_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/autorespond_events.ex`
- State atual: `show_autorespond_dialog`, `autorespond_dialog_selected`, `autorespond_dialog_editing`, `autorespond_dialog_draft_trigger`, `autorespond_dialog_draft_channel`, `autorespond_dialog_draft_command`, `autorespond_dialog_error`, `autorespond_cooldowns`.

## Tecnica

Use LiveComponent stateful para configuracao. `autorespond_cooldowns` e runtime behavior devem ficar fora do dialog, pois sao estado operacional do chat.

## Tasks

- [ ] Criar `AutoRespondDialogComponent`.
- [ ] Mover selected/editing/drafts/error.
- [ ] Manter cooldowns no runtime handler ou processo/contexto separado.
- [ ] Emitir add/edit/delete/toggle ao parent.
- [ ] Atualizar rules apos sucesso.

## Validacao

- [ ] Add/edit/delete/toggle rules funciona.
- [ ] Cooldowns continuam evitando spam.
- [ ] Draft cancelado nao altera rules.
- [ ] Auto response runtime segue funcionando com novas rules.

## Prompt de execucao

Separe configuracao de runtime. O dialog edita rules; o handler executa rules.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **COMPLETE** (batch com 36 + 37; padrao "inline-edit-list"). `Components.AutoRespondDialog` (LiveComponent), isomorfico. Escape-managed → parent mantem `show_autorespond_dialog` (`visible`); `autorespond_rules` (struct) por passthrough (componente computa `AutoRespondRules.entries/1`). Selecao e inteiro `position` (sobrevive ao round-trip JSON via `JS.push(value:)`). Componente dono de selected/editing/draft_trigger/draft_channel/draft_command/error. select/add/edit/cancel component-local; save/delete sobem carregando `selected`. O `toggle` (enable/disable por linha) ficou como adapter puro no parent — so muta a session, sem estado de UI, entao sem `send_update`. Parent reflete via `send_update` (`{:saved}` / `{:error, msg}` / `:deleted` / `:reset`). Removidos 6 assigns do parent. Validacao: `make ci` **9/9**; `auto_respond_dialog_test` 3/0; E2E `chat-autorespond-dialog` + `chat-automation-composition` verdes.
