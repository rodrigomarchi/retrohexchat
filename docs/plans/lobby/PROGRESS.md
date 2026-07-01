# Lobby (P2P Universal) — Progresso da Decomposição em Ilhas

Quadro central de progresso da decomposição do `LobbyLive`. **Atualize-o em todo loop
de implementação**, junto com o `## Progress Log` do plano individual. É o gêmeo do
`../PROGRESS.md` (que rastreou a migração — concluída — do ChatLive).

> Antes de qualquer coisa, leia [`00-OVERVIEW.md`](00-OVERVIEW.md) (arquitetura + 3
> contratos + cross-check do playbook) e `../STATEFUL-COMPONENT-PLAYBOOK.md` (receita +
> §9 windowing).

## Status Legend

- `pending`: ainda não iniciado.
- `in_progress`: iniciado, parcial ou aguardando validação.
- `blocked`: impedimento concreto, com próximo passo registrado.
- `complete`: tasks relevantes concluídas e validação registrada.

## Loop Rules

- **Leia o `STATEFUL-COMPONENT-PLAYBOOK.md` (esp. §9 windowing + §0a-anti) antes de
  cada extração.** Os 4 planos seguem o mesmo padrão — não redescubra armadilhas.
- **Respeite a ordem de tiers** (acoplamento crescente): 01 chat → 02 game → 03 file →
  04 media. Cada tier depende dos contratos provados no anterior.
- Antes de editar código, marque o plano escolhido como `in_progress` aqui.
- Depois de editar, registre evidência de validação (`make ci` 9/9 + spec Playwright).
- Nunca marque `complete` sem atualizar o checklist do plano individual.
- Sempre inclua o próximo passo.
- Registre **aprendizados novos** no `## Histórico de aprendizados` deste arquivo E,
  se forem reutilizáveis, na §9/Histórico do playbook.
- Use a data real do ambiente no momento da execução.

## Quadro de planos

| Tier | Plano | Ilha | Status | Contratos que estabelece/usa |
|---|---|---|---|---|
| 1 | [01](01-chat-island.md) | Chat | `complete` | **estabelece C1** (system-msg) |
| 2 | [02](02-game-island.md) | Game | `complete` | **estabelece C2+C3**; usa C1 |
| 3 | [03](03-file-island.md) | File | `complete` | usa C1/C2/C3; constraint hook-montado |
| 4 | [04](04-media-island.md) | Media | `complete` | usa todos; `surface_peer_media` |
| — | — | conn/telemetria + privacy + backbone WebRTC + taskbar | **fica no pai** (sem extração) | agregador / read-model |

## Mapa de Dependências & Armadilhas (para agentes de execução)

**Ordem obrigatória:** 01 → 02 → 03 → 04. Não pule.

- **01 Chat** é dona de `messages` (o sink de mensagens de sistema) → faça primeiro
  para o contrato **C1** existir quando 02/03/04 precisarem registrar mensagens.
- **02 Game** é a mais limpa (own-PubSub + own-window) → prova **C2** (read-model →
  taskbar) e **C3** (ilha dirige a própria janela), que 03/04 copiam.
- **03 File**: risco nº1 = **hook-sempre-montado** (ilha sempre montada, visibilidade
  por classe `u-hidden`, nunca `:if`). Sem PubSub (data-channel).
- **04 Media**: a gigante — sessão dedicada; `surface_peer_media` (auto-join +
  windowing) e o cenário de **vídeo bidirecional** (RTP real) são o que mais regride.
  NÃO tocar na negociação single-offerer (backbone do pai).

### ⚠️ A armadilha transversal (classe do bug do plano 41) — vale para 02/03/04

O `LobbyLive` tem `handle_info(_msg, socket)` catch-all em `lobby_live.ex:228` e só casa
`%{event:...}`. O bubble do contrato **C2** é uma TUPLA
(`send(self(), {:feature_summary, ...})`) → **cai no catch-all e é engolido em
silêncio.** Sempre adicione a cláusula `handle_info({:feature_summary, ...})` explícita
ACIMA da linha 228 e teste que o badge/strip muda.

### Armadilhas que NÃO se aplicam (já cruzadas — ver OVERVIEW)

Modal-in-modal (0 ocorrências), `render_submit`/`JS.push(value:)` (chat já é string +
campo nomeado), `select_item` (devices são `<select>` cru; layout/preset são string).

## Current Focus

- **🎉 SÉRIE COMPLETA (2026-06-30): as 4 ilhas extraídas.** `LobbyLive` reduzido ao host
  (backbone WebRTC + presença + lifecycle + agregador `conn`/Statistics + taskbar
  read-model). Cada feature agora vive numa ilha LiveComponent:
  - **01 Chat `complete`** — `ChatIsland` dona de `messages`; **C1** (system-msg sink).
  - **02 Game `complete`** — `GameIsland`; estabeleceu **C2** + **C3** (referência).
  - **03 File `complete`** — `FileIsland` + família `ft_*` (hook→raiz ⇒ adapters no host);
    hook sempre montado (constraint).
  - **04 Media `complete`** — `MediaIsland` self-contained (`surface_peer_media`,
    `Lobby.set_media`/broadcast, devices); single-offerer/signaling intactos.
