# PM = P2P — progresso e aprendizados

> Diário de execução do plano `p2p-chat-integracao.md`. Atualizado a cada
> passo concluído. Decisões travadas D1–D8 e edge cases E1–E10 estão no plano
> — aqui só status, desvios e aprendizados.

## Status por fase

| Fase | Descrição | Status |
|---|---|---|
| F0 | Plano + decisões + verificação de código | ✅ CONCLUÍDA (2026-07-08) |
| F1 | Domínio: leave por usuário + monitors + grace, decline/cancel, `active_session_for_user`, timer, `p2p_system` | 🔨 EM ANDAMENTO |
| F2 | Espinha no ChatLive: `@p2p_session` state machine, adapters, card aceite/recusa, status bar, guard multi-aba | ⬜ |
| F3 | Janelas: `p2p-stats` → `p2p-files` → `p2p-call` → `p2p-games` | ⬜ |
| F4 | Absorção do PM: `p2p_system`, card vivo, glifo na tab, fix fallback card | ⬜ |
| F5 | Paridade + E2E reescrito + help topics | ⬜ |
| F6 | Remoção do standalone `/lobby` + redirect | ⬜ |

## F1 — passos

- [x] 1. Ler domínio completo (session_server, service, lobby, policy, queries, schema)
- [x] 2. Redesenho do leave: saída por usuário + `Process.monitor` do pid que deu join (via `from` do handle_call) + grace de rejoin (`:lobby_rejoin_grace_timeout`, default 30s) antes do terminal; evento novo `lobby_peer_disconnected`; disconnect reseta `webrtc_ready[role]` + `signaling_started` e `maybe_start_signaling` aceita status `connected` → rejoin re-sinaliza
- [x] 3. `decline_session/2` + `cancel_invite/2` (wrappers de `close_session_server`, reasons `"declined"`/`"invite_cancelled"`; Policy `can_decline?`/`can_cancel_invite?` — role + pending)
- [x] 4. `Queries.active_sessions_for_user/1` + fachada `Lobby.active_session_for_user/1`
- [x] 5. `record_activity/1` (reset dos timers pré-conexão; no-op fora do status `lobby`)
- [x] 6. `p2p_system` em `PrivateMessage.@type_values` (sem migração)
- [x] 7. Testes: session_server (grace/rejoin/segunda aba/re-sinalização/record_activity), service_test novo (decline/cancel/query), private_message
- [x] 8. `make ci` 9/9 (2026-07-08) + commit

**F1 CONCLUÍDA** (commit `3f38a244`).

## F2 — passos

- [x] 1. `chat_live/p2p_session_events.ex`: máquina `@p2p_session` (nil → invite_sent → joining → connecting → connected), adapters de sinalização portados do LobbyLive, aceite/recusa/cancela/encerra, troca A→B, re-hidratação no mount
- [x] 2. Anchor `#lobby-webrtc` no template (wrapper keyado por token p/ remount na troca; NÃO monta em :invite_sent)
- [x] 3. Card do PM: [Aceitar][Recusar] p/ o convidado (viewer == peer, status pending) + link standalone mantido (side-by-side)
- [x] 4. `P2PConfirmDialog` (end + switch)
- [x] 5. Zona P2P na `status_bar_app` (+ threading chat_shell/chat_app_header)
- [x] 6. `/p2p` com sessão ativa → confirm ANTES de enviar o PM (E2); cancelar desfaz a sessão pendente criada pelo comando
- [x] 7. Testes liveview (6, cobrindo invite/accept/decline/cancel/switch nos dois sentidos) + Playwright alvo `chat-lobby.spec.ts:9` verde (side-by-side validado)
- [x] 8. `make ci` 9/9 + commit

**F2 CONCLUÍDA** (commit `45465f53`).

## F3 — janelas (uma por vez)

