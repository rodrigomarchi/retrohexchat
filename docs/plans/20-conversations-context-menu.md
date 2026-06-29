# Conversations Context Menu Migration

## Objetivo

Migrar context menu de conversas para dentro do `ConversationsComponent`.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Depende de: 05 (vive dentro de Conversations).
- **Componente de referência:** Estado local no componente de conversas.
- **Abordagem:** Ações sobem como comandos: mute/unmute, close, clear unread, join, part, query.
- **Gotchas:** —
- **Validação:** `make ci` 9/9 + E2E conversations-context-menu.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:435`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/conversations_context_menu.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/conversations_context_menu_events.ex`
- State atual: `conversations_context_menu`, `muted_channels`, `unread_counts`.

## Tecnica

Use state local no componente de conversas. Acoes de negocio sobem como comandos: mute/unmute, close, clear unread, join, part, query.

## Tasks

- [ ] Mover state do menu para `ConversationsComponent`.
- [ ] Calcular `is_muted`, `has_unread` e custom items dentro do componente.
- [ ] Trocar `on_action="conversations_context_action"` por `phx-target={@myself}`.
- [ ] Emitir acoes ao parent somente quando alteram sessao/servidor.
- [ ] Integrar fechamento em clique externo/mobile.

## Validacao

- [ ] Menu em canal e PM mostra opcoes corretas.
- [ ] Mute/unmute e clear unread atualizam sidebar.
- [ ] Fechar tab pelo menu preserva estado ativo.
- [ ] Menu nao depende de assigns do parent para coordenadas.

## Prompt de execucao

Este menu nao deve existir fora da sidebar. Migre junto ou imediatamente depois de `ConversationsComponent`.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
