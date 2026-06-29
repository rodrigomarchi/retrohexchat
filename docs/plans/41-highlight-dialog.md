# Highlight Dialog Migration

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

- [ ] Criar `HighlightDialogComponent`.
- [ ] Mover selected/color/subdialog state.
- [ ] Encapsular add/edit draft.
- [ ] Emitir add/edit/remove/color ao parent.
- [ ] Rebuild highlight matcher apos save.
- [ ] Atualizar MessageViewport se highlight settings exigirem re-render da janela atual.

## Validacao

- [ ] Add/edit/remove highlight funciona.
- [ ] Color picker atualiza cor correta.
- [ ] Mensagens novas usam regras atualizadas.
- [ ] Opcional: refresh atualiza highlights ja visiveis.

## Prompt de execucao

Highlight dialog configura regras; aplicacao das regras pertence ao pipeline de mensagens.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