- [x] **p2p-stats**: janela P2P Statistics (managed, gated na sessão) reusando
  `lobby_network_panel`; normalização de stats extraída para
  `RetroHexChatWeb.App.P2PStats` (compartilhada com o LobbyLive, não
  duplicada); menu **P2P** na menu bar (Statistics / End Session) + seção no
  start menu; clique na status bar foca as janelas P2P abertas (ou abre
  Statistics); `lobby_client_info` (whois) e `peer_online` portados;
  `detach_session` fecha as janelas p2p-*. CI 9/9.
- [x] **p2p-files**: a MESMA `FileIsland` do lobby montada no chat (reuso via
  flags, sem fork): ganhou `window_id` (dirige "file" no lobby, "p2p-files" no
  chat) e a notícia de conclusão desacoplada da ChatIsland — a ilha agora
  emite `{:p2p_feature_notice, :file, text}` e cada host roteia (LobbyLive →
  ChatIsland; ChatLive → system_event). Janela sempre montada enquanto
  joinado (constraint do FileTransferHook), X cancela via `on_close="ft_cancel"`;
  adapters `ft_*`/`file_transfer_ready` no host; `{:feature_summary, ...}`
  alimenta `file_summary`/`call_summary`/`game_summary` no `@p2p_session`
  (strip do Statistics + badges); menu "Send a File..." nos dois menus. CI 9/9.
- [x] **p2p-call**: a MESMA `MediaIsland` do lobby montada no chat (`window_id`
  + notícias `{:p2p_feature_notice, :call, ...}` + **token no envelope do
  broadcast interno** — sem isso o gate token-gated do ChatLive descartava
  `lobby_peer_mute`/`camera`). Janela sempre montada enquanto joinado (streams
  sobrevivem a hide/show), X encerra a chamada via `on_close="end_call"`;
  adapters `lobby_media_*`/`start_call`/`end_call`/layout/preset no host;
  pubsub `lobby_media_changed`/`peer_mute`/`peer_camera` → ilha (auto-join
  surface incluso); "Start Audio/Video Call" nos dois menus; encerrar chamada
  zera a telemetria do host. CI 9/9.
- [x] **p2p-games**: a MESMA `GameIsland` do lobby montada no chat (`window_id`
  + notícia de resultado `{:p2p_feature_notice, :game, ...}`). Server-managed
  (ilha monta só com a janela aberta; picker sempre fresco); X encerra o jogo
  para os dois via `on_close="end_game"`; propostas/status abrem a janela nos
  DOIS lados via `Windows.open_with` (send_update deferido — o mount da ilha
  managed não pode receber send_update no mesmo ciclo); handlers completos
  (propose/respond/end/result/error/dismiss/canvas_ready); "Play a Game..."
  nos dois menus. CI 9/9.

**F3 CONCLUÍDA** (commit `faeebabf`) — as 4 janelas P2P vivem no desktop do
chat, com as 3 ilhas do lobby reusadas (zero fork) e o standalone intacto.

## F4 — absorção do PM

- [x] Tipo `p2p_system` renderizado no PM (branch no MessageRow, source "P2P",
  `Messages.stream_type` estendido)
- [x] **Regra do escritor único implementada no contrato da notícia**: as
  ilhas emitem `{:p2p_feature_notice, feature, text, scope:/writer:}` —
  `:shared` + writer → o chat persiste como `p2p_system` (arquivo: receptor;
  jogo: host da partida); `:shared` + !writer → descarta (o PM chega via
  broadcast); `:local` (erros de mídia) → linha efêmera. LobbyLive ignora
  opts (ChatIsland como sempre).
- [x] Mensagens de ciclo de vida persistidas pelo ator: conectada (creator),
  recusada (decliner), cancelada (creator), encerrada (quem encerrou —
  inclusive na troca A→B); `finish_session` suprime a efêmera para reasons
  com escritor (`user_closed/declined/invite_cancelled/user_blocked`) e mantém
  para fins de domínio (expired/failed/peer_left).
