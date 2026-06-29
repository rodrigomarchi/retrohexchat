# Paste Confirm Dialog Migration

## Objetivo

Migrar confirmacao de paste para dentro do ComposerComponent.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:903`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/paste_confirm_dialog.ex`
- Timer handler: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex:246`
- State atual: `paste_lines`, `paste_flood_warning`, `paste_send_disabled`.

## Tecnica

Use state local do ComposerComponent. Paste e entrada de texto sao ownership do composer. Envio linha-a-linha pode chamar parent/command dispatcher, mas fila e confirmacao ficam locais.

## Tasks

- [ ] Mover paste state para ComposerComponent.
- [ ] Mover `PasteHook` para composer.
- [ ] Validar flood warning localmente com helper/contexto.
- [ ] Enviar linhas via mensagem controlada, respeitando timers.
- [ ] Cancelar limpa fila.

## Validacao

- [ ] Paste multi-line abre confirmacao.
- [ ] Flood warning aparece quando aplicavel.
- [ ] Send envia linhas na ordem.
- [ ] Cancel nao envia nada.
- [ ] Composer nao perde foco apos paste.

## Prompt de execucao

Paste e parte do input. Nao mantenha fila de texto colado no `ChatLive` parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.

- 2026-06-29: COMPLETE. `Components.PasteConfirmDialog` (15th stateful; content
  dialog, NOT Escape-managed). Componente dono de `lines`/`flood_warning`/`send_disabled`;
  `show = lines != nil`. Parent `paste_lines` (evento de `phx-hook`) vira
  `send_update {:set, lines, count>50, count>100}`; send/cancel component-local (send
  agenda `{:paste_next, lines}` via `Process.send_after` e limpa; cancel limpa +
  `push_event("focus_input")`). `make ci` 9/9; 3 testes de componente; 4 paste feature
  tests (cancel/send por element-click); E2E chat-paste verde.
