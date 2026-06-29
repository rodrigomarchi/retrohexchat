# Chat LiveView Migration Plans

Este diretorio contem prompts de execucao para migrar o chat para uma arquitetura LiveView de alta performance.

O objetivo e disruptivo: `RetroHexChatWeb.App.ChatLive` deve deixar de ser dono de todo o estado visual. Ele deve virar um orquestrador fino, enquanto componentes stateful ficam donos do proprio estado, eventos e streams.

## Tecnicas base

- Use `Phoenix.LiveComponent` stateful quando o componente tem estado ou eventos proprios.
- Use function components apenas para markup puro e deterministico.
- Use `stream/4`, `stream_insert/4`, `stream_delete/3` e `phx-update="stream"` para colecoes grandes.
- Sempre defina limite para streams que podem crescer indefinidamente no DOM, especialmente mensagens e status.
- Use `send_update/3` ou mensagens para componentes para atualizar ilhas stateful sem reatribuir o socket inteiro do parent.
- Use `phx-target={@myself}` para eventos locais de componentes stateful.
- Use `update_many/1` quando muitos componentes iguais precisarem carregar dados.
- Use `assign_async/3` ou `start_async/3` para carregamentos pesados, sem capturar `socket` dentro da task.
- Use `Phoenix.LiveView.JS` ou hooks com `phx-update="ignore"` para interacao puramente local: hover, foco, posicionamento, animacao e scroll.
- Reduza computed assigns no template. Calcule dados derivados no dono do estado ou em assigns pequenos e estaveis.

Referencias:

- `Phoenix.LiveView` streams, async e lifecycle: https://hexdocs.pm/phoenix_live_view/1.1.22/Phoenix.LiveView.html
- `Phoenix.LiveComponent`, `send_update/3` e `update_many/1`: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html
- Streams em Phoenix: https://fly.io/phoenix-files/phoenix-dev-blog-streams/
- Latencia e renderizacao em LiveView: https://dashbit.co/blog/latency-rendering-liveview
- Pitfalls de assigns: https://blog.appsignal.com/2022/06/28/liveview-assigns-three-common-pitfalls-and-their-solutions.html

## Ordem recomendada

1. Migrar o core: orquestrador, roteamento de eventos e hooks globais.
2. Migrar viewport de mensagens, status stream e composer.
3. Migrar nicklist, conversas e tabs.
4. Migrar popups/context menus.
5. Migrar dialogs simples.
6. Migrar dialogs complexos: account, address book, channel central, bot management e admin console.
7. Remover assigns mortos do parent e criar testes de regressao/performance.

## Inventario

- `00-loop-execution-prompt.md`
- `PROGRESS.md`
- `STATEFUL-COMPONENT-PLAYBOOK.md` (receita reutilizavel de extracao — ler antes de cada island)
- `01-chat-live-orchestrator.md`
- `02-chat-event-routing.md`
- `03-hidden-hooks.md`
- `04-shell-header-status.md`
- `05-conversations-sidebar.md`
- `06-irc-tabs.md`
- `07-topic-bar.md`
- `08-connection-status.md`
- `09-search-bar.md`
- `10-chat-message-viewport.md`
- `11-status-message-viewport.md`
- `12-message-row-renderer.md`
- `13-nicklist.md`
- `14-composer-input.md`
- `15-formatting-reply-typing.md`
- `16-autocomplete-syntax.md`
- `17-emoji-picker.md`
- `18-hover-card.md`
- `19-chat-context-menu.md`
- `20-conversations-context-menu.md`
- `21-nicklist-context-menu.md`
- `22-mute-duration-dialog.md` ate `52-admin-console-dialog.md`
- `53-unused-dialogs-audit.md`
- `54-chat-unused-components-audit.md`
- `55-toast-notifications.md`
- `56-loading-and-scroll-indicators.md`
- `57-testing-strategy.md`

Cada arquivo deve ser tratado como prompt independente para uma sessao de implementacao.
