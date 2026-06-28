# Timers Dialog Migration

## Objetivo

Migrar Timers dialog para componente stateful de configuracao, mantendo execucao dos timers fora do dialog.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:755`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/timers_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_events.ex`
- Runtime handlers: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex`
- State atual: `show_timers_dialog`, `user_timers`, `timers_dialog_selected`, `timers_dialog_editing`, `timers_dialog_draft_name`, `timers_dialog_draft_repeat`, `timers_dialog_draft_seconds`, `timers_dialog_draft_command`, `timers_dialog_error`.

## Tecnica

Use LiveComponent stateful para CRUD de timers. A execucao (`Process.send_after`, refs, firing) deve ficar em runtime manager/contexto ou parent, nao no dialog.

## Tasks

- [ ] Criar `TimersDialogComponent`.
- [ ] Mover selected/editing/drafts/error para o componente.
- [ ] Manter `user_timers` como runtime state externo ou criar `TimerManager`.
- [ ] Emitir add/edit/stop/save ao parent/manager.
- [ ] Atualizar lista no componente apos resposta.
- [ ] Separar validacao de duracao em helper puro.

## Validacao

- [ ] Add/edit/stop timer funciona.
- [ ] Timer repeat continua disparando.
- [ ] Timer one-shot some apos executar.
- [ ] Dialog fechado nao cancela timers ativos.
- [ ] Erros de validacao ficam locais.

## Prompt de execucao

Dialog configura timers; runtime executa timers. Nao misture os dois estados.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
