# Chat Context Menu Migration

> **STATUS: COMPLETE (2026-06-29) — migrated as a cluster with plan 21.**
> `RetroHexChatWeb.ChatLive.Components.UserContextMenus` (one stateful island) owns BOTH the chat
> message menu (`chat_context_menu`) and the nicklist menu (`context_menu`) plus the shared inline
> nick-color picker (`show_context_color_picker`) — three keys out of `assign_defaults`. The chat
> menu's "Set Color" coupling (it reused the nicklist menu's x/y) is now internal to the component
> (`set_color_from_chat` update directive). Open/close are STRING adapters in `ChatLive.ContextMenuEvents`
> driving the component via `put_menu/2` (`send_update`); `ctx_chat_*` actions read targets from
> `phx-value` params and do the privileged work on the parent. `session`/`channel_users`/`nick_color_fn`
> stay parent-owned (passthrough); permissions derive in `render/1`. `make ci` 9/9; shared component
> test `user_context_menus_test.exs` (7).

## Objetivo

Migrar context menu da area de mensagens para componente stateful local ao viewport de mensagens.

## Classificação para execução (agentes)

- **Tier:** 🟡/🔴
- **Dependências:** Independente-ish, mas usa helpers de permissão (ChatContext).
- **Componente de referência:** LiveComponent (cluster de context-menus 19/20/21).
- **Abordagem:** Owns visible/posição/target; ações sobem como comandos semânticos; resolve permissão via `ChatContext` (admin?/op?).
- **Gotchas:** Padrões compartilhados com 20/21.
- **Validação:** `make ci` 9/9 + E2E context-menus.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:407`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/chat_context_menu.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`
- State atual: `chat_context_menu` e helpers de permissao no parent.

## Tecnica

Use LiveComponent stateful. O menu deve guardar `visible`, posicao e target localmente. Acoes devem ser enviadas ao parent como comandos semanticos.

## Tasks

- [ ] Criar `ChatContextMenuComponent`.
- [ ] Mover `chat_context_menu` para o componente.
- [ ] Receber contexto minimo: viewer nick, permissions, active channel, custom menu entries.
- [ ] Calcular target state no componente ou em provider puro.
- [ ] Integrar com `MessageInteractionsHook`.
- [ ] Fechar menu localmente por JS quando possivel.
- [ ] Remover dispatcher `chat_context_action` do parent quando migrado.

## Validacao

- [ ] Menu de nick/url/channel/message mostra opcoes corretas.
- [ ] Acoes ignore/query/reply/edit/delete/retry/moderacao continuam.
- [ ] Clique fora fecha menu.
- [ ] Nova mensagem nao fecha/reabre menu indevidamente.

## Prompt de execucao

Context menu deve viver perto do elemento que o abre: MessageViewport. O parent nao deve manter coordenadas de mouse.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
