# IRC Tabs Migration

## Objetivo

Migrar a tab bar de status, canais e PMs para componente dedicado, reduzindo dependencia direta de `@session.channels`, `@session.pm_conversations` e `@unread_counts` no template principal.

## Classificação para execução (agentes)

- **Tier:** 🟡 Com ressalva
- **Dependências:** Independente (pequeno).
- **Componente de referência:** Function-component wrapper; stateful só se drag/reorder/overflow/pin.
- **Abordagem:** switch_tab/close_tab continuam adapters no parent (navigation_events).
- **Gotchas:** navigation_events faz re-dispatch — manter contrato.
- **Validação:** `make ci` 9/9 + E2E tabs.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:113`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/irc_tabs.ex`
- Events roteados pelo parent: `switch_tab` e `close_tab` em `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:286`
- Navigation events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/navigation_events.ex`

## Tecnica

Use function component wrapper se tabs forem pequenas. Use LiveComponent stateful se houver drag/reorder, overflow, pinning ou menus locais. Para muitos canais/PMs, use streams ou keys estaveis.

## Tasks

- [ ] Criar `TabsComponent` ou `ChatTabs`.
- [ ] Passar uma lista normalizada de tabs `%{type, label, active?, unread?, color}`.
- [ ] Mover `Map.get(@unread_counts, ...)` para preparacao de dados fora do HEEx principal.
- [ ] Emitir `{:switch_tab, type, label}` e `{:close_tab, type, label}`.
- [ ] Preservar status tab fixa.
- [ ] Considerar overflow/scroll de tabs se muitas PMs/canais.

## Validacao

- [ ] Canais e PMs alternam corretamente.
- [ ] Fechar tab preserva proximo target ativo.
- [ ] Unread some ao focar tab.
- [ ] Tab bar nao re-renderiza por mensagem no canal ativo sem mudanca de unread.

## Prompt de execucao

Normalize dados antes de renderizar. Evite passar a struct `Session` inteira para a tab bar.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
