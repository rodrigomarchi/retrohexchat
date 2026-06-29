# Disconnect Confirm Dialog Migration

## Objetivo

Migrar confirmacao de disconnect para dialog simples sem estado global alem da intencao de desconectar.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:539`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/disconnect_confirm_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- State atual: `show_disconnect_confirm`.

## Tecnica

Use function component com JS modal se possivel. Se confirmar precisa do server, o botao confirm emite evento global `confirm_disconnect`; abrir/fechar pode ser local.

## Tasks

- [x] Remover `show_disconnect_confirm` do parent — movido para o `DisconnectConfirmDialog` LiveComponent. (Modal 100% JS NAO foi escolhido: o trigger vem do dispatch generico de menu/toolbar que ja emite o evento server `disconnect`; um modal JS exigiria special-case nesse dispatch. O LiveComponent + adapter e mais consistente com o resto da migracao.)
- [x] Manter evento server apenas para confirmacao — `confirm_disconnect` (cleanup + redirect) continua no parent; open/close sao adapters `send_update`.
- [x] Cancel — `cancel_disconnect` faz um `send_update :close` leve (o componente e dono do `show`, entao o cancel passa pelo server para manter o estado sincronizado; nao altera a sessao). Escape do proprio `<.dialog>` dispara `on_cancel`.
- [x] Padronizar com outros confirm dialogs — segue o padrao adapter do playbook (igual ao mute dialog, plano 22).

## Validacao

- [x] Disconnect via menu abre confirmacao (E2E `logout`).
- [x] Confirmar executa cleanup e redirect (E2E: lands on `/connect`).
- [x] Cancelar nao altera sessao (cancel so fecha).
- [x] Fechar via Escape funciona (o `<.dialog>` tem `phx-key=escape` -> `on_cancel`).

## Prompt de execucao

Confirm dialog simples nao deve virar um bloco de estado permanente no parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **COMPLETE.** Terceiro LiveComponent stateful (segundo dialog), recipe do playbook quase mecanico.
  - Arquivos: `live/chat_live/components/disconnect_confirm_dialog.ex` (novo), `disconnect_confirm_dialog_test.exs` (novo). Modificados: `menu_toolbar_events.ex` (`disconnect`/`cancel_disconnect` → `send_update`; import + alias), `chat_live.ex` (removido default + import do function component), `chat_live.html.heex` (→ `<.live_component>`).
  - Decisao: NAO JS-only — o `disconnect` vem do dispatch generico de menu/toolbar (evento server); LiveComponent + adapter e mais simples e consistente.
  - Validacao: `make ci` **9/9**; 3 testes de componente 0 falhas; E2E `logout` passou (1 retry — falha inicial foi a corrida conhecida de primeira-abertura da menubar em `openFileMenu`, ANTES do item disconnect; nao e regressao desta mudanca). Contratos preservados (`disconnect-confirm-dialog*` testids) → Page Object intacto.
