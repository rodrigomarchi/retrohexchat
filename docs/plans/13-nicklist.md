# Nicklist Migration

## Objetivo

Migrar nicklist para componente stateful com stream de usuarios, updates incrementais e context menu local.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Bloqueia: 21 (nicklist-context-menu vive dentro). Streams + PubSub.
- **Componente de referência:** LiveComponent com `stream(:users, reset: true)`.
- **Abordagem:** `stream_insert/delete` em join/part/nick/mode/away; reset só ao trocar canal.
- **Gotchas:** Presence PubSub churn — não reatribuir a lista inteira por evento.
- **Validação:** `make ci` 9/9 + E2E nicklist (O12 é pre-existente).

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:288`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/nicklist.ex`
- Context menu: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/nicklist_context_menu.ex`
- Load users: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex:178`
- Membership PubSub: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/membership.ex`
- State atual: `channel_users`, `show_nicklist`, `context_menu`, `show_context_color_picker`.

## Tecnica

Use LiveComponent stateful com `stream(:users, users, reset: true)` ao trocar canal e `stream_insert/delete` em join/part/nick change/mode change/away. Evite reatribuir a lista inteira em cada evento de presenca.

## Tasks

- [ ] Criar `NicklistComponent`.
- [ ] Mover `show_nicklist`, `channel_users`, context menu e color picker para o componente.
- [ ] Definir id estavel por nick normalizado.
- [ ] Converter `load_channel_users/2` para retornar users ou enviar reset ao componente.
- [ ] Atualizar PubSub membership para enviar deltas ao componente quando possivel.
- [ ] Mover `NicklistHook` para dentro do componente.
- [ ] Integrar `NicklistContextMenuComponent` localmente.
- [ ] Expor ao parent somente acoes semanticas: query, ignore, op/deop, voice/devoice, kick, ban, color.

## Validacao

- [ ] Join/part atualiza um item, nao a lista inteira.
- [ ] Nick change preserva ordem/role/status.
- [ ] Mode changes atualizam role/voiced/muted.
- [ ] Context menu ainda conhece permissao do viewer.
- [ ] Status bar user_count continua correto.
- [ ] Teste com muitos usuarios confirma patch pequeno.

## Prompt de execucao

Nicklist e segunda prioridade depois de mensagens. Ela e uma lista viva; trate como stream, nao como assign de lista.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
