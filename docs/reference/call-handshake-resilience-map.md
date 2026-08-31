# P2P e conferencia - mapa de handshake e resiliencia

Data: 2026-07-28, revisado em 2026-08-31 (superficies com endereco proprio)

Este documento mapeia como chamadas P2P e chamadas de conferencia estao
implementadas hoje, quais mecanismos de resiliencia ja existem e onde ainda ha
risco de usuario ficar preso em fluxo quebrado. Ele complementa
`docs/reference/media-session-p2p-conference-current.md`, que continua sendo a
fonte curta de produto sobre superficies e janelas.

As regras duraveis que sairam deste mapa — `disconnected` nao e `failed`, epoch
de sinalizacao, renegociar versus rejoin, `PeerServer` monitorando o channel —
vivem em `docs/AGENT-GUIDE.md` secao 8.5. Aqui fica o inventario tecnico: quais
arquivos participam de cada caminho e o que os testes ja cobrem.

## Sumario executivo

- P2P e uma sessao WebRTC browser-browser. O convite, a autorizacao e o estado
  de sessao sao do backend Phoenix/LiveView; **a sinalizacao nao passa mais pelo
  socket do LiveView** — ela e um Phoenix Channel cru, `p2p:<session_token>`,
  autenticado por `Lobby.JoinToken`. A midia, arquivos e jogos trafegam no mesmo
  `RTCPeerConnection` do browser.
- Conferencia e uma sala SFU embutida no servidor. O browser negocia via
  Phoenix Channel com um `PeerServer` ExWebRTC por participante; o `RoomServer`
  coordena participantes, tracks, renegociacao e fanout RTP.
- O P2P tem uma estrategia correta de "single-offerer": so o iniciador cria
  offers, e o outro peer pede renegociacao via `lobby_renegotiate`. Isso evita
  glare na maior parte dos fluxos.
- A conferencia tambem tem um unico offerer efetivo: o servidor/SFU envia
  `group_call_offer` e o browser responde com `group_call_answer`.
- As camadas principais de resiliencia agora cobrem readiness antes de
  sinalizar, buffers de ICE/SDP, timeouts, backoff, retries, grace window de
  rejoin, TURN opcional, stats, validacao de payloads, epoch/offer_id para
  descartar sinalizacao obsoleta, feedback imediato em `disconnected` e UI de
  erro com saida manual funcional.
- Nesta rodada foram fechados os riscos mais graves mapeados: retry automatico
  do answerer P2P, erro SDP/ICE sem feedback, rejoin de conferencia quando o
  `PeerServer` nao esta pronto, answer obsoleta por offer antigo e rehydrate
  P2P bloqueado por janela stale apos reconnect/deploy.
- A suite E2E destrutiva agora cobre queda curta de rede/LiveView, botoes
  `End/Leave` em erro, reload durante a offer inicial P2P/SFU e `PeerServer`
  encerrado antes de `request_offer` da conferencia, alem de retries manuais
  simultaneos P2P.
- Conferencia agora trata fechamento inesperado do raw channel como
  `disconnected`, nao como saida voluntaria, e reidrata o participante
  nao-terminal apos mount/rejoin de canal.
- O endpoint `GET /api/calls/healthz` agora expoe readiness operacional de
  backend para P2P signaling, TURN e conferencia/SFU, sem depender da UI e sem
  expor segredos ou payloads WebRTC.
- Riscos remanescentes sao principalmente de robustez operacional: replay
  duravel de sinalizacao apos perda de mensagem server-client, alertas/dashboards
  externos sobre as metricas e o healthcheck, helper visual unico em todos os
  pontos de midia e cenarios E2E destrutivos mais agressivos de rede
  `disconnected` em laboratorio de rede real.

## O que mudou com as superficies com endereco proprio

Revisao de 2026-08-31, depois das ondas 0 a 6. As regras duraveis disso vivem em
[`guide/surfaces.md`](../guide/surfaces.md) (secao 19) e em
[`guide/webrtc-p2p.md`](../guide/webrtc-p2p.md) 8.1 e 8.5; aqui fica so o que
muda a leitura deste inventario:

- **A sinalizacao P2P virou channel cru** (`p2p:<session_token>`), como a
  conferencia e o space ja eram. Nenhuma das tres passa pelo socket do LiveView.
  O que ficou no LiveView e o que carrega politica de transporte — `ice_servers`,
  `role`, `turn_only` — e o ciclo de vida da sessao.
