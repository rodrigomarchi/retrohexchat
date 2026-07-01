# Lobby — Media (Call) Island

> Pré-requisito de leitura: [`00-OVERVIEW.md`](00-OVERVIEW.md) e
> `../STATEFUL-COMPONENT-PLAYBOOK.md`. Depende de
> [`03-file-island.md`](03-file-island.md) (C1/C2/C3 maduros). **É a gigante — última.**

## Objetivo

Extrair áudio/vídeo para
`RetroHexChatWeb.App.LobbyLive.Components.MediaIsland`, dona de `call`,
`call_layout`, `local_muted`, `local_camera_off`, `peer_muted`, `peer_camera_off`,
`peer_media`, `devices`, `media_ready`. É a ilha mais entrelaçada: tem PubSub,
windowing, sink de mensagens, devices e — o nó górdio — `surface_peer_media`
(auto-join de call disparado por mensagem do peer).

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo — reservar sessão dedicada; não fatiar.
- **Dependências:** entra C1/C2/C3 já provados. É a última.
- **Componente de referência:** GameIsland (PubSub via adapter) + FileIsland
  (família de eventos coesa) — combina os dois.
- **Abordagem:** ilha dona de todo o estado de mídia + handlers; PubSub via adapter
  do pai; dirige a janela `call`; espelha resumo (active?+duration) p/ taskbar e
  strip.
- **Gotchas:**
  - **`surface_peer_media/2` (`lobby_live.ex:759-794`)** é o handler mais entrelaçado:
    um PubSub `lobby_media_changed` muta `call`/`local_muted`/`local_camera_off` E
    dispara `lobby_media_join` + **`window_command open call`** (auto-join) ou encerra.
    Migra inteiro para a ilha (via adapter do pai que `send_update`).
  - **`call` é cross-read** pela strip da janela `conn` (`universal_lobby.ex:199`) e
    pelo badge da taskbar (`:376`) → resolvido por C2 (resumo no pai), NÃO por mover
    a janela `conn`.
  - **Negociação é single-offerer** (só o initiator emite offers) — NÃO mexer nessa
    lógica; ela é do backbone WebRTC (pai), não da ilha. A ilha só pede mídia via
    push_events ao hook; o pai/hook cuidam de offer/answer (constraint do
    `universal-lobby`, ponto 2).
  - `mounted`/`connected` chegam como assign passthrough (latch `ever_connected` é do
    pai); a ilha é sempre montada.
- **Validação:** `make ci` 9/9 + `chat-lobby.spec.ts` (audio→video upgrade,
  **bidirectional video quando ambos ligam ao mesmo tempo** — assert de RTP real
  `track.muted === false`, media controls, video+game+chat concorrentes, all-four).

## Código atual

- Render: `universal_lobby.ex:222-247` (janela `call`, `on_close="end_call"` →
  `<.media_panel connected={@mounted} call= call_layout= peer_nick= nickname=
  local_muted= local_camera_off= peer_media= peer_camera_off= peer_muted= devices= />`).
- Panel (stateless): `components/ui/lobby/media_panel.ex`.
- Assigns: `call` (`:660`), `call_layout` (`:661`), `local_muted` (`:662`),
  `local_camera_off` (`:663`), `peer_muted` (`:664`), `peer_camera_off` (`:665`),
  `peer_media` (`:666`), `devices` (`:669`), `media_ready` (`:658`).
- Eventos UI/hook (`lobby_live.ex`):
  `lobby_media_hook_ready` (`:304`), `start_call` video/audio (`:308`/`:317`,
  **`window_command open call`**), `lobby_media_call_started` (`:329`),
  `end_call` (`:352`), `lobby_media_call_ended` (`:356`, reset + **`window_command
  close call`**), `lobby_media_mute_changed` (`:373`, broadcast peer),
  `lobby_media_camera_changed` (`:386`, broadcast peer), `lobby_media_duration_tick`
  (`:396`), `lobby_media_quality_update` (`:401`), `media_select_preset` (`:412`),
  `set_call_layout` (`:416`/`:421`), `lobby_media_devices_listed` (`:427`),
  `lobby_media_device_fallback` (`:431`, **msg sistema C1**), `lobby_media_error`
  (`:435`, **msg sistema C1**).
- Info PubSub: `lobby_peer_mute` (`:112`), `lobby_peer_camera` (`:123`),
  `lobby_media_changed` (`:138`) → **`surface_peer_media/2`** (`:759-794`).
- push_events ao hook: `lobby_media_peer_muted` (`:119`), `lobby_media_peer_camera`
  (`:130`), `lobby_media_start_video`/`_audio` (`:313`/`:322`), `lobby_media_end_call`
  (`:353`,`:790`), `lobby_media_join` (`:776`), `lobby_media_set_preset` (`:413`).
- **Cross-read:** taskbar badge `call[:duration]` (`universal_lobby.ex:376`); strip
  `call={@call}` (`:199`) → ambos viram **C2**.

## Técnica

