# Lobby (P2P Universal) — Decomposição em Ilhas de LiveView

## Objetivo

Decompor o monólito `RetroHexChatWeb.App.LobbyLive` (`live/app/lobby_live.ex`, ~936
linhas, ~55 `handle_event` + ~20 `handle_info` misturando 6 features sobre uma
conexão WebRTC) em **ilhas LiveComponent statefull**, aplicando o
`STATEFUL-COMPONENT-PLAYBOOK.md` — o mesmo padrão que decompôs o ChatLive (210→70
`assign_defaults`, 58 planos, todos completos).

A característica nova aqui é o **windowing**: o lobby é um desktop Win98 onde cada
feature vive numa janela (`desktop_window`). Esta série trata a janela como cidadã
de primeira classe do padrão.

## Artefatos da série

- [`PROGRESS.md`](PROGRESS.md) — quadro central de status + mapa de dependências +
  armadilhas. **Atualize a cada loop.**
- [`00-loop-execution-prompt.md`](00-loop-execution-prompt.md) — prompt de execução em
  loop (regras, ritual, contratos, armadilha transversal, constraints de WebRTC).
- `01`–`04` — um plano por ilha, cada um com `## Classificação`, `## Armadilhas
  cruzadas`, `## Tasks`, `## Validação`, `## Prompt de execução`, `## Progress Log`.
- `../STATEFUL-COMPONENT-PLAYBOOK.md` **§9** — a regra nova de windowing.

## Veredito da análise (por que isto corta limpo)

O windowing **ajuda** a decomposição. Cada `desktop_window` já é chrome client-side
(o `WindowManagerHook` é dono de posição/tamanho/z-order/min-max/open via
localStorage) embrulhando um **panel stateless** alimentado por assigns do
`LobbyLive`. As features já estão fisicamente isoladas em janelas — só falta dar a
cada uma um **dono stateful**.

Confirmado: `push_event("window_command", %{action, id})` funciona **de dentro de um
LiveComponent** — o `this.handleEvent("window_command", ...)` do hook
(`assets/js/hooks/ui/window_manager_hook.js:56`) não é escopado a um elemento. Logo
uma ilha **dirige a própria janela** sem rotear pelo pai.

## Arquitetura alvo

```
LobbyLive (PAI = host / orquestrador / agregador) — NÃO é ilha
 ├─ Backbone WebRTC (uma RTCPeerConnection, 2 data channels):
 │   lobby_signal, lobby_renegotiate, lobby_start_signaling, lobby_webrtc_ready,
 │   role/offerer, maybe_start_webrtc, lobby_state_change, terminate/2
 ├─ Presença + identidade: peer_online, local_info/peer_info,
 │   lobby_peer_joined, lobby_client_info
 ├─ Ciclo de vida: lobby_status_changed, inactivity, session_closed, leave_lobby
 ├─ Janela "conn" (Statistics): stats + p2p_connection_strip + privacy + clock
 │   ← AGREGADOR cross-cutting puro: FICA NO PAI (não vira ilha)
 └─ Taskbar (badges lidos dos RESUMOS espelhados pelas ilhas)

 4 ILHAS (LiveComponent, uma por janela):
 ├─ LobbyChatIsland   (janela "chat")  → messages, send_message, lobby_message
 ├─ LobbyGameIsland   (janela "game")  → game/request/outgoing/games + PubSub de jogo
 ├─ LobbyFileIsland   (janela "file")  → file_transfer + família ft_* (data-channel)
 └─ LobbyMediaIsland  (janela "call")  → call/layout/mute/camera/devices + media
```

### Por que `conn`/telemetria e o backbone WebRTC ficam no pai

- A janela `conn` (`universal_lobby.ex:163-204`) é um **leitor cross-cutting puro**:
  agrega `call`, `file_transfer`, `stats`, `local_info`, `peer_info`,
  `connection_label`, `turn_only`. É o caso "conversations" do playbook (agregador
  pequeno e churny) → **mantém no agregador, não extrai.**
- `stats` é um struct único que mescla telemetria de TODAS as features
  (`lobby_live.ex:820-851`); é emitido pelo hook de conexão. Pertence ao host.
- `turn_only`/`turn_configured` (privacy) decidem o start do WebRTC
  (`maybe_start_webrtc`, `lobby_live.ex:700-702`) → têm de ser visíveis ao host.
- O backbone de sinalização (PC única multiplexando `filetransfer` + `gamedata`) é
  compartilhado por media+file+game → **nunca** numa ilha.

## Os três contratos cross-island (o que o playbook ainda não tinha)

Estes contratos são o coração da migração. Cada plano de ilha referencia este
arquivo.

