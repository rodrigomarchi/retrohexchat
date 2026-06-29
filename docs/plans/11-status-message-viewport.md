# Status Message Viewport Migration

## Objetivo

Extrair a lista de mensagens de status para componente stateful separado, com stream proprio e limite independente.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Depende de: 10 (mesmo padrão de stream).
- **Componente de referência:** `stream(:status_messages, limit: -N)`.
- **Abordagem:** Parent envia eventos de status sem manter a lista.
- **Gotchas:** Bounded log; igual ao viewport principal.
- **Validação:** `make ci` 9/9 + E2E status.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:266`
- Stream init: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:918`
- Push status: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/messages.ex:74`
- State atual: `show_status_tab`, `status_unread`.

## Tecnica

Use LiveComponent stateful com `stream(:status_messages, [], limit: -N)` para manter log de status bounded. O parent envia eventos status sem manter a lista.

## Tasks

- [ ] Criar `StatusViewportComponent`.
- [ ] Mover `stream(:status_messages, [])` para o componente.
- [ ] Definir limite de status, por exemplo 500.
- [ ] Mover `status_unread` ou transformar em evento para tabs/sidebar.
- [ ] Atualizar `Messages.push_status_message/3` para enviar update ao componente.
- [ ] Separar status de chat: dual-write deve ser explicito e testado.

## Validacao

- [ ] Status tab mostra MOTD, system events, erros e notices roteadas.
- [ ] Status unread liga/desliga corretamente.
- [ ] Status nao cresce sem limite no DOM.
- [ ] Mensagem de chat normal nao re-renderiza status quando tab status esta oculta.

## Prompt de execucao

Trate status como log proprio, nao como caso especial do viewport de chat.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