- **A sessao tem endereco proprio** (`/p2p/:token`) e o chat renderiza o mesmo
  modulo numa janela. Fechar a aba do chat nao encerra a chamada, e a filiacao a
  canal em que a conferencia se apoia so e liberada quando a **ultima**
  superficie da pessoa cai (`RetroHexChat.Surfaces`).
- **Uma sessao so fica viva numa janela por vez.** Abrir a mesma sessao em outra
  aba a **move** para la, com o mesmo reset que uma queda de socket provoca; a
  janela deslocada avisa e oferece traze-la de volta. Isso apagou o caminho de
  `reattach_pending` inteiro, que era o mais fragil do produto.
- **A maquina de estados ganhou `open`**: uma sessao pode nascer sem par, como
  link de partida, e a cadeira e tomada por uma escrita condicional.
- **O epoch de sinalizacao e por pagina**, e uma aba nova comeca do um. Um
  `offer` com `connection_reset: true` atravessa a guarda de staleness — sem
  isso, toda oferta de uma pagina recem-aberta lia como obsoleta para sempre.

## Referencias externas usadas

- MDN `RTCPeerConnection.restartIce()`:
  https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/restartIce
- MDN perfect negotiation:
  https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Perfect_negotiation
- MDN `iceConnectionState`:
  https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/iceConnectionState
- MDN WebRTC protocols, ICE/STUN/TURN/SFU:
  https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Protocols
- WebRTC.org TURN server:
  https://webrtc.org/getting-started/turn-server
- WebRTC samples Trickle ICE:
  https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
- Phoenix Channels reliability:
  https://phoenix.hexdocs.pm/channels.html
- Phoenix JavaScript client:
  https://phoenix.hexdocs.pm/js/
- ExWebRTC PeerConnection:
  https://ex-webrtc.hexdocs.pm/ExWebRTC.PeerConnection.html
- ExWebRTC negotiation guide:
  https://ex-webrtc.hexdocs.pm/negotiation.html
- Telemetry.Metrics:
  https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.html
- Phoenix Telemetry:
  https://hexdocs.pm/phoenix/telemetry.html
- Phoenix LiveDashboard metrics:
  https://hexdocs.pm/phoenix_live_dashboard/metrics.html
- Playwright offline em `BrowserContext`:
  https://playwright.dev/docs/api/class-browsercontext#browser-context-set-offline
- Playwright actionability:
  https://playwright.dev/docs/actionability
- Playwright WebSocket/WebSocketRoute:
  https://playwright.dev/docs/api/class-websocketroute
- Phoenix LiveView mount/reconnect params:
  https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html

Principios retirados dessas referencias:

- `disconnected` pode ser transitorio e voltar para `connected`; nao deve
  derrubar a chamada imediatamente.
- `getStats()` fornece contadores cumulativos de transporte, RTP e data channel;
  comparar snapshots permite diferenciar `disconnected` com trafego real de
  perda efetiva antes de escalar recovery.
- `failed` indica que ICE nao encontrou pares compativeis suficientes; o app
  precisa disparar ICE restart ou reconstruir a conexao.
- `restartIce()` so se completa via novo ciclo offer/answer; a aplicacao ainda
  precisa entregar a sinalizacao de forma robusta.
- WebRTC nao define transporte de sinalizacao. Phoenix entrega reconexao de
  socket/channel, mas mensagens servidor-cliente sao at-most-once; mensagens
  criticas de sinalizacao precisam ser idempotentes e reemitidas por estado
  proprio da aplicacao quando necessario.
- Em conferencia multiparty, SFU e o desenho esperado para evitar fanout N:N
  direto entre browsers.
- Teste E2E de fault injection deve usar offline/reconnect real do contexto e
  validar botoes visiveis/habilitados conforme as regras de actionability, para
  evitar falsos positivos em wrappers invisiveis ou DOM instavel.
- Healthcheck backend de TURN nao prova conectividade relay fim-a-fim sozinho:
  candidate `relay` exige ICE gathering de um cliente WebRTC. O endpoint atual
  cobre pre-condicoes server-side: configuracao, supervisao, listeners, ranges
  e SFU/registries.

## Inventario principal

### P2P

Frontend:

- `apps/retro_hex_chat_web/assets/js/lib/p2p/webrtc.js`
- `apps/retro_hex_chat_web/assets/js/lib/p2p/media.js`
- `apps/retro_hex_chat_web/assets/js/lib/p2p/rtc_media_hook_factory.js`
- `apps/retro_hex_chat_web/assets/js/lib/p2p/signaling_channel.js`
- `apps/retro_hex_chat_web/assets/js/hooks/lobby/lobby_webrtc_hook.js`
- `apps/retro_hex_chat_web/assets/js/hooks/lobby/lobby_media_hook.js`

