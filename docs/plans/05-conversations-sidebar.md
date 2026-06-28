# Conversations Sidebar Migration

## Objetivo

Migrar a sidebar de conversas para componente stateful dono de sections, unread/highlight/flash/mute state e listas de canais/PMs/populares.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:65`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/conversations.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/conversations_events.ex`
- Context menu events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/conversations_context_menu_events.ex`
- State atual: `show_conversations`, `channel_user_counts`, `popular_channels`, `conversations_sections`, `unread_counts`, `highlight_channels`, `flash_channels`, `muted_channels`.

## Tecnica

Use LiveComponent stateful com streams para canais, PMs e canais populares se a lista crescer. Derive `unread_channels` e `unread_pms` dentro do componente, nao no template do parent.

## Tasks

- [ ] Criar `ConversationsComponent`.
- [ ] Mover `conversations_sections` para o componente.
- [ ] Receber updates incrementais: `{:channel_joined, channel}`, `{:pm_opened, nick}`, `{:unread, key, count}`, `{:highlight, key}`, `{:mute, key, bool}`.
- [ ] Usar `stream(:channels, ...)`, `stream(:pms, ...)`, `stream(:popular_channels, ...)` se houver listas grandes.
- [ ] Mover eventos `switch_channel`, `switch_pm`, `toggle_section`, `browse_channels`, `join_popular`.
- [ ] Integrar com `ConversationsContextMenuComponent` por evento local ou callback.
- [ ] Remover comprehensions derivadas do parent.

## Validacao

- [ ] Entrar/sair de canais atualiza somente a sidebar e tabs necessarias.
- [ ] PM novo sobe na lista sem resetar toda a tela.
- [ ] Unread/highlight/flash/mute continuam corretos.
- [ ] Sidebar mobile abre/fecha sem depender do parent quando possivel.
- [ ] Popular channels carrega uma vez e nao recalcula a cada mensagem.

## Prompt de execucao

Comece mantendo a UI existente, mas movendo ownership. Depois adicione stream e updates incrementais.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
