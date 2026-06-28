# Sound Settings Dialog Migration

## Objetivo

Migrar Sound Settings para componente stateful com draft, preview local e apply/ok.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:655`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/sound_settings_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/settings_dialogs_events.ex`
- State atual: `show_sound_settings_dialog`, `sound_settings_draft`, `muted`.

## Tecnica

Use LiveComponent stateful. Preview deve usar `push_event("play_sound", ...)` direto do componente ou por parent callback. Draft local evita alterar session antes de Apply/OK.

## Tasks

- [ ] Criar `SoundSettingsDialogComponent`.
- [ ] Mover draft para o componente.
- [ ] Implementar preview sem alterar session.
- [ ] Apply atualiza session e mantem dialog aberto.
- [ ] OK aplica e fecha; Cancel descarta.
- [ ] Coordenar mute global com status bar.

## Validacao

- [ ] Alterar som e flash persiste corretamente.
- [ ] Preview toca sem salvar.
- [ ] Cancel nao salva.
- [ ] Muted global continua funcionando.

## Prompt de execucao

Som e preferencia de usuario: use draft local e commit explicito.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