Backend, channel e LiveView:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/channels/p2p_channel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/p2p_live.ex` — a sessao,
  montada em `/p2p/:token`, em `/play/:game/:token` e dentro da janela do chat
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_live/events.ex` — o
  adaptador de eventos da sessao (era `chat_live/p2p_session_events.ex`)
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_read_model.ex` —
  o que o chat sabe de uma sessao em que o leitor nao esta
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex` —
  o que sobrou no chat: convite, janela e troca de sessao
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_media_island.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_session_console.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/service.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/session_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/join_token.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/policy.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/schema/session.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/signaling_rate_limit.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/signaling_rate_limit/ets.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/*`

### Conferencia

Frontend:

- `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_prejoin_hook.js`
- `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js`

Backend e LiveView:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/channels/group_call_channel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/group_call_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/group_call/*`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/room_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/peer_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/rtp_forwarder.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/config.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/join_token.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/rate_limiter.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/policy.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/room.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/participant.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/track.ex`

## P2P - arquitetura atual

### Modelo

P2P usa um unico `RTCPeerConnection` persistente por sessao. Esse PC carrega:

- audio/video;
- `RTCDataChannel` `filetransfer`;
- `RTCDataChannel` `gamedata`;
- stats por faceta, derivadas do mesmo PC.

O backend nao ve midia nem dados de arquivo/jogo. Ele ve:

- criacao e encerramento da sessao;
- politicas de quem pode convidar/aceitar;
- presenca dos dois LiveViews;
- readiness dos hooks WebRTC;
- relay de mensagens SDP/ICE via PubSub;
- estado visual e mensagens de sistema persistidas.

### Estados duraveis e estados de UI

Persistencia em `Lobby.Schema.Session`:

- `pending`
- `lobby`
- `connected`
- `closed`
- `expired`
- `failed`

Estado LiveView aproximado:

- `nil`
- `:invite_sent`
- `:joining`
- `:connecting`
- `:connected`
- `nil`

Observacao: `:connecting` e estado de UI/assign; nao existe como status
persistido. O status persistido `lobby` cobre o intervalo entre aceite e
conexao WebRTC.

### Handshake P2P feliz

1. Criador inicia P2P pelo PM ou comando.
2. `Lobby.Service` cria sessao `pending` e o convite (a PM) sai na hora — criar
   a sessao E convidar. O criador cai na sala de partida do `App.P2PLive`, em
   `:invite_sent`; o anchor WebRTC ainda nao monta.
3. Peer aceita o convite pelo PM/header; isso e o consentimento, e abre a mesma
   sala de partida — o `P2PLive` toma o assento no mount.
4. `Lobby.SessionServer` marca os dois lados como joined e transiciona para
   `lobby`.
5. Cada lado escolhe dispositivos e aperta `[Pronto]`. So entao o anchor
   `#lobby-webrtc` monta, carregando o `session_token` e o `Lobby.JoinToken`
   que o hook usa para entrar no canal `p2p:<session_token>`. A resposta do
   join ja traz o replay: entrar no canal e, por si so, dizer "estou ouvindo e
   posso ter perdido alguma coisa".
6. Cada hook envia `lobby_webrtc_ready` — este continua indo para o LiveView,
   porque e a metade "o hook montou" do que `[Pronto]` promete.
7. `Lobby.SessionServer.maybe_start_signaling/1` so inicia sinalizacao quando:
   status e `lobby` ou `connected`, a sinalizacao ainda nao iniciou e os dois
   lados estao `webrtc_ready`.
8. `lobby_start_signaling` chega nos dois. O peer ja recebe `lobby_start_answer`
   e monta o PC (o primeiro offer e descartado se ele nao estiver escutando),
   mas continua na sala. O criador ganha `[Iniciar]` habilitado.
9. O criador aperta `[Iniciar]`: sai `lobby_start_offer` para ele e o broadcast
   `lobby_session_start` tira os dois da sala.
10. O iniciador cria PC, data channels e offer.
11. Offer viaja pelo evento `lobby_signal` **no canal** `p2p:<session_token>`;
    o `P2PChannel` valida (`Calls.SignalValidation`), aplica rate limit,
    registra para replay e retransmite via PubSub `lobby:<token>` — o canal do
    outro lado empurra para o browser dele.
12. Answerer aplica remote offer, drena ICE pendente, cria answer e envia
    `lobby_signal` pelo mesmo canal.
13. Initiator aplica answer, drena ICE pendente e termina negociacao.
14. ICE candidates sao trocados; candidates que chegam cedo ficam em
    `pendingIceCandidates` ate haver `remoteDescription`.
15. Quando `connectionState` vira `connected`, cada hook envia
    `lobby_connected` (para o LiveView: e ciclo de vida de sessao, nao fio);
    LiveView transiciona sessao para `connected`, abre
    console e dispara `lobby_media_pc_ready`.
16. `LobbyMediaHook` drena comandos pendentes e auto-inicia midia conforme
    `media_mode` escolhido no setup.

### Negociacao P2P

O hook `LobbyWebRTCHook` usa modelo single-offerer:

- criador/iniciador e o unico peer que envia offers;
- answerer nunca cria offer diretamente;
- answerer que adiciona tracks chama `lobby_renegotiate`;
- iniciador recebe `lobby_renegotiate`, cria transceivers recvonly se necessario
  e envia novo offer;
- data channels sao criados cedo pelo iniciador para evitar uma renegociacao
  extra posterior.

Essa escolha e coerente com a recomendacao de evitar glare, mas implica uma
obrigacao: qualquer recuperacao iniciada pelo answerer precisa notificar o
iniciador para que ele gere nova oferta.

### Midia P2P

`LobbyMediaHook` e criado por `createRtcMediaHook`. Ele e responsavel por:

- capturar camera/microfone;
- entrar receive-only sem capturar midia;
- anexar stream local/remoto aos elementos;
- aplicar mute/camera off;
- trocar device;
- screen share por `replaceTrack`/restauracao;
- publicar `lobby_media_call_started`, `lobby_media_call_ended`,
  `lobby_media_devices`, `lobby_media_quality`, `lobby_media_fallback`;
- republish de tracks locais quando o PC e substituido;
- watchdog de video remoto travado.

`P2PMediaIsland` e o ponto LiveView stateful que:

- mantem estado local de chamada;
- chama `Lobby.set_media`;
- recebe e propaga estado de peer;
- surfaceia peer media automaticamente quando o outro lado inicia;
- encerra receive-only quando o peer para toda midia;
- sincroniza console, status bar e resumo.

`media.js` centraliza:

- constraints estaveis de audio/video/screen;
- classificacao de erro de permissao/dispositivo;
- perfis de bitrate/framerate;
- codec preference H264 > VP8 e Opus;
- stats derivadas por faceta;
- helper defensivo `attachMediaStream`.

### Resiliencia P2P ja implementada

- Setup antes de montar WebRTC evita sinalizacao antes de consentimento.
- Gate de readiness nos dois hooks evita perda do primeiro offer.
- PubSub por `lobby:<token>` com filtro de token obsoleto no LiveView evita
  aplicar evento de sessao antiga.
- P2P signaling tem rate limiter por usuario.
- Offer recebido antes do PC e bufferizado no answerer.
- ICE candidate recebido antes de remote description e bufferizado.
- `connectionState` e `iceConnectionState` sao observados; `disconnected`
  entra em grace period e `failed` inicia recovery imediato.
- Ao entrar em `connection_disconnected` ou `ice_disconnected`, o hook publica
  `lobby_recovery_pending`; a UI mostra feedback de reconnecting durante o
  grace period, sem disparar restart antes da decisao por stats.
- Durante `disconnected`, o hook compara snapshots de `getStats()` antes/depois
  da grace period. Se bytes/pacotes/mensagens ainda avancam, adia o retry por
  limite pequeno; quando param de avancar, o recovery normal dispara.
- Retry automatico limitado a 3 tentativas com backoff 2s, 4s, 8s.
- Retry automatico iniciado pelo answerer envia `lobby_renegotiate` com
  `recover`, `epoch`, `attempt` e `connection_reset`; o iniciador gera nova
  oferta em vez de deixar o answerer esperando.
- `lobby_signal` carrega `epoch`, `offer_id` e `connection_reset`; SDP/ICE de
  epoch ou offer antigos sao descartados.
- `SessionServer` guarda snapshot em memoria do ultimo SDP, dos ultimos ICE
  candidates por papel e do ultimo `lobby_renegotiate`; o hook pode pedir
  `lobby_signal_replay` no canal quando startup/reconnect nao recebeu uma
  mensagem critica — e o proprio join do canal ja devolve o replay, entao um
  rejoin automatico do Phoenix depois de queda de socket recupera sozinho.
- Replay P2P e idempotente no browser: offers/answers/candidates ja aplicados
  sao ignorados por `offer_id`, SDP ou chave de ICE candidate.
- Painel de stats P2P mostra diagnostico de recovery e handshake:
  state, reason, trigger, attempt, signaling epoch e offer id corrente.
- O answerer reenvia `lobby_renegotiate` com backoff curto ate receber nova
  offer; se nenhuma offer chega apos o limite, entra no recovery coordenado em
  vez de esperar indefinidamente.
- Retry manual (`p2p_retry_connection`) broadcasta restart para ambos os peers.
- Todo `lobby_restart` carrega ICE servers frescos, role e `turn_only`, para o
  hook reconstruir o PC com a policy atual.
- Watchdog de video remoto travado tenta primeiro renegociacao/ICE restart e
  depois escala para restart coordenado.
- Watchdog tambem cobre o caso "video remoto esperado e nenhuma track chegou",
  usando o evento `lobby_media_peer_media`.
- `SessionServer` tem grace de rejoin de LiveView por 30s, para refresh ou
  reconnect curto.
- Uma segunda janela da mesma pessoa **assume** a sessao:
  `Lobby.join_session/3` com `takeover: true`, que o `SessionServer` trata como
  desconexao seguida de join — assento liberado, prontidao daquele lado zerada,
  replay apagado e par avisado. E o mesmo portao que reconstroi a midia depois
  de uma queda de socket que reconstroi aqui. A janela deslocada recebe
  `{:lobby_slot_taken, token}`, para de renderizar o anchor (o hook e destruido)
  e oferece trazer a sessao de volta.
- `SessionServer` fecha/falha por timeout de lobby/connecting, evitando sessao
  pendurada indefinidamente antes da conexao.
- Rehydrate ao montar LiveView reconecta usuario a sessao ativa.
- TURN embutido pode gerar credenciais efemeras; quando `turn_only` esta ativo
  o frontend usa `iceTransportPolicy: "relay"`.
- Validacao de SDP/ICE tem limite de tamanho, shape minimo e preserva apenas
  metadados de recovery aceitos.
- Erros de criacao/aplicacao de SDP e ICE no hook entram no mesmo ciclo de
  recovery/falha, sem depender apenas de `console.warn`.
- Falhas repetidas de `addIceCandidate` no browser sao agregadas por ciclo de
  conexao; erro isolado/stale e tolerado, mas tres falhas seguidas disparam
  recovery coordenado.
- Falha terminal e idempotente: eventos repetidos com a mesma reason nao
  empilham mensagens infinitas nem desmontam a superficie de midia.
- `P2PSessionConsole` mantem o `LobbyMediaHook` montado quando a sessao base
  esta `:connected`, mesmo durante recovery `:reconnecting`/`:failed`.
- O banner de recovery sempre oferece Retry quando manualmente recuperavel e
  End pelo mesmo fluxo de confirmacao usado pelo restante da sessao.
- Fallback de camera no `devicechange` agora espelha o fallback de microfone.
- Alternar privacy relay em sessao viva dispara restart coordenado imediato; a
  conexao nao fica usando policy antiga ate o proximo erro/retry.

### Riscos P2P tratados nesta rodada

- Retry automatico do answerer inerte: resolvido com renegociacao recover
  enviada ao iniciador e metadados de epoch/attempt.
- SDP/ICE antigo aplicado em PC novo: resolvido com descarte por
  `signalingEpoch`/`offer_id`.
- Payload SDP/ICE sem limite: resolvido em `P2P.validate_signal/1` e no relay
  LiveView.
- Falhas repetidas lotando o transcript: resolvido com `_notifyFailed/2`
  idempotente no hook e deduplicacao de `lobby_failed` no LiveView.
- Reconnect/deploy caindo em "already active in another window": resolvido com
  takeover — a janela mais recente assume o assento e a anterior mostra o
  caminho de volta. O caminho antigo (`reattach_pending` + backoff) deixou de
  existir junto com o motivo dele.
- Recovery desmontando a propria midia: resolvido mantendo o hook montado
  enquanto a sessao base segue conectada.
- Falha repetida de ICE candidate ficando invisivel no console: resolvido com
  agregacao no hook e entrada no mesmo ciclo de retry/falha.
- Perda transitoria de `offer`/`answer`/ICE/`lobby_renegotiate` no transporte:
  resolvida com snapshot/replay em memoria no `SessionServer` e dedupe no hook.
  O fio deixou de ser o socket do LiveView (canal `p2p:<session_token>`), entao
  um reload da pagina nao leva mais a negociacao junto.

### Riscos P2P remanescentes

- Replay de sinalizacao P2P e propositalmente em memoria. Se o BEAM/processo de
  sessao reinicia, o sistema nao tenta reaplicar SDP/ICE antigo; uma sessao
  `connected` sem snapshot dispara restart limpo de WebRTC com
  `reason: "signaling_snapshot_lost"`. Ainda falta historico duravel apenas
  para auditoria pos-incidente.
- Modo relay-only depende da disponibilidade operacional do TURN. A UI nao fica
  presa em connecting infinito; recovery/falha agora entra em telemetria
  agregada, mas ainda falta alerta especifico de outage TURN.
- O watchdog visual P2P foi ampliado, mas ainda nao ha helper unico compartilhado
  por P2P, prejoin e conferencia.

## Conferencia - arquitetura atual

### Modelo

Conferencia e uma chamada por canal com SFU no servidor:

- LiveView abre prejoin e cria/entra em uma room.
- Browser abre Phoenix Socket proprio para `/socket`.
- Browser entra no topic `group_call:<room_token>` usando join token assinado.
- `GroupCallChannel` autoriza, aplica rate limit e delega para
  `RetroHexChat.GroupCall`.
- `RoomServer` e o processo de autoridade da sala.
- `PeerServer` e o endpoint WebRTC ExWebRTC de cada participante.
- `RTPForwarder` reescreve e encaminha RTP de publishers para subscribers.

### Estados duraveis

Room (`GroupCall.Schema.Room`):

- `pending`
- `open`
- `active`
- `closing`
- `closed`
- `expired`
- `failed`

Participant (`GroupCall.Schema.Participant`):

- `invited`
- `joining`
- `connected`
- `reconnecting`
- `disconnected`
- `left`
- `kicked`
- `failed`

Track (`GroupCall.Schema.Track`):

- `announced`
- `active`
- `muted`
- `ended`
- `failed`

### Handshake conferencia feliz

1. Usuario identificado abre chamada no canal.
2. LiveView abre prejoin (`GroupCallPreJoinHook`) e carrega preferencias.
3. Usuario confirma join.
4. LiveView chama `GroupCall.create_channel_call` ou pega room ativa.
5. LiveView assina join token e monta `GroupCallWebRTCHook`.
6. Hook cria `Phoenix.Socket("/socket")` e entra em
   `group_call:<room_token>`.
7. `GroupCallChannel.join/3` verifica join token, room e canal.
8. Hook envia `group_call_join` com `client_info` e `media_constraints`.
9. `RoomServer.join_call` valida politica/capacidade e cria ou reconecta
   participante.
10. `RoomServer` cria `PeerServer` pendente, monitora pid e agenda
    `ready_timeout`.
11. `PeerServer` inicia ExWebRTC `PeerConnection`, cria transceivers recvonly
    para receber audio/video do browser e sendonly para peers existentes.
12. `PeerServer` envia `group_call_offer` para o channel pid.
13. Browser processa offer em fila serializada:
    - garante PC browser;
    - aplica remote offer;
    - captura midia local se audio/video estao habilitados;
    - adiciona tracks locais;
    - drena candidates pendentes;
    - cria answer;
    - envia `group_call_answer`.
14. `PeerServer` aplica answer, drena candidates remotos e assina tracks
    pendentes.
15. ICE conecta; `PeerServer` recebe estado `:connected` e chama
    `RoomServer.mark_ready`.
16. `RoomServer` move participante de pending para participants, marca status
    `connected`, cancela ready timeout e broadcasta join.
17. Quando um participante publica track, `RoomServer.track_added` persiste ou
    atualiza track e avisa os demais.
18. Para participantes ja conectados, `RoomServer` envia `peer_added` ao
    `PeerServer`; ele adiciona transceivers de saida e manda novo offer com ICE
    restart quando necessario.
19. RTP inbound no `PeerServer` e encaminhado a subscribers por
    `RTPForwarder`.

### Sinalizacao conferencia

Eventos channel principais:

- `group_call_join`
- `group_call_answer`
- `group_call_ice_candidate`
- `group_call_request_offer`
- `group_call_media_state`
- `group_call_screen_share_state`
- `group_call_reaction`
- `group_call_leave`

Rate limit:

- join tem rate limit proprio;
- answer, ICE, request_offer, media_state e screen_share_state usam
  `check_signal_rate`;
- reaction nao aparece no mesmo rate limiter de sinalizacao.

### Resiliencia conferencia ja implementada

- Join token assinado amarra browser a sala/canal.
- Phoenix Channel tem reconnect/backoff automatico.
- Channel join valida room ativa e token.
- Browser enfileira offers, evitando processar dois offers concorrentes.
- Browser ignora offer identico ja respondido.
- Browser bufferiza ICE candidate ate remote description.
- `PeerServer` bufferiza candidate remoto enquanto esta em
  `:have_local_offer`.
- Hook observa `iceConnectionState`; `checking` publica recovery conectando,
  `disconnected` agenda recovery e `failed` aciona retry imediato.
- Antes do pedido automatico de fresh offer em `disconnected`, o hook compara
  snapshots de `getStats()` e adia o retry se ainda houver atividade de
  transporte, RTP ou data channel, com limite pequeno.
- `PeerServer.request_offer` reenvia offer pendente ou cria offer com
  `ice_restart?: true`.
- Hook agenda watchdog apos `group_call_joined`; se a offer inicial nao chega,
  publica recovery `offer_not_received` e pede `group_call_request_offer` em vez
  de deixar a UI presa aguardando SDP.
- `group_call_request_offer` retorna erro estruturado `rejoin_required` quando
  o `PeerServer` nao esta pronto; o browser fecha PC local, limpa streams
  antigos e executa `group_call_join` novamente no mesmo channel.
- `PeerServer` usa `offer_id` por oferta; browser ecoa na answer e answers
  obsoletas sao ignoradas.
- Falha ao aplicar answer ou ICE candidate no `PeerServer` envia
  `group_call_error` ao browser em vez de ficar apenas em log.
- Falhas repetidas de `addIceCandidate` no browser sao agregadas por ciclo; erro
  isolado/stale e tolerado, mas tres falhas seguidas acionam recovery da
  conferencia.
- `RoomServer` tem `ready_timeout_ms` para participante que nao conectou.
- `RoomServer` tem `reconnect_timeout_ms` para participante desconectado.
- `RoomServer` tem `peerless_timeout_ms` para fechar sala vazia.
- `RoomServer` aceita reconexao por nickname normalizado quando participante
  esta `disconnected`.
- Peer add/remove durante offer pendente vai para `pending_peers` ate answer.
- `RTPForwarder` tem munger/cache para reorder, gaps e duplicatas.
- Testes BEAM exercitam fanout RTP, late join, leave/rejoin, audio-only,
  screen share e ICE restart.
- Hook reporta stats browser e qualidade por participante.
- Painel de stats da conferencia mostra diagnostico de recovery e handshake:
  state, reason, trigger, attempt, proximo retry, offer id e rejoin epoch.
- UI tem estado recoverable para warning de midia e estado actionable para
  falha de conexao.
- `GroupCallChannel` valida tamanho/shape de SDP, candidate e `offer_id`.
- Audio/video podem ser capturados on-demand quando o usuario liga midia depois
  de entrar receive-only ou depois de falha inicial.
- O rate limit de reacoes fica no contexto `GroupCall.send_reaction/4`; o
  channel preserva esse contrato sem duplicar bloqueio.

### Riscos conferencia tratados nesta rodada

- Browser repetindo `request_offer` contra `PeerServer` morto: resolvido com
  `rejoin_required` e rejoin completo no hook.
- Link entre `PeerServer` e channel derrubando a sinalizacao: resolvido trocando
  link por monitor do channel pid.
- Answer obsoleta aplicada em oferta nova: resolvido com `offer_id`.
- Falha de answer/candidate invisivel ao browser: resolvido com
  `group_call_error`.
- Falha repetida de ICE candidate no browser ficando apenas em `console.warn`:
  resolvido com agregacao local e recovery por `ice_candidate_failed`.
- SDP/ICE sem limite no channel: resolvido com validacao de shape/tamanho.
- Usuario receive-only por falha inicial sem caminho para publicar depois:
  resolvido com captura on-demand e republish de tracks.
- Offer inicial server-client perdida: resolvido com watchdog no hook que pede
  fresh offer e falha com retry manual se a offer nao chegar.

### Riscos conferencia remanescentes

- Sinalizacao server-client segue at-most-once. `offer_id` torna answers
  idempotentes e `group_call_request_offer` recupera offers perdidas enquanto o
  `PeerServer` esta vivo, mas ainda falta snapshot duravel de sala para
  auditoria apos restart completo.
- Tile remoto agora usa `attachMediaStream` e dispara recovery quando a track
  esta live mas o elemento de video nao apresenta frames. Esse evento agora
  entra em telemetria agregada por `reason: "remote_video_stalled"`.
- Falta transformar os novos counters de recovery/erro em alertas operacionais
  e dashboards focados em incidentes.

## Testes existentes

### P2P

Unitarios JS:

- `webrtc.js`: criacao de PC, TURN relay policy, offer/answer, ICE, close,
  callbacks e `RETRY_CONFIG`.
- `media.js`: constraints, erros de permissao/dispositivo, screen capture,
  stream helpers, stats, MOS, perfis, devices, replace track, attach video
  stall e codec preferences.
- `lobby_webrtc_hook.test.js`: data channels, roteamento inbound de canais,
  stats completas, feedback imediato em `ice_disconnected`, deferral por
  `getStats()` e cleanup de poller.
- `lobby_media_hook.test.js`: receive-only, fallback de captura, devices do
  setup, fila ate PC ready, republish apos PC replacement, watchdog de video
  remoto, screen share e atalhos.

Backend:

- `calls/health_test.exs`: healthcheck operacional cobre P2P signaling, TURN
  desabilitado/degradado, drift de listeners TURN, conferencia desabilitada e
  range ICE inutilizavel sem expor segredos.

LiveView:

- `p2p_session_flow_test.exs`: setup, invite, accept/decline/cancel, console,
  files/games/stats, media state, receive-only, audio-only, recovery UI,
  window manager, mensagens persistidas, ignore/block, concorrencia de invites,
  rehydrate com slot stale, feedback de `ice_disconnected` e botao End dentro do
  banner de recovery.

E2E:

- `e2e/tests/chat-p2p.spec.ts`: aceita pelo PM, video real bidirecional,
  file/game no mesmo PC, TURN relay, receive-only, audio-only, screen share,
  falha com retry manual, mini/stats/maximize, decline/cancel.
- `e2e/tests/chat-call-fault-injection.spec.ts`: queda curta de LiveView/rede
  durante sessao P2P, reconexao e encerramento; recovery `failed` com botao
  `End` abrindo confirmacao e terminando a sessao; reload do answerer durante
  offer inicial; retries manuais simultaneos dos dois peers com midia remota
  recuperada.

Lacunas P2P de teste:

- perda de mensagem server-client durante handshake ja com offer em voo;
- TURN indisponivel com `turn_only` habilitado;
- E2E destrutivo de laboratorio com perda de rede fisica/packet loss enquanto
  ICE entra em `disconnected`.

### Conferencia

Unitarios JS:

- `group_call_prejoin_hook.test.js`: preferencias persistidas, device preview,
  refresh de markup, prompt pendente, permissao negada com retry e config P2P.
- `group_call_webrtc_hook.test.js`: capture denied warning, constraints,
  audio/video off sem getUserMedia, moderacao, push-to-talk, duplicate offer,
  offer queue, recovery com request_offer, `rejoin_required`, ICE state,
  captura on-demand, watchdog de tile remoto, manual retry, layout, reactions,
  stats, active speaker, screen share e screen moderation.

Channel/LiveView:

- `group_call_channel_test.exs`: token ausente, token de outra room, join com
  server SDP offer, validacao SDP/ICE/offer_id, rejoin_required e rate limit de
  sinalizacao.
- `group_call_flow_test.exs`: criacao/join/prejoin, preferencias, indicadores,
  participantes, leave, layout, atalhos, a11y, empty/failure states, mini mode,
  stats, renegociacao nao degrada status, screen share, qualidade, reacoes,
  server stats e moderacao.
- `calls_health_controller_test.exs`: endpoint `GET /api/calls/healthz` retorna
  200 para `degraded` e 503 para `down`.

SFU BEAM:

- `sfu_media_path_test.exs`: video bidirecional sintetico, gaps/duplicatas/
  reorder, RTP stats monotonic, PLI, late join, quatro participantes, sem
  camera, audio-only, screen share, leave/rejoin churn, remaining routes e ICE
  restart explicito. O teste de stats aquece a rota antes da contagem exata
  para evitar descartar sequencias antigas como se fossem falha de encaminhamento.

E2E:

- `e2e/tests/chat-group-call.spec.ts`: prejoin, polish, dois usuarios trocando
  video real, atalhos, entrada com mic/camera off, permissao negada com
  receive-only, moderacao, request-to-speak, locked conference, screen share,
  layout, mini mode, stats, qualidade, reacoes, failed media recovery com retry
  manual, tres usuarios renegociando join/leave e screen moderation.
- `e2e/tests/chat-call-fault-injection.spec.ts`: queda curta de LiveView/rede
  durante conferencia, reconexao e saida; reload durante `group_call_offer`;
  `PeerServer` encerrado antes de `request_offer` com rejoin por
  `previous_participant_id`; erro de recovery/media com botao `Leave` abrindo
  confirmacao e limpando status/window.

Lacunas conferencia de teste:

- reentrada de browser apos Phoenix channel reconnect durante offer pendente e
  perda real de mensagem server-client;
- candidate invalido repetido agregado por epoch.

