# Perform Dialog Migration

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

- [ ] Criar `PerformDialogComponent`.
- [ ] Mover tab, selecoes e subdialogs para o componente.
- [ ] Receber entries de perform/autojoin como snapshots.
- [ ] Encapsular add/edit drafts.
- [ ] Emitir comandos e atualizar local state apos sucesso.
- [ ] Remover eventos globais do dialog.

## Validacao

- [ ] Add/edit/remove/move perform funciona.
- [ ] Enable/disable perform persiste.
- [ ] Add/edit/remove autojoin funciona.
- [ ] Subdialogs limpam draft ao fechar.

## Prompt de execucao

Perform dialog e outro mini-app. Estado de selecao e subforms nao pertence ao `ChatLive`.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
