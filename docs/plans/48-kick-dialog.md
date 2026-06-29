# Kick Dialog Migration

## Objetivo

Migrar fila de kicks para componente de notificacao stateful.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:921`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/kick_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/kick_events.ex`
- PubSub: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/channel_state.ex`
- State atual: `kick_queue`.

## Tecnica

Use LiveComponent stateful com queue local. PubSub envia kick events ao componente; dismiss remove primeiro item.

## Tasks

- [ ] Criar `KickQueueComponent`.
- [ ] Mover `kick_queue` para o componente.
- [ ] Definir payload normalizado de kick.
- [ ] Dismiss local remove item.
- [ ] Coordenar com troca/part de canal no parent.

## Validacao

- [ ] Kick recebido mostra dialog com operador/alvo/razao.
- [ ] Dismiss avanca fila.
- [ ] Ser kickado do canal atual atualiza sessao e mensagens.
- [ ] Queue nao fica presa apos reconnect.

## Prompt de execucao

Kick dialog e notificacao operacional. Nao precisa ser estado permanente do parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **COMPLETE** (batch com 34 + 42). `Components.KickQueueDialog` (LiveComponent; fila de notificacao via PubSub). NAO e Escape-managed → o componente e dono da fila inteira (`queue`) e deriva a propria visibilidade (mostra enquanto `queue != []`). O handler PubSub `channel_state.ex` (quando VOCE e kickado) troca o assign `kick_queue: ... ++ [event]` por um `send_update {:enqueue, kick_event}` de UMA linha (o resto — `part_channel_after_kick`/sound/system_event — fica no parent). OK/dismiss e component-local. Deletado `kick_events.ex` (so tinha o dismiss) + suas DUAS registracoes de hook (a lista `event_hooks` do `attach_all_hooks` E o module-attr `@event_hook_fns`). Removido `kick_queue` default do parent. Validacao: `make ci` **9/9**; `kick_queue_dialog_test` 3/0; E2E `chat-channel-moderation` I12 (kick) verde. **Invite (47) — fila irma — DEFERIDA:** `pending_invites` dirige a decisao de PRIORIDADE do Escape (`if pending_invites != []`) + timers de expiracao por-convite cujo `timer_ref` o handler de Escape do parent cancela; estado de orquestrador em 5 arquivos.