### C1 — Mensagens de sistema (sink compartilhado)

`messages` (`lobby_live.ex:659`) é alimentado por media (`:432`, `:437`), file
(`:504`), game (`:163`) e falhas de conexão (`:283`), não só pelo chat.

→ **A `LobbyChatIsland` é dona de `messages`.** Qualquer outra ilha (ou o pai) que
precise registrar uma mensagem de sistema faz **`send_update(LobbyChatIsland, id:
"lobby-chat", system_message: txt)`**. Mesmo shape do "PubSub notification queue
(kick, plano 48)": o componente é dono da lista; os demais fazem um `send_update` de
uma linha.

### C2 — Read-model no pai (taskbar + janela conn)

A taskbar lê `call.duration` (`universal_lobby.ex:376`), `file_transfer.percent`
(`:383`), `game_active` (`:390`); a janela `conn` lê `call` + `file_transfer`. Esses
leitores ficam no template do pai (`universal_lobby.ex`).

→ **Cada ilha é dona do estado COMPLETO da sua feature** e espelha um **resumo
mínimo** ao pai sempre que muda: `send(self(), {:feature_summary, :call, %{active?:
true, duration: "01:23"}})` (em LiveComponent, `self()` é o pid do pai). O pai
guarda só `call_summary`/`file_summary`/`game_summary` para os badges e a strip.
**Zero refactor dos leitores** — exatamente o padrão `shared-list-stream`
(read-model no pai + render-model na ilha, ligados por deltas).

### C3 — Windowing: a ilha dirige a própria janela (regra NOVA — ver playbook §9)

- A ilha emite **`push_event("window_command", %{action: "open"|"close"|"flash", id:
  "<sua-janela>"})`** diretamente (funciona de LiveComponent).
- Os eventos `on_close` das janelas (`end_call`/`ft_cancel`/`end_game`, definidos em
  `universal_lobby.ex:226/254/276`) passam a ser **adapters finos no pai** que fazem
  `send_update` na ilha (preserva os `data-testid` e o contrato Playwright — regra
  "adapter default" do playbook §1).
- Os `lobby_*`/`ft_*` push_events para os hooks JS também migram para a ilha (ela é
  quem fala com o hook da sua feature).

## Preservação de contratos (anti-churn)

Usar **"adapter default"** (playbook §1): os nomes de evento legados continuam
disparando no pai como adapters finos que fazem `send_update` na ilha. Assim
preserva-se sem mudança:

- Os **16 testes Playwright** `e2e/tests/chat-lobby.spec.ts` (page object
  `e2e/pages/LobbyPage.ts`, helpers `e2e/helpers/lobbyFlows.ts`).
- Todos os `data-testid` (`lobby-window-*`, `lobby-menu-*`, `lobby-shortcut-*`, etc.).
- Os JS hooks (`LobbyWebRTCHook`, `WindowManagerHook`, `ClockHook`).

## Constraint crítico — manter hooks montados

`LobbyWebRTCHook` (`universal_lobby.ex:104-105`) e os panels das features **não podem
desmontar em blips de status**. O latch `ever_connected` → flag derivada `mounted`
(`universal_lobby.ex:40-42,89`) existe para isso. As ilhas **sempre** são montadas
(nunca dentro de `:if`); a visibilidade é interna; a raiz é `<div id={@id}>` estável
(playbook §3). O `mounted`/`connected` chegam como assigns passthrough do pai.

## Cross-check do playbook (verificado contra o código real, 2026-06-30)

Cada armadilha histórica do `STATEFUL-COMPONENT-PLAYBOOK.md` foi cruzada com o código
do lobby. Resultado: **o lobby é bem mais limpo que o ChatLive para esta migração.**

### Armadilhas que NÃO se aplicam (confirmado por grep)

- **Modal-in-modal (`fixed inset-0` + input não-controlado)** — o ⛔ bloqueador
  comprovado 3× no chat (playbook §0a-anti): **0 ocorrências** nos 5 panels
  (`components/ui/lobby/*.ex`). Nenhuma ilha é bloqueada.
- **`render_submit` não dispara `JS.push(evt, value:)`** — o form de chat usa
  `phx-submit="send_message"` (evento STRING) + `name="content"` (campo nomeado), que
  é o padrão SEGURO do playbook. File usa `<input type=file>` hook-driven; game usa
  cliques. Nenhum form com `JS.push(value:)`.
- **`select_item` força evento string** — devices de mídia são `<select
  data-device-kind>` CRU (lido pelo `LobbyMediaHook`), e layout/preset são
  `phx-click` + `phx-value-layout`/`-preset` (string). Nenhum select do design-system.