- **Evidência final:** `make ci` **9/9** + `chat-lobby.spec.ts` **20/20** (incl.
  bidirectional-video RTP) + 20 testes de unidade de ilha + lobby_live_test 21/21.
- **Próximo:** nenhum plano restante na série. Follow-ups possíveis (fora desta série):
  remover `/p2p` e `/game` legados quando o lobby atingir paridade (memória
  [[universal-lobby]]); auditar assigns mortos remanescentes no host.
- Last updated: 2026-06-30

## Histórico de aprendizados

- 2026-07-01 (auditoria pós-série): revisão adversarial (2 agentes) + gates confirmam a
  série pronta p/ produção. Achados: (1) `media_ready` era estado MORTO já no host
  original (só atribuído, nunca lido no lobby) — removido da `MediaIsland` (§5 do
  playbook); `lobby_media_hook_ready` cai no no-op catch-all da ilha (comportamento
  idêntico). (2) Contratos E2E/hooks 100% preservados (todo testid/id/selector +
  pushEvent↔handler + handleEvent↔push). (3) Nenhum bug de comportamento: 48 handle_event
  + 21 handle_info antigos mapeados; prefix adapters exatos; ilhas sempre montadas (maior
  risco — não ocorre); `surface_peer_media` byte-equivalente; summaries C2 completos.
  ⚠️ **Flake pré-existente descoberto (NÃO é regressão desta série):** o worker "Feature
  Tests" do `make ci` (`--only liveview_feature`, roda concorrente com o worker "test")
  falha intermitentemente (~2 de 3 runs) sob carga; isolado passa 212/0 e um `make ci`
  limpo dá 9/9. O worker de feature NÃO contém testes do lobby (lobby é `:liveview`, no
  outro worker), então é infra/concorrência, alheio à decomposição — vale investigar à
  parte. Evidência final: `make ci` **9/9** limpo + `chat-lobby.spec.ts` **20/20** (incl.
  bidirectional-video) após a limpeza do `media_ready`.
