# Perform Dialog Migration

> **STATUS: COMPLETE (2026-06-30) — full ownership (plan-40 pattern).**
> `RetroHexChatWeb.ChatLive.Components.PerformDialog` owns the ENTIRE dialog: `show`/`active_tab`, both
> selections, all 4 sub-form `show_*` flags, every event (`@myself`, `target` threaded through the design-system
> `perform_dialog/1`), and the `PerformList`/`AutoJoinList` logic. `perform_autojoin_events.ex` gutted 289→~55
> lines (open/close/toggle routing). The perform/autojoin lists stay on the parent's `session` (the central
> read-model — connect flow + composer read it, §1d); the dialog runs the mutation and bubbles the new session
> via `{:perform_dialog_session, session, kind}` → parent assigns + fire-and-forget persist; validation errors
> bubble via `{:perform_system_error, msg}`. Tabs are client-side CSS (the dead `on_tab` attr was removed).
> `assign_defaults` −8 (→94). `make ci` 9/9; component test (6) + `perform_feature_test` 27/27 element-based.
> See PROGRESS.md log (2026-06-30).

## Objetivo

Migrar Perform/Autojoin para componente stateful com tabs, selecao e subdialogs internos.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Duas features (Perform + AutoJoin) num dialog + 4 subdialogs modal (Escape-managed).
- **Componente de referência:** Inline-edit-list + threading de seleção.
- **Abordagem:** Componente owns tab+seleções; seleção vai pro parent via `phx-value`/hidden input; subforms hardcoded sobem pro parent (adapter).
- **Gotchas:** ⚠️ `render_submit` NÃO despacha `JS.push(value:)` (finding lote 4) — use hidden input + `phx-value`.
- **Validação:** `make ci` 9/9 + E2E perform/autojoin.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:667`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/perform_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/perform_autojoin_events.ex`
- State atual: `show_perform_dialog`, `perform_dialog_tab`, `perform_selected`, `autojoin_selected`, `show_perform_add_dialog`, `show_perform_edit_dialog`, `show_autojoin_add_dialog`, `show_autojoin_edit_dialog`.

## Tecnica

Use LiveComponent stateful. Perform/autojoin entries podem ser lista normal; use stream se crescerem. O componente emite comandos add/edit/remove/move/toggle ao parent.

## Tasks

- [x] Criar `Components.PerformDialog` (LiveComponent stateful).
- [x] Mover tab, selecoes e subdialogs para o componente.
- [x] Receber entries de perform/autojoin via `session` (passthrough; deriva no `render/1`).
- [x] Encapsular add/edit (sub-forms `@myself`, `target` threaded — modal-in-modal resolvido na raiz).
- [x] Rodar a lógica `PerformList`/`AutoJoinList` no componente; bubble da nova session ao parent.
- [x] Remover eventos globais do dialog (`perform_autojoin_events.ex` 289→~55 linhas; dismissals do keyboard removidos).

## Validacao

- [x] Add/edit/remove/move perform funciona (`perform_feature_test` element-based).
- [x] Enable/disable perform persiste (`maybe_persist_perform_list` via bubble).
- [x] Add/edit/remove autojoin funciona.
- [x] Subdialogs limpam estado ao fechar (`@closed` reset no close/open).

## Prompt de execucao

Perform dialog e outro mini-app. Estado de selecao e subforms nao pertence ao `ChatLive`.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-30: **COMPLETE — full ownership, plan-40 clone.** `Components.PerformDialog` é dono do dialog
  inteiro; `perform_autojoin_events.ex` virou só roteamento de open/close/toggle (`send_update`). Os
  sub-forms `fixed inset-0` foram resolvidos na raiz com `target` (`phx-target={@target}`). A novidade
  deste caso vs admin: a lista perform/autojoin mora no `session`, que é lido SÍNCRONO por OUTRO
  subsistema (connect/composer) — então fica no parent (§1d genuíno), mas a MUTAÇÃO roda no componente e
  a nova session sobe via `{:perform_dialog_session, session, kind}`. Código morto removido em vez de
  preservado: o attr `on_tab` do design-system (tabs são CSS client-side) + o handler inalcançável.
  `make ci` 9/9; `perform_dialog_test` (6) + `perform_feature_test` 27/27 element-based.