- [x] **Card vivo**: `Chat.Queries.get_p2p_invite_between/3` +
  `PM.refresh_p2p_invite_card/3` re-enriquecem e re-inserem a row do card
  (mesmo dom id) quando a sessão muda (aceita → perde botões; terminal →
  card inerte) — só quando o PM do peer está na tela (load re-enriquece o resto).
- [x] Glifo de sessão na tab do PM (`p2p` attr no `irc_tab_item`, só quando
  `:connected`)
- [x] Fallback `p2p_invite_card` inerte ("session no longer available") —
  gap do apêndice fechado.
- [x] CI 9/9

**F4 CONCLUÍDA** (commit `69c3c0b3`).

## F5 — paridade + E2E + help

- [x] **Auditoria de paridade** vs inventário do plano §3.5: chat (PM ✓),
  chamada áudio/vídeo ✓, transferência ✓, 28 jogos ✓, estatísticas ✓,
  whois/diagrama ✓ — **gap fechado**: privacy mode (TURN-only) adicionado ao
  menu P2P (`p2p_toggle_privacy`, persiste em UserPreference, gated em
  `turn_configured`).
- [x] **Help (obrigatório)**: novo tópico "P2P Sessions in Chat"
  (`feature-p2p-in-chat` + página HEEx + embed no `HelpContent.P2P`);
  tópico `/p2p` reescrito (aceitar no card); "See also" cruzados com P2P Lobby.
- [x] **E2E in-chat**: `e2e/tests/chat-p2p.spec.ts` (3 testes): aceitar no
  card → **conexão WebRTC REAL estabelecida sem sair do /chat** (status bar
  "P2P: <peer>" nos dois lados) + glifo na tab + linha p2p_system persistida
  + encerrar com confirm; recusar; cancelar pendente. 3/3 verdes.
- [x] CI 9/9

**F5 CONCLUÍDA** (commit `bd760465`). Fora de paridade por decisão: layout/PiP
(recursos internos da MediaIsland, funcionam idem), suite standalone
`chat-lobby.spec.ts` continua cobrindo a página própria até a F6 (menos
:96/:200, quebra pré-existente de vídeo na main).

## F6 — remoção do standalone: **AGUARDANDO PRÉ-REQUISITOS** (recomendação)

A F6 (deletar LobbyLive/universal_lobby/rota + redirect) está pronta para
executar, MAS removê-la agora apagaria a suite `chat-lobby.spec.ts` — a única
cobertura E2E de MÍDIA (vídeo bidirecional com RTP real, upgrade de áudio,
device fallback) — enquanto:
1. **A quebra pré-existente de vídeo no E2E** (`:96`/`:200`, `enableVideoButton`
   nunca habilita; falha na main desde antes da F1) impede portar essa
   cobertura para o fluxo in-chat. Diagnóstico preliminar: a conexão E2E passa
   (`:9` verde) e o `waitUntilConnected` já assere o botão habilitado — a
   falha posterior no `sendVideo` sugere locator/strict-mode ou regressão de
   UI dos commits do space; precisa de sessão de trace Playwright dedicada.
2. Ordem recomendada: (a) consertar o E2E de vídeo → (b) portar os testes de
   mídia para `chat-p2p.spec.ts` → (c) executar a F6.

Checklist da F6 quando destravar: deletar `lobby_live.ex(.heex)`,
`chat_dispatch.ex`, `ChatIsland`+`chat_panel`, `universal_lobby.ex`,
`lobby_menu_bar/status_bar/terminal`, `LobbyCloseWindowHook`, rota →
redirect `/lobby/:token` → `/chat` (re-hidratação assume), e2e
`chat-lobby.spec.ts`+`lobbyFlows`+`LobbyPage`, `lobby_live_test.exs`;
**MANTER**: Media/File/Game islands + panels + network panel (o chat usa),
domínio `Lobby`, `RetroHexChat.P2P`, hooks WebRTC; renomear o namespace
`App.LobbyLive.Components.*` das ilhas sobreviventes; tópico de help
"P2P Lobby" reescrito/removido; card sem link standalone.