LiveComponent statefull montado na janela `call`, sempre montado (`connected=
{@mounted}` passthrough). Dono de todo o estado de mídia + handlers (UI/hook
component-local; PubSub via adapter do pai → `send_update`).

- **`surface_peer_media`** migra inteiro para a ilha; o adapter do pai para
  `lobby_media_changed` só repassa o payload. A ilha decide auto-join/encerrar e
  emite seu próprio `window_command` + push_events ao hook.
- **C3:** todos os `window_command {open|close, "call"}` saem da ilha; `end_call`
  (on_close `universal_lobby.ex:226`) via adapter/`phx-target`.
- **C2:** ao mudar `call` (incl. `duration` no tick), emitir `{:feature_summary,
  :call, %{active?: call != nil, duration: call[:duration]}}`; o pai guarda
  `call_summary` para o badge da taskbar E para a `p2p_connection_strip`
  (a strip passa a receber `call_summary` em vez de `@call` cru).
- **C1:** `lobby_media_device_fallback`/`lobby_media_error` →
  `send_update(ChatIsland, system_message:)`.

> Nota de fronteira: a strip/`conn` é o agregador no pai (OVERVIEW). Quando `call`
> sair para a ilha, a strip passa a ler `call_summary` (C2). Confirmar que o resumo
> carrega tudo que a strip mostra (tipo/áudio/vídeo/qualidade) — se a strip precisar
> de mais que o resumo, ampliar o resumo, NUNCA mover a janela `conn` para a ilha.

## Tasks

- [x] Criar `Components.MediaIsland` (raiz `<div id={@id} class="h-full">`,
      `@id="lobby-media-island"` no mount — distinto do `id="lobby-media"` do panel —,
      sempre montado).
- [x] Mover `media_panel` para a ilha; janela monta o `live_component`.
- [x] Migrar todos os eventos UI/hook de mídia — via adapters no host (o `LobbyMediaHook`
      faz `pushEvent` p/ a raiz): `lobby_media_call_ended` explícito (reset de `stats`
      host-owned) + genérica `"lobby_media_" <> _` + guarda
      `start_call`/`end_call`/`set_call_layout`/`media_select_preset` →
      `send_update(MediaIsland, action: {:media_event, name, params})`.
- [x] Migrar `surface_peer_media` (inteiro) + os 3 handlers PubSub
      (peer_mute/peer_camera/media_changed) via adapters do host → `send_update`.
- [x] C3: `window_command {open|close, "call"}` + push_events ao hook saem da ilha;
      `end_call` (on_close) via adapter.
- [x] C2: ilha emite `{:feature_summary, :call, %{type, duration, quality_label}}`; pai
      guarda `call_summary`; taskbar (badge `duration`) E a `p2p_connection_strip` leem
      dele (resumo ampliado p/ cobrir o que a strip mostra).
- [x] C1: device_fallback/error → `send_update(ChatIsland, system_message:)` (da ilha).
- [x] NÃO toquei na negociação single-offerer nem no signaling (backbone do host).
- [x] Removidos do pai os 9 assigns de mídia (+ `surface_peer_media`); pai mantém
      `stats`/`network_info_open` (janela Statistics) e a assinatura PubSub.
- [x] Teste de unidade: idle/connect-prompt/start-buttons + `surface_peer_media`
      (auto-join recvonly) via `update({:peer_media_changed, ...})`. Estados que chamam
      `Lobby.set_media` (call_started) ficam no E2E.

## Armadilhas cruzadas (verificadas contra o código)

- ⚠️ **C2 swallow (linha 228) — agravado aqui:** a strip da janela `conn` lê o resumo
  de `call` E o badge da taskbar lê `duration` (que muda a cada tick). Ambos via
  `send(self(), {:feature_summary, :call, ...})` (tupla). Exige
  `handle_info({:feature_summary, :call, ...})` explícito ACIMA da linha 228 — senão a
  strip E o badge congelam silenciosamente. Como o tick é por segundo, esse handler
  roda muito: mantenha-o barato (só guarda o resumo, não recomputa nada).
- ✅ Devices = `<select data-device-kind>` cru lido pelo hook (`media_panel.ex:246`);
  layout/preset = `phx-click` + `phx-value-*` string (`:187-230`). NENHUM trap de
  `select_item`/`JS.push(value:)`. Zero modal-in-modal.
- ⚠️ **`surface_peer_media` + negociação single-offerer** (memória `universal-lobby`,
  pontos 1 e 2): NÃO mover a lógica de offer/answer para a ilha — ela é do backbone do
  pai. A ilha só pede mídia via push_events; o cenário bidirecional (ambos ligam vídeo
  ao mesmo tempo, RTP real) é o teste que mais regride — rode-o.
- ⚠️ `send_update` assíncrono sob LiveViewTest → flush via `render(view)`; cobrir
  `surface_peer_media` via `update({...})` no teste de unidade (PubSub via adapter).

## Validação

