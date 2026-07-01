# Lobby — Game Island

> Pré-requisito de leitura: [`00-OVERVIEW.md`](00-OVERVIEW.md) e
> `../STATEFUL-COMPONENT-PLAYBOOK.md`. Depende de [`01-chat-island.md`](01-chat-island.md)
> (contrato C1 disponível).

## Objetivo

Extrair a feature de jogos para
`RetroHexChatWeb.App.LobbyLive.Components.GameIsland`, dona de `game`,
`game_request`, `game_outgoing`, `games`. É a ilha **mais limpa** (own-PubSub +
own-window self-contida) e por isso **estabelece os contratos C2 (read-model →
taskbar) e C3 (a ilha dirige a própria janela)**.

## Classificação para execução (agentes)

- **Tier:** 🟢 Mecânico — own-assigns + own-PubSub + own-window, baixo cross-read.
- **Dependências:** entra C1 (uma msg de sistema). Estabelece C2/C3 para 03/04.
- **Componente de referência:** ilha que fala com hook (`lobby_game_*` push_events) +
  o padrão C3 do OVERVIEW/playbook §9.
- **Abordagem:** ilha dona do estado de jogo + handlers de evento + handlers PubSub
  (via adapters do pai → `send_update`) + `window_command` próprio.
- **Gotchas:** o `respond_game`/`propose_game` chamam o contexto `Lobby` (server) →
  adapter de string que bubble pro pai? Não — o contexto pode ser chamado de dentro
  da ilha (não precisa de session do parent além de token/nick, que chegam como
  assign). Avaliar: se precisar de algo só-do-pai, usar adapter. `lobby_game_response`
  recusado emite msg de sistema → C1.
- **Validação:** `make ci` 9/9 + `chat-lobby.spec.ts` (game request/start/decline).

## Código atual

- Render: `universal_lobby.ex:272-292` (janela `game`, `on_close="end_game"` →
  `<.game_panel game= game_request= game_outgoing= games= peer_nick= />`).
- Panel (stateless): `components/ui/lobby/game_panel.ex`.
- Assigns: `game` (`lobby_live.ex:676`), `game_request` (`:677`), `game_outgoing`
  (`:678`), `games` (`:679`).
- Eventos UI/hook:
  - `lobby_game_canvas_ready` (`:572`) — se playing, re-push `lobby_game_start`.
  - `propose_game` (`:583`) → `Lobby.propose_game`.
  - `respond_game` (`:590`) → `Lobby.respond_game`.
  - `end_game` (`:598`) → `Lobby.end_game`, limpa request, **`window_command close
    game`**.
  - `lobby_game_result` (`:607`) — no-op (hoje).
- Info PubSub (`lobby:#{token}`):
  - `lobby_game_request` (`:148`) — set request/outgoing, **`window_command open game`**.
  - `lobby_game_response` recusado (`:157`) — limpa request + **msg de sistema (C1)**.
  - `lobby_game_response` aceito (`:166`) — no-op.
  - `lobby_game_status_changed` "playing" (`:170`) — set `game`, limpa request, push
    `lobby_game_start`, **`window_command open game`**.
  - `lobby_game_status_changed` "idle" (`:187`) — reset `game`, push `lobby_game_end`,
    **`window_command close game`**.
- push_events ao hook: `lobby_game_start` (`:183`, `:577`), `lobby_game_end` (`:191`).
- Taskbar badge: `game_active` ● (`universal_lobby.ex:390`) → **C2**.

## Técnica

LiveComponent statefull montado na janela `game`. Dono de
`game`/`game_request`/`game_outgoing`/`games`. Os handlers PubSub viram adapters
finos no pai (o pai recebe na sua `handle_info`, faz `send_update(GameIsland, ...)`) —
mantém o roteamento PubSub no host (uma assinatura de tópico) e o estado na ilha.

### C3 — a ilha dirige a janela `game`

Todos os `window_command {open|close, "game"}` passam a sair da ilha
(`push_event/3` de LiveComponent). O `on_close="end_game"` da janela
(`universal_lobby.ex:276`) vira adapter no pai → `send_update(GameIsland, action:
:end_game)` (ou `phx-target` direto na ilha, se preservar o testid).

### C2 — resumo para a taskbar

Quando `game.status` muda, a ilha faz `send(self(), {:feature_summary, :game,
%{active?: game.status == "playing"}})`; o pai guarda `game_summary` e a taskbar lê
dele (substitui o `@game_active` derivado hoje em `universal_lobby.ex:91,390`).

## Tasks

- [x] Criar `Components.GameIsland` (raiz `<div id={@id}>` estável, `@id` no mount,
      sempre montado; `games` carregado no mount via `Catalog`).
- [x] Mover render de `game_panel` para a ilha; janela monta o `live_component`
      (`connected`/`peer_nick` passthrough).
- [x] Migrar os eventos UI/hook: `lobby_game_canvas_ready` e `end_game` viram adapters
      no pai → `send_update(GameIsland, action: ...)`; `propose_game`/`respond_game`
      ficam no pai (fire-and-forget no contexto, sem estado de ilha; resultado volta
      por PubSub) — a ilha NÃO precisa de token/user_id.
- [x] Migrar os handlers PubSub de jogo: pai recebe e faz `send_update` na ilha
      (request/declined/playing/idle).
- [x] C3: os 4 `window_command {open|close, "game"}` + os push_events ao hook
      (`lobby_game_start`/`lobby_game_end`) saem da ilha (de `update/2`); `end_game`
      (X da janela e botão do painel) via adapter no pai.
- [x] C2: ilha emite `{:feature_summary, :game, %{active?: ...}}` em playing/idle; pai
      ganha `handle_info({:feature_summary, :game, summary})` ACIMA do catch-all e guarda
      `game_summary`; taskbar lê `game_active={@game_summary.active?}`.
