# Hover Card Migration

## Objetivo

Migrar hover card para componente stateful ou hook-driven, evitando que hover de nick altere o socket inteiro do chat.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:376`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/hover_card.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex`
- State atual: `hover_card`.

## Tecnica

Use LiveComponent stateful com async para lookup pesado de usuario, ou hook client-side para posicionamento. O parent deve receber no maximo a intencao "lookup nick".

## Tasks

- [ ] Criar `HoverCardComponent`.
- [ ] Mover `hover_card` para o componente.
- [ ] Usar `start_async/3` para whois/metadata se custoso.
- [ ] Manter posicionamento x/y no componente ou hook.
- [ ] Cachear resultado por nick por curto periodo se hover repetir.
- [ ] Integrar dismiss local.

## Validacao

- [ ] Hover em nick mostra dados corretos.
- [ ] Sair/dismiss oculta sem patch global.
- [ ] Hover rapido em muitos nicks nao enfileira tasks sem controle.
- [ ] Nao ha flicker ao receber mensagem nova.

## Prompt de execucao

Hover e evento quente. Ele deve ser local e barato; qualquer IO deve ser async e cancelavel/ignoravel por token.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
