# Chat Context Menu Migration

## Objetivo

Migrar context menu da area de mensagens para componente stateful local ao viewport de mensagens.

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