- [x] C1: `lobby_game_response` recusado → `send_update(ChatIsland, system_message:)`
      (permanece no pai).
- [x] Removidos do pai os assigns `game/game_request/game_outgoing/games` (+ alias
      `Catalog`).
- [x] Teste de unidade: render por status (connect-prompt/idle/request/outgoing/playing),
      id/data-testid.

## Armadilhas cruzadas (verificadas contra o código)

- ⚠️ **C2 swallow (classe do bug do plano 41) — a armadilha real desta migração.** O
  `send(self(), {:feature_summary, :game, ...})` é uma tupla; o `LobbyLive` tem
  `handle_info(_msg, socket)` catch-all em `lobby_live.ex:228` e só casa `%{event:...}`
  hoje. **Adicione `handle_info({:feature_summary, :game, summary}, socket)` ACIMA da
  linha 228** ou o badge da taskbar nunca atualiza (falha silenciosa). Teste explícito:
  ao entrar/sair de "playing", o badge `●` aparece/some.
- ✅ Eventos de jogo são `phx-click` string com `phx-value-*` → sem trap de
  `select_item`/`JS.push(value:)`. Zero modal-in-modal.
- ⚠️ **`send_update` (PubSub→ilha via adapter) é assíncrono sob LiveViewTest** → flush
  com `render(view)`. Eventos component-local (`@myself`) não disparam por nome em
  feature test → element-click no botão real (adicione `data-testid`).
- Esta ilha é a referência de C2/C3 — deixe os dois contratos exemplares.

## Validação

- [x] Propor jogo → peer vê request, janela `game` abre (C3) no peer. (E2E + unit
      consent; lobby_live_test "proposing a game".)
- [x] Aceitar → ambos entram em "playing", janela abre, canvas inicia. (E2E
      video+game+chat; lobby_live_test playing.)
- [x] Recusar → request some + msg de sistema no chat (C1). (E2E "declining a game".)
- [x] Encerrar (`end_game`) → janela fecha (C3), badge da taskbar some (C2).
      (lobby_live_test "X on the Game window" + novo teste C2 do badge.)
- [x] Isolação por change-tracking: a ilha é LiveComponent próprio → só re-renderiza
      quando seu estado muda.
- [x] `make ci` **9/9** (2026-06-30); `chat-lobby.spec.ts` **20/20** (port 4003 após
      `mix assets.build`).

## Prompt de execução

Leia OVERVIEW + playbook §9. Esta ilha prova C2 e C3 — capriche nos contratos, eles
serão copiados por file/media. PubSub via adapter (host mantém a assinatura).

## Progress Log

- 2026-06-30: Planejado. Não iniciado.
- 2026-06-30: `in_progress`. Escopo: criar
  `RetroHexChatWeb.App.LobbyLive.Components.GameIsland` (dona de
  `game`/`game_request`/`game_outgoing`/`games`; `games` carregado no `mount` via
  `Catalog`). **C3:** a ilha dirige os 4 `window_command {open|close, "game"}` e os
  push_events ao hook (`lobby_game_start`/`lobby_game_end`) de dentro de `update/2`.
  **C2:** `send(self(), {:feature_summary, :game, %{active?: ...}})` em playing/idle; o
  pai ganha `handle_info({:feature_summary, :game, summary})` ACIMA do catch-all e
  guarda `game_summary`; taskbar lê `game_active={@game_summary.active?}`. PubSub de
  jogo fica no host como adapters finos → `send_update(GameIsland, action: ...)`.
  `propose_game`/`respond_game` ficam no pai (fire-and-forget no contexto; resultado
  volta por PubSub) e `end_game` é adapter no pai (chama `Lobby.end_game` + `send_update`
  na ilha). A ilha NÃO precisa de token/user_id (sem chamada de contexto). C1 do
  declined permanece no pai. Arquivos: `game_island.ex` (novo), `game_island_test.exs`
  (novo), `lobby_live.ex`, `universal_lobby.ex`, `lobby_live.html.heex`,
  `lobby_live_test.exs` (flush + teste C2 do badge). Validação planejada: `make ci`
  9/9 + `chat-lobby.spec.ts` (game request/start/decline).
- 2026-06-30: `complete`. Implementado conforme o escopo. **C2 e C3 estabelecidos** (a
  ilha é a referência para 03/04). C3: a ilha dispara os 4 `window_command` e os
  push_events ao hook de dentro de `update/2` (`push_event` funciona em `update/2` de um
  LiveComponent). C2: `summarize/1` faz `send(self(), {:feature_summary, :game, ...})`
  em playing/idle; **a cláusula explícita `handle_info({:feature_summary, :game,
  summary})` foi colocada ACIMA do catch-all** — sem ela o badge nunca acende
  (armadilha do swallow confirmada e coberta por teste). `propose_game`/`respond_game`
  ficaram no pai (fire-and-forget; resultado volta por PubSub) → a ilha não precisa de
  token/user_id. **Validação real:** `make ci` **9/9** de primeira (format já rodado
  antes); `chat-lobby.spec.ts` **20/20**; unit GameIsland 6/6; lobby_live_test 19/19
  (inclui o teste C2 do badge + flush `render(view)` no end_game). Arquivos:
  `game_island.ex` (novo, ~135 ln), `game_island_test.exs` (novo), `lobby_live.ex`,
  `universal_lobby.ex`, `lobby_live.html.heex`, `lobby_live_test.exs`. Aprendizado: o
  badge da taskbar é o teste-canário do swallow — `Process.sleep(50) + render(view)`
  drena toda a cadeia assíncrona (event → send_update → ilha → `send(self(),
  feature_summary)` → pai → assign) porque o processo da LV roda seu loop sozinho.
