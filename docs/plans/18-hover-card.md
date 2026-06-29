# Hover Card Migration

## Objetivo

Migrar hover card para componente stateful ou hook-driven, evitando que hover de nick altere o socket inteiro do chat.

## Classificação para execução (agentes)

- **Tier:** 🟡 Com ressalva
- **Dependências:** Independente (pequeno), mas lookup async.
- **Componente de referência:** LiveComponent; resultado async = passthrough.
- **Abordagem:** Estado `hover_card`; lookup pesado via async/PubSub → passthrough do resultado; posicionamento via hook client-side; parent recebe no máx 'lookup nick'.
- **Gotchas:** Não mover a busca async — passar o resultado por passthrough.
- **Validação:** `make ci` 9/9 + E2E hover.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:376`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/hover_card.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex`
- State atual: `hover_card`.

## Tecnica

Use LiveComponent stateful com async para lookup pesado de usuario, ou hook client-side para posicionamento. O parent deve receber no maximo a intencao "lookup nick".

## Tasks

- [x] Criar `HoverCardComponent` (`Components.HoverCard`).
- [x] Mover `hover_card` para o componente. **Extração TOTAL** — o parent não guarda mais `hover_card` (os 2 leitores eram PubSub handlers que agora dirigem via `send_update`).
- [ ] Usar `start_async/3` para whois/metadata se custoso. (N/A — o lookup é SÍNCRONO e barato, não async; fica no adapter `hover_events.ex` que tem `session`, resultado sobe por `{:set, card}` passthrough conforme o gotcha.)
- [x] Manter posicionamento x/y no componente ou hook. (x/y vêm no `:set` e são renderizados como posição absoluta pelo function component; sem hook de posicionamento.)
- [ ] Cachear resultado por nick por curto periodo se hover repetir. (Não feito — otimização opcional; comportamento atual recomputa por hover. Sem regressão.)
- [x] Integrar dismiss local. (`nick_hover_dismiss` bubble→adapter→`{:dismiss}`; rename→`{:dismiss_if_nick}`; away→`{:update_away}`.)

## Validacao

- [x] Hover em nick mostra dados corretos. (E2E chat-hover-card O14: registered/away/idle/client/shared channels.)
- [x] Sair/dismiss oculta sem patch global. (Dismiss agora só re-renderiza a ilha HoverCard; `card.visible=false`.)
- [x] Hover rapido em muitos nicks nao enfileira tasks sem controle. (Lookup é síncrono — sem fila de tasks; cada hover faz um `send_update {:set}`.)
- [x] Nao ha flicker ao receber mensagem nova. (Hover virou ilha isolada por change-tracking; mensagens novas re-renderizam só o MessageViewport, não o HoverCard.)

## Prompt de execucao

Hover e evento quente. Ele deve ser local e barato; qualquer IO deve ser async e cancelavel/ignoravel por token.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: `in_progress`. Extração TOTAL: `Components.HoverCard` vira dono do mapa `card`. Os únicos leitores de `hover_card` no parent eram 2 PubSub handlers em `membership.ex` (rename→dismiss; away→merge) + o template → ambos passam a dirigir o componente via `send_update` (ações condicionais que o componente decide com o próprio `card.nick`). O lookup pesado de presença/registro fica no adapter `hover_events.ex` (tem `session`) e o RESULTADO sobe por `{:set, card}` (passthrough, conforme o gotcha). `channel_tooltip`/`dismiss_hover_card` continuam globais no `ScrollHook` (`handleEvent`), então funcionam de qualquer emissor.
- 2026-06-29: `complete`. `Components.HoverCard` (LiveComponent) dono de `card`; protocolo de ações `{:set, card}` / `:dismiss` / `{:dismiss_if_nick, nick}` / `{:update_away, nick, away, message}`. `hover_events.ex` virou adapter: `nick_hover` computa o mapa via `build_hover_card/4` (puro, ex-`populate_hover_card`) e faz `send_update {:set}`; dismiss/dblclick fazem `send_update :dismiss` (+ `PM.open_pm_conversation` no dblclick). Em `membership.ex` os 2 reads viraram `send_update` (a lógica de merge-away e o match-de-nick mudaram VERBATIM para o componente; o componente também empurra `dismiss_hover_card`, recebido globalmente pelo `ScrollHook`). Parent perdeu o assign `hover_card` inteiro + o `import UI.HoverCard` + o init em `assign_defaults`. **Validação:** `make ci` **9/9**; `hover_card_test.exs` (5); E2E chat-hover-card O14 verde. Sem baseline-check (lógica movida verbatim; as coordenações away/rename são as condições idênticas do código original).