- 2026-06-30 (plano 04, Media — a gigante, série concluída): a ilha mais entrelaçada
  migrou sem regressão repetindo os padrões de 02/03. **Self-contained quando o estado e
  os efeitos são inseparáveis:** diferente do Game (propose/respond ficaram no host por
  serem fire-and-forget sem estado), aqui cada `Lobby.set_media`/broadcast vem JUNTO de
  uma transição de `call`/mute/camera — então a ilha recebe token/user_id e chama o
  contexto + faz `broadcast` ela mesma; partir isso entre host e ilha duplicaria a
  extração de params. A assinatura PubSub continua no host (3 adapters inbound). **`stats`
  e `network_info_open` ficaram no host** (são da janela Statistics, agregador
  cross-cutting) — `lobby_media_call_ended` é o único adapter de mídia que NÃO é genérico
  (reseta `stats` host-owned + forward). **Armadilha nova: id da ilha vs. id interno do
  panel.** O `@id` da ilha (`<div id={@id}>`) NÃO pode colidir com nenhum `id=` que o
  function-component renderiza dentro — o `media_panel` já usa `id="lobby-media"` (o
  elemento do hook), então a ilha teve que ser `lobby-media-island`. "Duplicate id found
  while testing LiveView" em runtime é o sintoma; o `live_component id=` deve casar com
  `Ilha.id()`. **C2 com cross-read que muda por segundo:** o `duration` tick re-emite o
  summary a cada segundo → o `handle_info({:feature_summary, :call, ...})` só guarda
  (barato). `call_summary` = `Map.take([:type, :duration, :quality_label])` cobre badge +
  strip. Single-offerer/signaling: nem tocados — a ilha só pede mídia via push ao hook.
  Bidirectional-video RTP (#13) passou limpo. **Série encerrada: as 4 ilhas extraídas, o
  host virou orquestrador/agregador puro.**
- 2026-06-30 (plano 03, File — hook compartilhado + cross-read rico): duas lições novas.
  **(1) Hook que faz `pushEvent` empurra para a LV RAIZ, não para o LiveComponent** —
  mesmo quando o elemento do hook vive dentro da ilha. Então eventos de ENTRADA de um
  hook compartilhado (`FileTransferHook`, usado também pelo chat) ficam no host como
  adapters; só a SAÍDA (server→client: `push_event`/`window_command`) sai da ilha (o
  `handleEvent` do hook escuta o socket inteiro, capta de qualquer componente). Aqui os
  ~18 `ft_*` viraram 2 adapters: `file_transfer_ready` + a genérica `"ft_" <> _` →
  `send_update(FileIsland, action: {:ft_event, name, params})`; a ilha despacha por nome.
  Reduziu MUITO o host. **(2) O resumo C2 não é sempre "mínimo de badge".** A strip da
  janela agregadora `conn` lê `file_transfer` rico (status/sender_nick/percent/speed/
  file_name) → o `file_summary` espelha esses 5 campos (`Map.take`), não só o `%`.
  Regra: o summary carrega a UNIÃO do que os leitores cross-cutting do host precisam
  (badge + strip). **Constraint do hook-sempre-montado** sai de graça: ilha montada via
  `live_component` (nunca `:if`) → fechar a janela (X→`ft_cancel`) só esconde; teste
  prova `phx-hook="FileTransferHook"` ainda no DOM após cancelar. Flake conhecido:
  bidirectional-video (RTP real, mídia) falha ~1/2 sob carga e passa isolada — não é
  regressão de file; confirmar isolando o teste antes de investigar.
- 2026-06-30 (plano 02, Game — C2 + C3 estabelecidos): a ilha de jogo virou a
  referência dos dois contratos. **C3:** `push_event/3` funciona dentro do `update/2` de
  um LiveComponent — então a ilha dispara `window_command {open|close, "game"}` e os
  lifecycle do hook (`lobby_game_start`/`lobby_game_end`) direto, sem rotear pelo pai.
  Os handlers PubSub de jogo viraram adapters de 2 linhas no pai (`send_update(GameIsland,
  action: ...)`); o `on_close="end_game"` da janela e o botão "End game" do painel
  disparam o MESMO `end_game` (adapter) → preserva ambos sem mudança. **C2:** a ilha faz
  `send(self(), {:feature_summary, :game, %{active?: ...}})` em playing/idle e o pai
  guarda `game_summary`; a taskbar lê `game_active={@game_summary.active?}`. ⚠️ A
  cláusula `handle_info({:feature_summary, :game, summary})` PRECISA estar ACIMA do
  catch-all (`handle_info(_msg, socket)`) — confirmado: sem ela a tupla é engolida e o
  badge nunca acende. O **badge é o canário** desse bug — escrevi um teste que entra/sai
  de "playing" e asserta `render(view) =~ "●"`. **Decisão de ownership:** eventos
  fire-and-forget que só chamam o contexto e cujo resultado volta por PubSub
  (`propose_game`/`respond_game`) FICAM no pai — a ilha não precisou de token/user_id.
  Só estado + render + window-driving + summary migraram. **Mecânica de teste:**
  `Process.sleep(50) + render(view)` drena a cadeia assíncrona inteira (event →
  send_update → ilha → `send(self(), feature_summary)` → pai → assign) porque o processo
  da LV roda seu próprio loop; `assert_push_event` de push vindo de `send_update` precisa
  de `render(view)` antes (flush). `games` (catálogo estático) carregou no `mount` da
  ilha — saiu do pai.
- 2026-06-30 (plano 01, Chat — 1ª ilha, C1 estabelecido): a receita do playbook §9
  escala limpa pro lobby. Confirmado em runtime: um `live_component` montado dentro do
  slot de um **function component** (`desktop_window`) que por sua vez é chamado pela
  LiveView funciona — cid e change-tracking corretos, sem precisar mover o
  `desktop_window` pra LiveView. **C1 na prática:** a ilha dona da lista expõe DOIS
  shapes de `update/2` — `{:system_message, txt}` (constrói o map de sistema DENTRO da
  ilha) e `{:append_message, msg}` (eco cru do PubSub `lobby_message`); o pai vira só
  adaptador `send_update(ChatIsland, id: ChatIsland.id(), ...)` em 6 callsites. A ilha
  carrega seu próprio `system_message/1` (o do pai foi removido). Wrapper de raiz
  precisa de `class="h-full"` pra preservar a cadeia `h-full` do `chat_panel` dentro do
  `window_body` (`flex-1`). `live/app/` é pulado pelo `lint.css_consistency`, então
  Tailwind cru (`h-full`) na ilha passa. Único tropeço: linhas longas de `send_update`
  quebraram o Format no 1º `make ci` (Stage 3/Dialyzer foi skipado) — `mix format`
  antes do gate evita o ciclo. Sem swallow de catch-all aqui (C1 usa `send_update`, não
  tupla) — essa armadilha entra a partir do 02 (C2).
- 2026-06-30: Série planejada e cruzada com o código real (grep das armadilhas do
  playbook). Lobby é mais limpo que o ChatLive (sem modal-in-modal, form de chat já
  seguro, sem `select_item`). Única armadilha transversal = swallow do catch-all
  (linha 228) sobre o bubble C2 por tupla. Windowing confirmado compatível
  (`window_command` funciona de LiveComponent). Nenhuma implementação iniciada.
