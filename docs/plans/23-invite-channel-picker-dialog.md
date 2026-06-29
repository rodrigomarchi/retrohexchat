# Invite Channel Picker Dialog Migration

## Objetivo

Migrar seletor de canal para convite para LiveComponent dono de selecao e erro.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:494`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/invite_channel_picker_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/invite_events.ex`
- State atual: `show_invite_channel_picker`, `invite_channel_picker_target`, `invite_channel_picker_selected`, `invite_channel_picker_error`.

## Tecnica

Use LiveComponent stateful. O parent passa canais disponiveis quando abre; o componente guarda selected/error e emite `{:invite_to_channel, target, channel}`.

## Tasks

- [ ] Criar `InviteChannelPickerComponent`.
- [ ] Abrir por update com target e canais.
- [ ] Mover selected/error para o componente.
- [ ] Validar canal selecionado antes de emitir.
- [ ] Fechar e limpar estado apos sucesso/cancel.

## Validacao

- [ ] Lista canais atuais do usuario.
- [ ] Submit sem selecao mostra erro local.
- [ ] Convite e enviado para target correto.
- [ ] Troca de canal no chat enquanto dialog aberto nao quebra lista.

## Prompt de execucao

Mantenha parent como executor do convite; o dialog so decide target/canal.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **COMPLETE** (batch com 24 + 29). `Components.InviteChannelPickerDialog` (LiveComponent). Escape-managed → parent mantem `show_invite_channel_picker` (lido pelo mapa de Escape em `keyboard_events.ex`); o componente recebe como `visible` (passthrough) e tambem `channels={@session.channels}` (passthrough). Componente dono APENAS do draft: `target_nick`/`selected_channel`/`error` via `send_update` (`{:open, target, selected}`, `{:error, target, selected, msg}`, `:close`). O form ja submete `target` (hidden) + `channel` (select), entao TODOS os assigns de draft sairam do parent (lidos de params). Submit (`Invite.send_invite`) fica no parent (adapter). `open/close_invite_channel_picker` no `context_menu_events.ex` E no `keyboard_events.ex` agora fazem `send_update`. Validacao: `make ci` **9/9**; `invite_channel_picker_dialog_test` 4/0; E2E `chat-ui-features-channel` Feature 06 verde. Page Object intocado.
