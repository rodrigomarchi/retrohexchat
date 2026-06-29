# Toast Notifications Migration

## Objetivo

Isolar toast/tips/feedback notifications como infraestrutura client-side, sem misturar estado de dicas no socket principal do chat.

## Classificação para execução (agentes)

- **Tier:** ✅ Mecânico (leve)
- **Dependências:** Independente; majoritariamente client-side.
- **Componente de referência:** Toast já client-side.
- **Abordagem:** LiveView emite eventos semânticos (tip_trigger/feedback_toast); hook gerencia fila/dismiss/persistência. Só `tips_suppressed` é server.
- **Gotchas:** Não trazer a fila pro server — só preferências.
- **Validação:** `make ci` 9/9 + E2E toast/tips.

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
- 2026-06-29: **COMPLETE (leve).** Auditoria confirmou que o toast JÁ é infraestrutura client-side correta: container ÚNICO (`RetroHexChatWeb.Components.Toast.toast_container`, `.toast-container`) renderizado 1× no `chat_live.html.heex`; `ContextualTipsHook` é dono da fila/dismiss/persistência (localStorage, `tips.js`). **Achado:** `tips_suppressed` era **estado morto write-only** no socket — escrito por `TipEvents` no `tips_state_sync`, NUNCA lido em lugar nenhum (sem `@tips_suppressed` em template/componente/módulo). Removido o assign default; `TipEvents.handle_event("tips_state_sync", …)` agora apenas dá `{:halt, socket}` (swallow limpo — o hook ainda emite o evento, então mantemos roteado para evitar o debug-log de evento não-roteado), com moduledoc explicando que supressão é client-side-only e reintroduzir assign server só se houver consumidor server-side. Sem tests/E2E referenciando `tips_suppressed`/`tips_state_sync` (grep). `make ci` 9/9.
