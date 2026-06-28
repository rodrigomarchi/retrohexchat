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