- [x] Iniciar áudio → janela `call` abre (C3); upgrade para vídeo (E2E #6).
- [x] **Ambos ligam vídeo ao mesmo instante → vídeo bidirecional com RTP real**
      (`track.muted === false`) — E2E #13, passou limpo (sem flake nesta run).
- [x] Mute/camera local refletem no peer (broadcast da ilha); peer mute/camera refletem
      aqui (E2E #10 media controls).
- [x] `surface_peer_media`: peer liga mídia → call auto-join + janela abre (E2E #2 +
      unit auto-join).
- [x] Encerrar call (`end_call`) → janela fecha (C3), badge/strip limpam (C2)
      (E2E #3 + lobby_live_test).
- [x] device fallback/error → msg de sistema no chat (C1) (na ilha → ChatIsland).
- [x] Call + game + chat concorrentes (E2E #4); all-four-at-once (E2E #14).
- [x] `make ci` **9/9** (2026-06-30); `chat-lobby.spec.ts` **20/20** (media suite verde,
      incl. bidirectional RTP).

## Prompt de execução

Sessão dedicada. Leia OVERVIEW + playbook + os 3 constraints do `universal-lobby`
(signaling readiness, single-offerer, hook sempre montado). `surface_peer_media` é o
nó górdio — migre inteiro, teste o cenário bidirecional. NÃO mexa no backbone WebRTC.

## Progress Log

- 2026-06-30: Planejado. Não iniciado.
- 2026-06-30: `in_progress`. Escopo: criar
  `RetroHexChatWeb.App.LobbyLive.Components.MediaIsland` (dona de `call`/`call_layout`/
  `local_muted`/`local_camera_off`/`peer_muted`/`peer_camera_off`/`peer_media`/`devices`/
  `media_ready`), SEMPRE montada. Como o `LobbyMediaHook` faz `pushEvent` p/ a raiz (igual
  ao file), todos os eventos de mídia chegam ao host e são forwardados via adapters
  (`lobby_media_call_ended` explícito p/ resetar `stats` host-owned + genérica
  `"lobby_media_" <> _` + guarda p/ `start_call`/`end_call`/`set_call_layout`/
  `media_select_preset`) → `send_update(MediaIsland, action: {:media_event, name,
  params})`. A ilha é **self-contained**: chama `Lobby.set_media` e faz `broadcast`
  (lobby_peer_mute/camera) ela mesma (token/user_id passthrough), roda
  `surface_peer_media` inteiro, dispara os push_events ao hook + `window_command` (C3) e
  espelha `call_summary` (`type`/`duration`/`quality_label`) p/ badge E strip da janela
  `conn` (C2). `handle_info({:feature_summary, :call, summary})` ACIMA do catch-all.
  C1: device_fallback/error → ChatIsland. **NÃO toca** signaling/single-offerer (host).
  Host MANTÉM: assinatura PubSub + 3 adapters inbound (peer_mute/peer_camera/
  media_changed), `lobby_stats`→`stats`, `toggle_network_info`→`network_info_open`.
  Arquivos: `media_island.ex` (novo), `media_island_test.exs` (novo), `lobby_live.ex`,
  `universal_lobby.ex` (+attr user_id), `lobby_live.html.heex` (+user_id), 
  `lobby_live_test.exs`. Validação: `make ci` 9/9 + `chat-lobby.spec.ts` (media suite,
  incl. bidirectional-video RTP real).
- 2026-06-30: `complete`. A gigante migrou sem regressão. **Self-contained island:** a
  `MediaIsland` chama `Lobby.set_media` e faz `broadcast` (peer mute/camera) ela mesma
  (token/user_id passthrough), roda `surface_peer_media` inteiro, dispara push_events ao
  hook + `window_command` (C3) e espelha `call_summary` (type/duration/quality_label) p/
  badge + strip (C2). O host virou adapters finos (a hook empurra p/ a raiz, igual ao
  file): `lobby_media_call_ended` explícito (reset `stats`) + `"lobby_media_" <> _` +
  guarda das 4 UI events. **Armadilha resolvida:** o `@id` da ilha colidia com o
  `id="lobby-media"` do próprio `media_panel` (hook) → "Duplicate id" em runtime; renomeei
  p/ `lobby-media-island` (e o `live_component id=` casa com `MediaIsland.id()`). **NÃO
  toquei** signaling/single-offerer. **Validação real:** `make ci` **9/9**;
  `chat-lobby.spec.ts` **20/20** — incl. bidirectional-video RTP (#13) limpo nesta run,
  audio→video (#6), media controls (#10), auto-join (#2), all-four (#14). Unit MediaIsland
  5/5; lobby_live_test 21/21. Arquivos: `media_island.ex` (novo, ~290 ln),
  `media_island_test.exs` (novo), `lobby_live.ex` (encolheu ~140 ln), `universal_lobby.ex`
  (+attr user_id, -8 attrs media), `lobby_live.html.heex`, `lobby_live_test.exs`.
  **Série COMPLETA: as 4 ilhas extraídas.**
