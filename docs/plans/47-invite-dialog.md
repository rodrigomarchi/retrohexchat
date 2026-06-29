# Invite Dialog Migration

## Objetivo

Migrar lista de convites pendentes para componente stateful ou notification queue dedicada.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo (orquestrador)
- **Dependências:** Atravessa ~5 arquivos.
- **Componente de referência:** Fila com timer + prioridade de Escape — NÃO é dialog simples.
- **Abordagem:** `pending_invites` dirige a prioridade do Escape + timers de expiração por convite (timer_ref cancelado no Escape).
- **Gotchas:** Estado de orquestração genuíno — deixar para depois dos mecânicos.
- **Validação:** `make ci` 9/9 + E2E invite.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:913`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/invite_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/invite_events.ex`
- PubSub invite: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/presence.ex`
- State atual: `pending_invites`.

## Tecnica

Use LiveComponent stateful com queue local. Parent/PubSub envia `{:invite_received, invite}` ao componente. Accept/ignore sobem como comandos.

## Tasks

- [ ] Criar `InviteQueueComponent`.
- [ ] Mover `pending_invites` para o componente.
- [ ] Definir id unico por invite/channel/inviter.
- [ ] Accept envia join ao parent.
- [ ] Ignore remove localmente.
- [ ] Expirar convites se regra existir.

## Validacao

- [ ] Convite recebido mostra dialog.
- [ ] Multiplos convites entram em fila.
- [ ] Accept entra no canal correto.
- [ ] Ignore remove somente o convite correto.
- [ ] Queue nao re-renderiza chat inteiro.

## Prompt de execucao

Convites sao notificacoes. Modele como queue, nao como lista global solta.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
