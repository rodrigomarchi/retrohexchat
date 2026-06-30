# Notify List Dialog Migration

> **STATUS: COMPLETE (2026-06-30) — standalone dialog isolated as a full-ownership island, −2 keys.**
> `RetroHexChatWeb.ChatLive.Components.NotifyListDialog` owns its OWN `show`, selection, note draft and
> both sub-form flags; the `notify_list/1` UI is `target`-threaded so the `fixed inset-0` sub-forms survive
> the presence re-renders that flip buddies online/offline (§0a-anti). The shared mutation logic lives in a
> pure `RetroHexChatWeb.ChatLive.NotifyOps` helper (add/remove/update_note/toggles, returns
> `{:ok, session, status}`); the island bubbles `{:notify_dialog_session, session}` (parent assigns +
> persists), `{:notify_dialog_status, msg}` (status bar) and `{:notify_dialog_cancel_timer, nick}` (parent
> owns the debounce timers). **The "entanglement" with the Address Book was a non-problem:** the two are
> separate use cases that never open together — they share `session.notify_list` (read-model) but each owns
> its UI state locally, so selection no longer leaks. `notify_events.ex` keeps serving the Address Book's
> Notify tab until plan 31 (then retired). Removed `show_notify_list` + `selected_note` (the latter a latent
> bug: the standalone edit form read `@selected_note` while events wrote `@selected_notify_note`).
> `make ci` 9/9; component test (5) + `chat-notify` E2E 6/6. See PROGRESS.md log (2026-06-30).

## Objetivo

Migrar Notify List para componente stateful dono de selecao, add/edit subdialogs e toggles.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Compartilha estado notify com 31 (address-book tem show_notify_*). Coordenar com 31.
- **Componente de referência:** Inline-edit-list, MAS com sub-forms modal.
- **Abordagem:** ⚠️ ANTI-PADRÃO modal-in-modal (show_notify_add/edit_dialog) — risco de clobber de input não-controlado (ver 41). Use input CONTROLADO no sub-form OU `phx-update="ignore"`.
- **Gotchas:** Estado compartilhado com 31 — não duplicar; decidir dono único.
- **Validação:** `make ci` 9/9 + E2E notify.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:566`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/notify_list.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/notify_events.ex`
- State atual: `show_notify_list`, `notify_selected`, `selected_note`, `show_notify_add_dialog`, `show_notify_edit_dialog`.

## Tecnica

Use LiveComponent stateful. Lista pode ser normal se pequena; se notify list puder crescer, use stream para rows. Add/edit subdialogs devem ser estado interno, nao assigns do parent.

## Tasks

- [x] Criar `Components.NotifyListDialog` (LiveComponent stateful).
- [x] Mover selecao, note draft e add/edit visibility (próprios do componente).
- [x] Derivar entries de `session.notify_list` (passthrough) no `render/1`.
- [x] Rodar as mutações via `NotifyOps`; bubble de session/status/cancel-timer ao parent.
- [x] Atualizar localmente (optimistic) + parent persiste.
- [x] Selecao isolada — cada ilha é dona da sua (sem vazamento p/ AddressBook).

## Validacao

- [x] Add/edit/remove notify funciona (`chat-notify` E2E).
- [x] Auto whois e auto add PM persistem (`chat-notify-settings` E2E).
- [x] Selecao nao vaza para AddressBook (estado local da ilha).
- [x] Fechar/reabrir reseta sub-dialog (`@closed` no open/close/toggle).

## Prompt de execucao

Notify List e um dialog proprio; nao reutilize assigns globais compartilhados com AddressBook.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-30: **COMPLETE — a "entanglement" era falso problema.** Os dois dialogs (standalone Notify +
  Address Book Notify tab) NUNCA abrem juntos: são casos de uso separados que só leem o mesmo
  `session.notify_list`. Isolação = cada ilha dona da SUA seleção/draft/sub-dialog; o dado e a lógica de
  mutação são compartilhados (read-model na session + helper puro `NotifyOps`). `NotifyListDialog` é a ilha
  do standalone (full ownership via `NotifyOps`, bubbles session/status/cancel-timer). `notify_events.ex`
  segue servindo a Notify tab do Address Book até o plano 31 (depois é removido). −2 chaves
  (`show_notify_list` + `selected_note`). Bug latente consertado de quebra: o edit form do standalone lia
  `@selected_note` mas os eventos escreviam `@selected_notify_note` (nota sempre vazia). `make ci` 9/9;
  `notify_list_dialog_test` (5) + `chat-notify`/`chat-notify-settings` E2E 6/6.
