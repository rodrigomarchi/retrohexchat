# Account Dialog Migration

## Objetivo

Migrar Account dialog para LiveComponent stateful dono de tabs, auth draft, bio draft, warnings, away message e modos de usuario.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:518`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/account_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/account_events.ex`
- State atual: `show_account_dialog`, `account_dialog_tab`, `account_auth_mode`, `account_registered`, `account_error`, `account_auth_valid`, `account_nick_error`, `account_bio_draft`, `account_bio_warning`, `account_ghost_error`, `account_last_away_message`.

## Tecnica

Use LiveComponent stateful montado sob demanda. Dados derivados de `Session` entram como snapshot inicial. Operacoes NickServ/profile/away sobem ao parent/contexto como comandos; resultado volta por `send_update/3`.

## Tasks

- [ ] Criar `AccountDialogComponent`.
- [ ] Mover tabs e drafts para o componente.
- [ ] Nao passar `Session` inteira; passar snapshot `%{nickname, identified, registered, away, bio, modes}`.
- [ ] Processar `account_auth_change` localmente.
- [ ] Enviar submits ao parent: register, identify, ghost, bio save, away toggle, modes.
- [ ] Atualizar componente com resultado/erro via `send_update/3`.
- [ ] Remover `account_events.ex` da pipeline global apos migrar eventos.

## Validacao

- [ ] Register/login/identify continuam.
- [ ] Erros de senha/ghost aparecem no dialog.
- [ ] Profile bio salva e warning conta caracteres.
- [ ] Away/presence sincroniza status bar.
- [ ] User modes persistem e refletem no dialog.
- [ ] Fechar/reabrir nao carrega drafts antigos indevidamente.

## Prompt de execucao

Account e dialog medio e sensivel. Migre ownership de UI primeiro, depois comandos de dominio.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
