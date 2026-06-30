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

- [x] Criar `Components.ChatTabs` (function component em `chat_live/components/`).
- [x] Construir uma lista normalizada `%{type, label, active, unread, closeable, nick_color}` em `build_tabs/1`.
- [x] Mover `Map.get(@unread_counts, ...)` para `build_tabs/1`, fora do HEEx principal.
- [x] `switch_tab`/`close_tab` continuam adapters no parent (attr defaults `on_switch`/`on_close`), preservando o contrato de `phx-value-type`/`phx-value-label`.
- [x] Status tab fixa preservada (primeiro item, `closeable: false`).
- [ ] Overflow/scroll de tabs — deferido (o `irc_tab_bar` já tem `overflow-x-auto`; sem drag/reorder/pin por enquanto, segue function component).

## Validacao

- [ ] Canais e PMs alternam corretamente.
- [ ] Fechar tab preserva proximo target ativo.
- [ ] Unread some ao focar tab.
- [ ] Tab bar nao re-renderiza por mensagem no canal ativo sem mudanca de unread.

## Prompt de execucao

Normalize dados antes de renderizar. Evite passar a struct `Session` inteira para a tab bar.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE (batch 04+06+08).** `Components.ChatTabs.chat_tabs/1` (function component)
  normaliza status + canais + PMs numa lista única em `build_tabs/1` (tira as 3 comprehensions
  inline + os `Map.get(@unread_counts, …)` do template) e renderiza via `irc_tab_bar`/`irc_tab_item`.
  `switch_tab`/`close_tab` seguem adapters no parent (defaults de attr); contratos `role="tab"`/
  `phx-value-*` preservados → Page Object intacto. Sem stream (lista pequena, sem append-heavy) e
  sem estado local (não há drag/reorder/pin). Validação: `make ci` **9/9**; `chat_tabs_test.exs`
  (4, `@moduletag :unit`).
