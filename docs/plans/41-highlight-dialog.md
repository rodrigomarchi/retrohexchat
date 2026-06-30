# Highlight Dialog Migration

> **STATUS: COMPLETE (2026-06-30) — UNBLOCKED. Full ownership, −5 keys (`assign_defaults` → ~89).**
> `RetroHexChatWeb.ChatLive.Components.HighlightDialog` owns the whole dialog: `show`, selection,
> color-picker draft, both sub-form flags, every event (`@myself`), and the `HighlightWords` logic.
> `highlight_events.ex` gutted to open/close/toggle routing. **Two fixes unblocked it:** (1) the modal-in-modal
> color-pick clobber — `target` threaded through `highlight_dialog/1` AND the `color_picker` primitive, plus
> `phx-update="ignore"` on the word input so the in-form color-pick re-render (same component) can't reset it;
> (2) a ROOT-CAUSE bug — the `{_ref, _result}` Task-result swallower in the `pubsub_handlers`/`presence`
> `:handle_info` hooks greedily halted EVERY 2-tuple, eating island→parent bubbles like
> `{:highlight_dialog_session, session}` before they reached the LiveView (so the parent session never updated
> and inbound messages weren't highlighted). Fixed with an `is_reference/1` guard — which also repairs the
> silently-broken `{:cc_system_error}`/`{:admin_system_error}`/`{:perform_system_error}` bubbles. `make ci`
> 9/9; component test (5) + `chat-highlights` E2E green. See PROGRESS.md log (2026-06-30).

## Objetivo

Migrar Highlight dialog para componente stateful com selecao, add/edit subdialogs e color picker local.

## Classificação para execução (agentes)

- **Tier:** ⛔ BLOQUEADO
- **Dependências:** Independente, mas com bloqueio técnico real.
- **Componente de referência:** Nenhuma — wrapper NÃO resolve.
- **Abordagem:** BLOQUEIO: sub-forms Add/Edit (modal-in-modal) submetem ao PARENT mas vivem no DOM do componente → mismatch de cid quebra a preservação de valor de input do LiveView; a palavra digitada some no re-render do color-pick. Provado 3x (E2E) mesmo com passthrough puro.
- **Gotchas:** FIX: sub-forms OWNED pelo componente (`@myself` + child→parent p/ escrita na session) OU input controlado/`phx-update="ignore"`. Mantido INLINE (function component) até o refator.
- **Validação:** `make ci` 9/9 + E2E chat-highlights TEM que passar.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:840`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/highlight_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/highlight_events.ex`
- State atual: `show_highlight_dialog`, `highlight_selected`, `highlight_selected_color`, `show_highlight_add_dialog`, `show_highlight_edit_dialog`.

## Tecnica

Use LiveComponent stateful. Highlight words sao settings; o componente edita draft local e parent persiste em session/contexto.

## Tasks

- [x] Criar `Components.HighlightDialog` (LiveComponent stateful).
- [x] Mover selected/color/subdialog state.
- [x] Encapsular add/edit (sub-forms `@myself` + `phx-update="ignore"` no input p/ sobreviver ao re-render do color-pick).
- [x] Rodar a lógica `HighlightWords` no componente; bubble da nova session ao parent (3-tuple-safe via guard).
- [x] Sem matcher separado: o pipeline de mensagens lê `session.highlight_words` no render → basta a session atualizar.
- [x] Remover eventos globais do dialog (`highlight_events.ex` → routing; dismissals do keyboard removidos).

## Validacao

- [x] Add/edit/remove highlight funciona (`chat-highlights` E2E).
- [x] Color picker atualiza cor correta (irc-bg-N).
- [x] Mensagens novas usam regras atualizadas (E2E: inbound highlighted irc-bg-9).
- [x] Persistência funciona (parent `maybe_persist_highlight_words` agora roda — antes era engolido).

## Prompt de execucao

Highlight dialog configura regras; aplicacao das regras pertence ao pipeline de mensagens.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-30: **COMPLETE — DESBLOQUEADO.** O dialog que estava ⛔ por causa do modal-in-modal color-pick
  clobber agora é uma ilha de posse total. Dois consertos: (1) `target` threaded pelo `highlight_dialog/1`
  E pelo primitivo `color_picker` + `phx-update="ignore"` no input da palavra (o clobber aqui vem do
  RE-RENDER do mesmo componente no color-pick, não de outro componente — `phx-target` sozinho não bastava;
  precisou do `ignore`). (2) **Bug de raiz:** o swallower `{_ref, _result}` dos hooks `:handle_info`
  (`pubsub_handlers`/`presence`) engolia TODO 2-tuple, comendo o bubble `{:highlight_dialog_session, session}`
  antes de chegar no LiveView — a session do parent nunca atualizava e as mensagens não eram destacadas.
  Corrigido com guard `is_reference/1` (só resultados de `Task` são `{ref, result}` com ref reference). Isso
  também conserta os bubbles de erro 2-tuple do cc/admin/perform que estavam quebrados em silêncio.
  `make ci` 9/9; `highlight_dialog_test` (5) + `chat-highlights.spec.ts` E2E verde.