### Aprendizados F3 (parciais)

- `dispatch_to_hooks` usa a lista `@event_hook_fns` — SEPARADA do
  `attach_all_hooks`; um módulo de eventos novo precisa entrar NAS DUAS listas
  ou os eventos de menu (toolbar_action) nunca chegam nele.
- Dois feature tests fixam a menu bar por posição/lista literal
  (`window_display_edit_menu`, `server_administration` Help em `Enum.at(4)`) —
  menu novo desloca o Help; atualizados para P2P entre Tools e Help.

## Aprendizados F2

- **ChatLive já força UMA instância por usuário** (takeover `:force_disconnect`
  no mount) — o guard multi-aba vira: takeover mata o LV antigo → grace F1
  segura a sessão → re-hidratação no novo LV reconecta. `:already_joined` fica
  como fallback da race.
- **Side-by-side exigiu o creator NÃO joinar no convite**: se o ChatLive
  joinasse ao enviar o convite, abrir o standalone devolveria :already_joined
  e a página própria ficaria inutilizável. Modelo: creator = subscribe-only em
  :invite_sent; joina quando o peer entra (lobby_peer_joined); se o join
  devolver :already_joined (o próprio standalone assumiu), o chat se desanexa
  em silêncio e deixa aquela superfície dirigir.
- **O anchor WebRTC não pode montar em :invite_sent** — montaria um segundo
  RTCPeerConnection do mesmo usuário se ele fosse para o standalone (dois hooks
  respondendo ao mesmo lobby_start_offer = sinalização em guerra).
- **Race de troca A→B resolvida com token no envelope PubSub**: o
  lobby_session_closed da sessão antiga já estava na mailbox quando a nova
  entrava; sem `%{token:}` no envelope o handler derrubava a sessão NOVA.
  Extra key não quebra os matches existentes do LobbyLive.
- **E2E `chat-lobby.spec.ts` estava quebrado na main ANTES da F1** (verificado
  via stash em 77614a13): o helper procurava o card fallback
  (`p2p-invite-card`/"Join lobby") mas o card rico renderiza (`session-card`/
  "Join") — corrigi os locators (:9 voltou a passar). **:96 e :200 (vídeo)
  continuam vermelhos na main limpa — quebra pré-existente NÃO relacionada à
  migração** (enableVideoButton nunca aparece); investigar à parte.
- Componente com key list explícita (MessageViewport) precisa do default do
  assign novo também no `mount` — `render_component` dos testes unitários não
  passa pelo merge do update.

## Validações

| Data | O quê | Resultado |
|---|---|---|
| 2026-07-08 | testes alvo domínio+web (lobby, private_message, lobby_live, session_card) | 64 testes, 0 falhas |
| 2026-07-08 | `make ci` fechamento F1 | 9/9 ✅ |

## Aprendizados / desvios do plano

- **Sessão conectada NÃO tem timeout de inatividade** — os timers warning/expiry
  só existem no status `lobby` (pré-conexão) e são cancelados no `connected`.
  A preocupação do plano §7.2 sobre "base do timer" era menor do que parecia:
  `record_activity/1` cobre só a janela pré-conexão.
- **Detecção de segunda aba tem uma race benigna no refresh**: se o LV antigo
  ainda estiver vivo quando o novo dá join (reconexão muito rápida), o join
  devolve `:already_joined` indevidamente. Na prática o socket velho morre
  antes do novo conectar; se aparecer em campo, F2 adiciona um retry curto no
  host. Standalone mostra card "already open in another tab".
- **`decline`/`cancel` não precisaram de API nova no SessionServer** — só
  Policy + wrappers no Service com `closed_reason` novo; o `do_close` existente
  já notifica os dois lados (`lobby_session_closed` + `lobby_session_ended`).
- O monitor usa o pid do `from` do `handle_call` — zero mudança de assinatura
  no `join/2`; o Registry é local (single-node), então `Process.alive?` é
  seguro na checagem de takeover.
