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

- [ ] Criar `Components.GameIsland` (raiz estável, `@id` no mount, sempre montado).
- [ ] Mover render de `game_panel` para a ilha; janela monta o `live_component`.
- [ ] Migrar os 5 eventos UI/hook para a ilha (component-local quando não precisam do
      pai; adapter quando precisam).
- [ ] Migrar os handlers PubSub de jogo: pai recebe e faz `send_update` na ilha.
- [ ] C3: mover os 4 `window_command {open|close, "game"}` para a ilha; `end_game`
      via adapter/`phx-target`.
- [ ] C2: emitir `{:feature_summary, :game, ...}`; pai guarda `game_summary`; taskbar
      lê dele.
- [ ] C1: `lobby_game_response` recusado → `send_update(ChatIsland, system_message:)`.
- [ ] Remover do pai os assigns `game/game_request/game_outgoing/games`.
- [ ] Teste de unidade: render por status (idle/request/playing), id/data-testid.

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

- [ ] Propor jogo → peer vê request, janela `game` abre (C3) no peer.
- [ ] Aceitar → ambos entram em "playing", janela abre, canvas inicia.
- [ ] Recusar → request some + msg de sistema no chat (C1).
- [ ] Encerrar (`end_game`) → janela fecha (C3), badge da taskbar some (C2).
- [ ] Abrir/fechar/dragar OUTRA janela não re-renderiza a ilha de jogo.
- [ ] `make ci` 9/9; `chat-lobby.spec.ts` (game request/start/decline) verde.

## Prompt de execução

Leia OVERVIEW + playbook §9. Esta ilha prova C2 e C3 — capriche nos contratos, eles
serão copiados por file/media. PubSub via adapter (host mantém a assinatura).

## Progress Log

- 2026-06-30: Planejado. Não iniciado.
