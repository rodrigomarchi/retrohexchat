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
- 2026-06-28 — **COMPLETE** (batch com 42 + 48). `Components.SoundSettingsDialog` (LiveComponent). Escape-managed → parent mantem `show_sound_settings_dialog` (`visible`); componente dono do `draft` (struct `SoundSettings`). Flash/preview/apply/OK component-local (`@myself`); **preview** faz `push_event("play_sound")` direto do componente. A mudanca do dropdown de som PRECISA ser string (o `select_item` do design system faz `JS.push(on_change, value:)`, que rejeita `%JS{}`) → sobe pro parent que faz `send_update {:change, params}`; o componente aplica no proprio draft. **Apply/OK** commitam o draft-struct na session do parent via `send(self(), {:commit_sound_settings, draft, mode})` + um hook NOVO `settings_dialogs_info` (`SettingsDialogsEvents.handle_info/2`) que persiste e, no OK, fecha (`show` false + `send_update :close`). `muted` (status bar) e `toggle_mute` ficam no parent, intactos. Adicionados `data-testid` em OK/Apply/Cancel pro feature test clicar elementos (eventos component-local nao podem ser disparados por nome na view). Validacao: `make ci` **9/9**; `sound_settings_dialog_test` 3/0 + `sound_settings_test` 9/0; E2E `chat-sound-settings` U3/U4 verdes.