### A ÚNICA armadilha que SE aplica — ⚠️ C2 swallow (classe do bug do plano 41)

O `LobbyLive` é um **LiveView simples** (`handle_info` direto, SEM o reducer
`attach_hook`/`info_hooks` do ChatLive). Tem um catch-all **`handle_info(_msg, socket),
do: {:noreply, socket}` na `lobby_live.ex:228`**, e TODAS as cláusulas PubSub existentes
casam o shape `%{event: ..., payload: ...}`.

→ O bubble do contrato **C2** — `send(self(), {:feature_summary, key, summary})` é uma
**tupla**, não casa com `%{event:...}`, e **cai no catch-all da linha 228, sendo
silenciosamente engolida.** É a mesma classe do bug do plano 41 (catch-all comendo
bubbles ilha→pai).

**Mitigação obrigatória em TODO plano que usa C2 (game/file/media):** adicionar
cláusulas `handle_info({:feature_summary, key, summary}, socket)` explícitas **ACIMA**
da linha 228, e validar com um teste que o resumo realmente chega (badge/strip muda).
Idem para qualquer outro bubble por tupla. C1 usa `send_update` (não cai aqui), mas
lembre do §2: `send_update` é assíncrono sob LiveViewTest (flush via `render(view)`).

### Outras notas do playbook/memórias a respeitar

- **Moduledoc descreve o código, não a atividade** (memória
  `comments-describe-code-not-activity`): nada de "migrado do LobbyLive", refs a plano,
  etc. nos `@moduledoc`/comentários das ilhas.
- **i18n** (memória `windowed-lobby-redesign`): o domínio gettext `lobby` não tem
  `.pot` e `gettext.extract --check` já falha no baseline; **NÃO** rodar
  `i18n.gettext.rebuild` dentro de um PR de feature (diff gigante de 21 locales).
  Strings novas caem no source em runtime e entram na próxima wave.
- **Feature Tests ≠ Playwright:** `make ci` roda `mix test --only liveview_feature`
  (in-process). O E2E `chat-lobby.spec.ts` é separado (`cd e2e && npx playwright test`)
  e exige `mix assets.build` antes (senão serve bundle velho sem o hook novo).
- **Chrome cru em LiveComponent → fica na função-componente.** Os panels já são
  function components em `components/ui/lobby/`; a ilha apenas os monta (sem Tailwind
  cru solto no LiveComponent — playbook §1d / nicklist).

## Ordem de execução (menor acoplamento primeiro)

Cada tier é um gate `make ci` 9/9 + `chat-lobby.spec.ts` verde (Playwright NÃO está
no `scripts/ci.exs`; rode `cd e2e && npx playwright test chat-lobby` após
`mix assets.build`).

| Tier | Plano | Ilha | Por que nessa ordem |
|---|---|---|---|
| 1 | [01](01-chat-island.md) | **Chat** | Dona de `messages` (o sink) → estabelece C1 cedo; mais simples |
| 2 | [02](02-game-island.md) | **Game** | Own-PubSub + own-window self-contida → estabelece C2 + C3 |
| 3 | [03](03-file-island.md) | **File** | Família `ft_*` coesa, sem PubSub (data-channel) |
| 4 | [04](04-media-island.md) | **Media** | A gigante: `surface_peer_media` (auto-join + windowing), devices, `call` cross-read |

Telemetria/privacy + backbone WebRTC + lifecycle = **permanecem no pai** (sem plano
de extração).

## Definition of done (a série toda)

- `LobbyLive` reduzido ao host: backbone WebRTC + presença + lifecycle + agregador
  `conn` + taskbar (read-model). As ~55 `handle_event`/~20 `handle_info` das 4
  features migradas para suas ilhas (adapters finos restantes no pai).
- `make ci` 9/9 em cada tier; `chat-lobby.spec.ts` 16/16 (ou paridade de baseline
  comprovada via `git stash`).
- Cada ilha: `@moduledoc` com a decisão de ownership + `@spec` em toda fn pública,
  ZERO `<svg>` inline (facade `Icons.*`), ZERO cor/`style=` hardcoded
  (`mix audit.styles --strict` = 0), teste de unidade
  (`use RetroHexChatWeb.ConnCase, async: true` + `@moduletag :unit`).
- Help: migração preserva comportamento → sem novo tópico de ajuda (playbook §7b).

## Progress Log

- 2026-06-30: Série planejada. Mapa estrutural completo levantado (assigns/eventos/
  info/hooks/janelas). Arquitetura travada: pai = host/agregador, 4 ilhas, 3
  contratos (C1 system-msg, C2 read-model, C3 window self-drive). Nenhuma
  implementação iniciada.
