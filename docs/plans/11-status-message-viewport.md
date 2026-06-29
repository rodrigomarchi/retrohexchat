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

- [x] Criar `StatusViewport` (`live/chat_live/components/status_viewport.ex`).
- [x] Mover `stream(:status_messages, [])` para o componente.
- [x] Definir limite de status (500 — `stream/4` + `stream_insert` com `limit: -500`).
- [x] `status_unread` FICA no parent (lido pela aba IRC + navegação — shared read-model).
- [x] Atualizar `Messages.push_status_message/3` (funil único) para `StatusViewport.insert/2`.
- [x] Dual-write chat+status continua explícito nos helpers `*_event` (já separado no plano 10).

### Decisão de arquitetura

Único funil de inserção (`push_status_message/3`) → trivialmente reroteado para
`StatusViewport.insert/2`. Shared read-model igual ao plano 10: o parent mantém
`status_unread`/`show_status_tab` (lidos pela aba IRC, navegação, command_dispatch);
o componente é dono só do `stream(:status_messages)` (DOM), agora **bounded a 500
linhas** — ganho independente que o plano pedia. O parent perdeu o último uso de
`<.chat_message_list>`/`<.chat_message>`, então o import `ChatMessage` saiu dele.

## Validacao

- [x] Status tab mostra MOTD, system events, erros e notices roteadas (E2E chat-server-messages H11, chat-notice J2–J4, chat-welcome A5; feature MOTD-in-Status).
- [x] Status unread liga/desliga corretamente (assign no parent intacto; aba IRC lê `status_unread`).
- [x] Status nao cresce sem limite no DOM (`limit: -500` no stream).
- [x] Mensagem de chat normal nao re-renderiza status quando tab status esta oculta (`:for` saiu do parent → change-tracking isola).

## Prompt de execucao

Trate status como log proprio, nao como caso especial do viewport de chat.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **Concluído.** `StatusViewport` extraído (dono do `stream(:status_messages)`,
  bounded a 500). Funil único `push_status_message/3` → `StatusViewport.insert/2`;
  `status_unread`/`show_status_tab` permanecem no parent (shared read-model). heex troca
  o bloco inline pelo `<.live_component>`; `stream(:status_messages, [])` e o import
  `ChatMessage` removidos do parent. **Gotcha de teste (novo, no playbook §2):** com o
  status agora atrás de `send_update`, 10 testes `:liveview`/`:liveview_feature` que
  afirmavam um `push_event` (som/title-flash) ou texto de status logo após um `send`/
  `render_submit` passaram a precisar de `render(view)` para flush — o `push_event` É
  gerado (provado por IO.inspect), só não era entregue sem render porque o diff do parent
  pós-handler agora é vazio (a lista saiu do parent). Corrigido centralizando o flush nos
  helpers `send_*` (sound/visual tests) e adicionando flush nos 2 membership + 1 MOTD.
  Validado: `make ci` 9/9; suíte web completa 794/0; `status_viewport_test.exs` (4);
  E2E focado de status 11/11 (chat-server-messages H11, chat-notice J2–J4, chat-welcome
  A5, chat-wallops J17/J18, chat-statusbar O19, chat-nickserv). A falha E2E
  chat-nickserv-whois-realtime W4 é PRÉ-EXISTENTE (default `whois_output_mode: :card` vs
  teste que espera texto — mesma classe de J10/J11; ver 57-testing-strategy).
