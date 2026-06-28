# Mute Duration Dialog Migration

## Objetivo

Migrar o dialog de duracao de mute para componente stateful pequeno, removendo `mute_duration_dialog` do parent.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:485`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/mute_duration_dialog.ex`
- Events relacionados: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`
- State atual: `mute_duration_dialog: %{show, target_nick}`.

## Tecnica

Use LiveComponent stateful montado sempre ou sob demanda. Estado local: target, duration draft, validation error. Evento local com `phx-target={@myself}`; parent recebe somente `{:mute_user, nick, duration}`.

## Tasks

- [ ] Criar `MuteDurationDialogComponent`.
- [ ] Mover show/target/draft/error para o componente.
- [ ] Abrir via `send_update/3` a partir de context menu.
- [ ] Validar duracao localmente usando helper puro.
- [ ] Emitir comando final ao parent.

## Validacao

- [ ] Abrir por context menu preserva target nick.
- [ ] Confirmar aplica mute com duracao correta.
- [ ] Cancelar limpa draft.
- [ ] Dialog fechado nao deixa assign no parent.

## Prompt de execucao

Trate como dialog transiente: parent nao deve guardar formulario nem coordenadas.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
