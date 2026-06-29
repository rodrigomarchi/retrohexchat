# Account Dialog Migration

## Objetivo

Migrar Account dialog para LiveComponent stateful dono de tabs, auth draft, bio draft, warnings, away message e modos de usuario.

## Classificação para execução (agentes)

- **Tier:** ✅ Mecânico (superfície grande)
- **Dependências:** Independente.
- **Componente de referência:** `Components.CustomMenusDialog` (37, tabs) + `Components.SoundSettingsDialog` (34, commit de draft).
- **Abordagem:** SEM modal-in-modal (0 overlays). Escape-managed → parent mantém `show_account_dialog` (passthrough `visible`); tabs/drafts (bio etc.) no componente; auth/registro = forms CONTROLADOS.
- **Gotchas:** Superfície grande (9 inputs, 11 assigns, 396 LOC events); senha = NÃO logar params; bio_draft controlado (sem clobber).
- **Validação:** `make ci` 9/9 + E2E account.

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
- 2026-06-29: **COMPLETE** (20º LiveComponent stateful — a maior superfície mecânica). `Components.AccountDialog`.
  - **Ownership:** componente é dono das 8 assigns de UI/draft: `tab`, `auth_mode`, `auth_valid`, `error`, `nick_error`, `bio_draft`, `bio_warning`, `ghost_error`. Parent mantém `show_account_dialog` (gatilhos EXTERNOS: status-bar widget + File-menu Account group; não-Escape — o `<.dialog>` trata Escape via `on_close`) → `visible`; `account_registered` (snapshot do NickServ mantido por `sync_identity`, que também muta a session); `account_last_away_message` (preferência de sessão lida pelo away-toggle do status bar com o dialog fechado). Campos derivados da session (nickname/account_state/identified/away/away_message/wallops) = passthrough.
  - **Eventos = ADAPTERS string** (TODOS — o feature test dispara cada form por nome `render_submit(view, "account_register_submit", ...)`; e todos fazem trabalho de orquestrador: NickServ via CommandDispatch + sync_identity). Os adapters refletem resultados de UI (erros, mode, validez, bio draft) de volta via `send_update` (protocolo de ações `{:open,…}`/`{:auth,…}`/`{:auth_error,…}`/`{:auth_reset,…}`/`{:ghost_error,…}`/`{:nick_error,…}`/`{:bio,…}`/`:reset`). Senha nunca logada.
  - Removidas 8 assigns do `assign_defaults` do parent (mantidas só `show_account_dialog`/`account_registered`/`account_last_away_message`) + import do function component.
  - **Testes:** `account_dialog_test` (componente, novo, 3 tests `@moduletag :unit`); `account_entry_points_feature_test` **11/11** sem mudança (dispara por nome → adapters; cada assert usa `render(view)` fresco = flush do send_update §2). `make ci` **9/9**. Sem E2E dedicado de account (coberto pelo feature test).
