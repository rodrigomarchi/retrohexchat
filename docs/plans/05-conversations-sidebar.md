# Conversations Sidebar Migration

## Objetivo

Migrar a sidebar de conversas para componente stateful dono de sections, unread/highlight/flash/mute state e listas de canais/PMs/populares.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Bloqueia: 20 (conv-context-menu vive dentro). Streams.
- **Componente de referência:** LiveComponent com `stream` (canais/PMs/populares).
- **Abordagem:** Derivar unread_channels/unread_pms DENTRO do componente; muitos mapas passthrough (unread/highlight/flash/muted).
- **Gotchas:** Não reatribuir a lista inteira; usar stream_insert/delete.
- **Validação:** `make ci` 9/9 + E2E conversations.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:65`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/conversations.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/conversations_events.ex`
- Context menu events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/conversations_context_menu_events.ex`
- State atual: `show_conversations`, `channel_user_counts`, `popular_channels`, `conversations_sections`, `unread_counts`, `highlight_channels`, `flash_channels`, `muted_channels`.

## Tecnica

Use LiveComponent stateful com streams para canais, PMs e canais populares se a lista crescer. Derive `unread_channels` e `unread_pms` dentro do componente, nao no template do parent.

## Tasks

- [x] Criar `Components.Conversations`.
- [x] `conversations_sections` continua no parent (canônico) e chega como assign; o componente deriva `collapsed_sections`.
- [~] Updates incrementais: NÃO necessário — sem stream. O parent passa os mapas crus como assigns; change-tracking re-renderiza o componente só quando um deles muda.
- [~] Streams: **descartado de propósito** — listas pequenas + estilo por-linha (unread/flash/highlight) muda muito → stream re-pusharia linhas a cada mudança de estilo. Passthrough + derive-inside isola igual, mais simples.
- [x] Eventos `switch_channel`/`switch_pm`/`toggle_section`/`browse_channels`/`join_popular` seguem adapters (string, bubble pro parent) — inalterados.
- [~] Context menu (20) fica no parent por ora (lê `channel_user_counts`/permissões); integração local é o plano 20.
- [x] Remover as 3 comprehensions derivadas do template do parent (movidas pro `render/1` do componente).

## Validacao

- [x] Entrar/sair de canais atualiza só a sidebar (o `:for` saiu do parent → change-tracking isola). (E2E sidebar)
- [x] PM novo sobe na lista sem resetar a tela (parent muta `pm_conversations`/`unread_counts`; só o componente re-renderiza). (E2E pm-unread)
- [x] Unread/highlight/flash/mute corretos (derivados dos mapas crus dentro do componente). (E2E unread/mute)
- [x] `show_conversations` (toggle) continua no parent; sidebar mobile abre/fecha via `toggle_conversations` (adapter).
- [x] Popular channels passthrough (carregado pelo parent, não recalcula a cada mensagem).
- [x] `make ci` 9/9; component test (4); E2E 6/7 (V3 browse-all-search pré-existente no baseline).

## Prompt de execucao

Comece mantendo a UI existente, mas movendo ownership. Depois adicione stream e updates incrementais.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE — 22º stateful; gêmeo do nicklist, variante SEM stream.**
  `Components.Conversations`. Mesma forma de read-model compartilhado do nicklist
  (`unread_counts`/`highlight`/`flash`/`muted` lidos em 30+ sites), MAS sem stream:
  listas pequenas + estilo por-linha que muda muito tornam o stream a ferramenta
  errada (re-push de linha a cada mudança de estilo). Em vez disso, passthrough dos
  mapas crus + as 3 comprehensions (`unread_channels`/`unread_pms`/`collapsed_sections`)
  derivadas DENTRO do componente; change-tracking isola do hot-path do parent (a
  sidebar parou de re-renderizar a cada msg/typing/lag). Eventos seguem adapters;
  `show_conversations` fica no parent → `visible`. Chrome → novo
  `Components.UI.Conversations.conversations_sidebar/1` (Tailwind cru fora do
  LiveComponent, igual nicklist). `make ci` 9/9; component test (4); **E2E 6/7**
  (sidebar/unread/pm-unread/mute verdes); V3 (browse-all preserva search pre-state)
  falha IDÊNTICO no baseline limpo (`git stash`) = pré-existente do ChannelListDialog,
  não regressão. Refinamento da receita no playbook §1d (variante sem stream).
  Desbloqueia o plano 20 (context menu de conversas).
