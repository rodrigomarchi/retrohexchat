# Toast Notifications Migration

## Objetivo

Isolar toast/tips/feedback notifications como infraestrutura client-side, sem misturar estado de dicas no socket principal do chat.

## Codigo atual

- Toast container no template: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:22`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/toast.ex`
- Hook: `apps/retro_hex_chat_web/assets/js/hooks/ui/contextual_tips_hook.js`
- Toast builders: `apps/retro_hex_chat_web/assets/js/lib/notifications/toast.js`
- Feedback toast: `apps/retro_hex_chat_web/assets/js/lib/notifications/feedback_toast.js`
- State atual relacionado: `tips_suppressed`.

## Tecnica

Manter toasts majoritariamente client-side. O LiveView deve emitir eventos semanticos (`tip_trigger`, `feedback_toast`) e o hook deve gerenciar fila, dismiss e persistencia local. Se houver preferencias server-side, sincronizar apenas preferencias, nao a fila.

## Tasks

- [ ] Criar plano de ownership: `ToastHost` global no shell ou no chat root.
- [ ] Confirmar se `tips_suppressed` ainda e necessario no socket.
- [ ] Padronizar eventos JS: `tip_trigger`, `feedback_toast`, `toast_clear`.
- [ ] Evitar que componentes individuais renderizem containers duplicados.
- [ ] Documentar quais componentes podem emitir feedback toast.
- [ ] Se preferencias de tips forem persistidas, mover para settings/contexto.

## Validacao

- [ ] Tips continuam aparecendo uma vez conforme regra.
- [ ] Feedback toast de copy/settings continua funcionando.
- [ ] Mensagens novas nao re-renderizam o container.
- [ ] Nao ha multiplos containers `.toast-container`.
- [ ] Preferencia de suppress persiste conforme comportamento atual.

## Prompt de execucao

Toast e infraestrutura visual global. Nao transforme fila de toasts em assigns LiveView se JS ja resolve melhor.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
