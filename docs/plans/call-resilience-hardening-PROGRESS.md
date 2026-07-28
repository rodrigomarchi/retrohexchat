# Call resilience hardening - progresso e aprendizados

Data de inicio: 2026-07-28

Objetivo: tornar chamadas P2P e conferencia resilientes contra falhas de
handshake, SDP/ICE, recovery parcial, reconnect e device/media fallback, sem
deixar o usuario em fluxos quebrados.

Fonte do mapeamento:
`docs/reference/call-handshake-resilience-map.md`.

Follow-up operacional:
`docs/plans/call-resilience-follow-up.md`.

## Estado

| Fase | Tema | Estado |
|---|---|---|
| 1 | Estado/protocolo de recovery | CONCLUIDO |
| 2 | P2P recovery coordenado | CONCLUIDO |
| 3 | Conferencia rejoin robusto | CONCLUIDO |
| 4 | Validacao SDP/ICE e rate limits | CONCLUIDO |
| 5 | Midia/device recovery | CONCLUIDO |
| 6 | Testes e verificacoes | CONCLUIDO |
| 7 | ICE direto, reattach e botoes de erro | CONCLUIDO |
| 8 | Watchdog visual de tile remoto da conferencia | CONCLUIDO |
| 9 | Privacy relay aplicado imediatamente em P2P ativo | CONCLUIDO |
| 10 | Falhas repetidas de ICE candidate no browser | CONCLUIDO |
| 11 | Replay idempotente de sinalizacao P2P | CONCLUIDO |
| 12 | Watchdog de offer inicial da conferencia | CONCLUIDO |
| 13 | Telemetria operacional de recovery/falhas de chamadas | CONCLUIDO |
| 14 | Restart explicito quando snapshot P2P foi perdido | CONCLUIDO |
| 15 | `getStats()` antes de escalar `disconnected` | CONCLUIDO |
| 16 | Diagnostico de recovery/handshake no painel de stats | CONCLUIDO |
| 17 | E2E destrutivo de reload durante offer P2P/SFU | CONCLUIDO |
| 18 | E2E destrutivo de PeerServer morto durante `request_offer` | CONCLUIDO |
| 19 | E2E destrutivo de retries simultaneos P2P | CONCLUIDO |
| 20 | Feedback imediato para P2P `disconnected` | CONCLUIDO |

## Log

### 2026-07-28 - Inicio

- Criado arquivo vivo de progresso.
- Ordem de execucao escolhida:
  1. P2P recovery coordenado e signaling epoch;
  2. conferencia com rejoin quando `PeerServer` nao esta pronto;
  3. validacao e rate limit;
  4. recovery de midia/device;
  5. testes direcionados por regressao encontrada.

## Aprendizados

- P2P tem single-offerer correto, entao recovery iniciado pelo answerer precisa
  virar pedido explicito ao initiator.
- Conferencia precisa distinguir renegociacao no mesmo `PeerServer` de rejoin
  completo com novo endpoint WebRTC.

### 2026-07-28 - Iteracao adicional: reload durante offer P2P/SFU

- Pesquisa web aplicada antes da implementacao:
  - Playwright `WebSocketRoute`/`WebSocket` documenta interceptacao de websocket,
    mas a decisao foi evitar mock de protocolo Phoenix e usar injecao real no
    browser;
  - Playwright navigation/wait APIs foram usadas para reload deterministico;
  - Phoenix LiveView remonta no reconnect, e o parametro `_mounts` confirma que
    reconnect precisa reconstruir estado proprio da aplicacao;
  - Phoenix Channels reentra em channels automaticamente com backoff, mas estado
    de chamada fora do channel precisa ser reconciliado pela aplicacao.
- E2E destrutivo:
  - adicionado atraso controlado em `RTCPeerConnection.setRemoteDescription`
    quando chega a primeira remote offer;
  - P2P agora cobre reload do answerer enquanto aplica offer inicial e valida
    status bar, janela e midia remota viva nos dois lados;
  - conferencia agora cobre reload do participante enquanto aplica
    `group_call_offer` do SFU e valida status bar, janela, hook e midia remota.
- Bug encontrado e corrigido:
  - `GroupCallWebRTCHook.destroyed()` enviava `group_call_leave` em qualquer
    destroy, incluindo reload/deploy. Isso transformava queda inesperada em
    saida voluntaria terminal;
  - `GroupCallChannel.terminate/2` agora marca fechamento inesperado como
    `disconnected` por `GroupCall.disconnect_call/4`, preservando janela de
    reconnect;
  - leave voluntario continua terminal pelo LiveView/confirmacao e pelo evento
    raw `group_call_leave`.
- Race fechado:
  - o hook agora inicializa `participantId` a partir de `data-participant-id`;
  - `group_call_join` usa `previous_participant_id` para reentrar no mesmo
    participante;
  - `RoomServer` troca `signal_pid`/`PeerServer` do participante validando mesmo
    `registered_nick_id` e nick normalizado;
  - `disconnect_call` ignora terminate atrasado da conexao antiga se o
    participante ja esta preso ao novo channel.
- Rehydrate LiveView:
  - `ChatLive.GroupCallEvents.rehydrate/1` reconstruiu `@group_call` para
    participante nao-terminal em canal ja rejoined;
  - rehydrate exige sessao identificada;
  - joins de canal em background/restore chamam rehydrate apos atualizar
    `session.channels`, cobrindo canais restaurados depois do mount.
- Verificado:
  - `rtk mix compile --warnings-as-errors`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`
  - `rtk npx tsc --noEmit`
  - `rtk npm exec prettier -- --check apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js e2e/tests/chat-call-fault-injection.spec.ts`
  - `rtk env E2E_PORT=4022 npm test -- --project=chromium tests/chat-call-fault-injection.spec.ts --retries=0`

### 2026-07-28 - Iteracao adicional: PeerServer morto durante request_offer

- Pesquisa web aplicada antes da implementacao:
  - MDN `iceConnectionState` reforca que `disconnected` pode ser transitorio,
    mas `failed` exige recuperacao ativa;
  - MDN `iceconnectionstatechange` documenta o evento usado para reagir a
    mudancas de estado ICE;
  - W3C WebRTC especifica `restartIce()` como novo ciclo de negociacao, mas
    quando o endpoint SFU do participante morreu a recuperacao correta e
    recriar o transporte local e reentrar no servidor;
  - Phoenix routing permite isolar rota operacional de teste por ambiente.
- Criado endpoint E2E-only `POST /api/e2e/group-call-peer/terminate`:
  - habilitado apenas por `config :retro_hex_chat, e2e_fault_injection?: true`
    em `config/e2e.exs`;
  - a rota so e compilada quando a flag esta ativa;
  - a action tambem retorna 404 se a flag nao estiver ativa em runtime;
  - recebe `token` e `participant_id` por corpo JSON, encerra somente o
    `PeerServer` correspondente e espera o `RoomServer` refletir o participante
    como `disconnected` antes de responder.
- E2E destrutivo adicionado em `chat-call-fault-injection.spec.ts`:
  - dois usuarios entram em conferencia com video real;
  - o peer SFU do Bob e encerrado sem leave voluntario;
  - a UI entra em erro recuperavel e o botao real `Retry` e clicado;
  - `group_call_request_offer` recebe `rejoin_required`, o hook executa rejoin
    com `previous_participant_id`, e a midia remota volta viva nos dois lados.
- Aprendizado:
  - para testar esse caminho sem flake, a falha injetada precisa aguardar o
    `:DOWN` do `PeerServer` ser processado pelo `RoomServer`; caso contrario o
    clique de Retry pode disputar com a atualizacao assincrona de estado.
- Verificado:
  - `rtk mix compile --warnings-as-errors`
  - `rtk npx tsc --noEmit`
  - `rtk env E2E_PORT=4023 npm test -- --project=chromium tests/chat-call-fault-injection.spec.ts --retries=0`
  - `rtk mix format --check-formatted`
  - `rtk npm exec prettier -- --check tests/chat-call-fault-injection.spec.ts`
  - `rtk git diff --check`

### 2026-07-28 - Iteracao adicional: retries simultaneos P2P

- Pesquisa web aplicada antes da implementacao:
  - MDN perfect negotiation reforca que corridas de offer/answer precisam de
    papel claro e tratamento idempotente;
  - WebRTC nao define sinalizacao, entao o app precisa coordenar retry/restart
    entre os peers;
  - Playwright actionability foi usado para clicar os botoes reais `Retry`
    somente quando estavam visiveis e habilitados.
- E2E destrutivo adicionado em `chat-call-fault-injection.spec.ts`:
  - dois peers entram em P2P com video real bidirecional;
  - ambos recebem recovery `failed` com `manual_retry`;
  - ambos clicam `Retry` quase simultaneamente;
  - o fluxo precisa continuar single-offerer, limpar os banners de recovery e
    restaurar tracks remotas `live` nos dois lados.
- Aprendizado:
  - o caminho `p2p_retry_connection` ja e suficientemente idempotente para dois
    retries manuais concorrentes porque cada lado faz restart local e o
    answerer transforma sua tentativa em `lobby_renegotiate` para o iniciador.
- Verificado:
  - `rtk npx tsc --noEmit`
  - `rtk env E2E_PORT=4024 npm test -- --project=chromium tests/chat-call-fault-injection.spec.ts --retries=0`

### 2026-07-28 - Iteracao adicional: feedback imediato para P2P disconnected

- Pesquisa web aplicada antes da implementacao:
  - MDN `iceConnectionState` reforca que `disconnected` pode ser transitorio e
    voltar para `connected`;
  - W3C WebRTC recomenda ICE restart quando o estado vira `failed` e sugere
    `getStats()` para decidir se `disconnected` ainda tem atividade antes de
    reiniciar;
  - Chrome DevTools Protocol documenta `packetLoss` para WebRTC em
    `Network.emulateNetworkConditions`, mas no Chromium local o teste E2E com
    packet loss nao gerou `iceConnectionState="disconnected"` de forma
    deterministica dentro de 20s.
- Mudanca implementada:
  - `LobbyWebRTCHook._startDisconnectedGracePeriod/2` agora envia
    `lobby_recovery_pending` assim que entra em `connection_disconnected` ou
    `ice_disconnected`;
  - esse evento nao recria PC nem agenda retry extra; ele apenas mostra
    feedback real enquanto o grace period e o deferral por `getStats()` decidem
    se ha recuperacao espontanea;
  - `ChatLive.P2PSessionEvents` trata `lobby_recovery_pending` como recovery
    `:reconnecting` com `trigger: "disconnected"`;
  - `P2PSessionConsole` mostra mensagem especifica de interrupcao de midia.
- Testes:
  - JS unit garante que `ice_disconnected` mostra `lobby_recovery_pending`, mas
    ainda nao dispara `lobby_retry` antes da grace period;
  - JS unit garante que o deferral por `getStats()` preserva essa ausencia de
    retry imediato enquanto ainda ha atividade;
  - LiveView garante que o banner aparece com a mensagem real e volta a idle em
    `lobby_connected`.
- Aprendizado:
  - Playwright/CDP e util para testar rede HTTP/WebSocket e pode documentar
    packet loss WebRTC, mas o estado ICE real em loopback/local pode nao
    transicionar de modo deterministico; esse cenario deve ir para follow-up com
    netem/Network Link Conditioner/lab de navegador, nao para suite local cara.
- Verificado:
  - `rtk npx tsc --noEmit`
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - `rtk mix compile --warnings-as-errors`
  - `rtk env E2E_PORT=4026 npm test -- --project=chromium tests/chat-call-fault-injection.spec.ts --retries=0`

### 2026-07-28 - P2P epoch e retry coordenado

- `LobbyWebRTCHook` agora carrega `signalingEpoch`, `offer_id` e
  `connection_reset` nos signals.
- Retry automatico do answerer agora envia `lobby_renegotiate` recover com
  `connection_reset`, evitando recriar PC e ficar esperando offer que nao vem.
- Offers de recovery podem fazer o answerer recriar PC quando chegam com epoch
  novo e `connection_reset`.
- Answers/candidates de epoch antiga sao descartados.
- `P2P.validate_signal/1` passou a validar tamanho/shape de SDP e ICE candidate
  e preserva metadados de recovery.
- `lobby_renegotiate` passou pelo rate limit de sinalizacao.
- Verificado:
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/p2p/p2p_test.exs`
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`

### 2026-07-28 - Conferencia rejoin quando PeerServer cai

- `GroupCallWebRTCHook` agora trata `request_offer` com erro
  `rejoin_required` como rejoin completo:
  - publica recovery `rejoining`;
  - fecha o `RTCPeerConnection` local;
  - limpa candidates/offers pendentes;
  - limpa tiles/tracks remotos antigos;
  - para screen share ativo antes de reentrar;
  - chama `group_call_join` novamente no mesmo channel com `trigger: "rejoin"`
    e `rejoin_epoch`.
- `_ensureLocalTracks` passou a republicar tracks locais quando o PC muda.
- `GroupCallChannel` converte `:peer_not_ready` em `code: "rejoin_required"`.
- `PeerServer` deixou de linkar no channel e passou a monitorar o channel.
  Aprendizado: o link fazia queda do endpoint SFU derrubar o proprio canal de
  sinalizacao, bloqueando retry/rejoin no browser.
- Verificado:
  - `rtk npm test -- --run test/hooks/group_call/group_call_webrtc_hook.test.js`
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk npm run format:check`
  - `rtk npm run lint` (0 erros, 2 warnings existentes em
    `assets/scripts/bundle_retrohex_css.cjs`)
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`

### 2026-07-28 - Iteracao adicional: diagnostico de recovery/handshake no painel de stats

- Pesquisa web aplicada antes da implementacao:
  - MDN `connectionState` confirma que o estado agregado do
    `RTCPeerConnection` deve ser tratado como dado operacional visivel;
  - MDN `getStats()` confirma que o browser expoe snapshots tecnicos da conexao;
  - Phoenix LiveView mantém o read model no servidor, entao metadados de
    recovery precisam entrar nos assigns para ficarem consistentes entre patchs.
- P2P:
  - `LobbyWebRTCHook` passou a incluir em `lobby_stats.summary`
    `connection_state`, `ice_connection_state`, `signaling_epoch` e `offer_id`;
  - `P2PStats` normaliza esses campos com defaults;
  - estado `recovery` do P2P agora preserva `trigger`;
  - painel de stats ganhou grupo `Recovery` com state, reason, trigger,
    attempt, signaling epoch e offer id.
- Conferencia:
  - `GroupCallWebRTCHook` passou a incluir em `group_call_stats.summary`
    `offer_id` e `rejoin_epoch`;
  - `GroupCallStats` normaliza esses campos;
  - painel de stats ganhou grupo `Recovery` com state, reason, trigger,
    attempt, next retry, offer id e rejoin epoch.
- Mantido o mesmo criterio de privacidade da telemetria: nada de SDP, ICE
  candidate, tokens, user ids, IPs ou mensagens livres no painel.
- Verificado:
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/p2p_stats_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/group_call_stats_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/group_call/stats_panel_test.exs`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk npm run format:check`
  - `rtk npm run lint` (0 erros, 2 warnings existentes em
    `assets/scripts/bundle_retrohex_css.cjs`)
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`

### 2026-07-28 - Iteracao adicional: `getStats()` antes de recovery em `disconnected`

- Pesquisa web aplicada antes da implementacao:
  - MDN `iceConnectionState` documenta que `disconnected` pode ser transitorio
    e voltar sozinho para `connected`;
  - MDN `getStats()` expõe um `RTCStatsReport` do `RTCPeerConnection`;
  - W3C WebRTC Stats define contadores cumulativos de bytes/pacotes em
    `candidate-pair`, `transport`, RTP inbound/outbound e data channels.
- `media.js` ganhou snapshot de atividade de baixa cardinalidade:
  `bytesReceived`, `bytesSent`, `packetsReceived`, `packetsSent`,
  `messagesReceived` e `messagesSent`. O helper nao registra SDP, ICE, ids,
  enderecos ou qualquer campo identificavel.
- P2P agora, ao receber `connectionState/iceConnectionState = disconnected`,
  mede atividade antes/depois da janela de grace. Se ainda houver bytes,
  pacotes ou mensagens avancando, adia o retry por mais uma janela, com limite
  pequeno. Quando a atividade para, o recovery existente dispara normalmente.
- Conferencia aplica a mesma decisao antes de pedir `group_call_request_offer`
  automatico por `disconnected`/`ice_disconnected`; `failed` continua escalando
  sem deferral.
- Defensivo adicionado para contadores de deferral nao inicializados, evitando
  `NaN` em instanciacoes parciais de hook.
- Testes adicionados:
  - helper agrega counters de candidate-pair, transport, RTP e data channel;
  - P2P segura `lobby_retry` enquanto `getStats()` mostra atividade e dispara
    retry quando a atividade para;
  - conferencia segura `group_call_request_offer` enquanto ha atividade e
    retoma recovery quando a atividade para.
- Verificado:
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js`
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk npm run format:check`
  - `rtk npm run lint` (0 erros, 2 warnings existentes em
    `assets/scripts/bundle_retrohex_css.cjs`)
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`

### 2026-07-28 - Iteracao adicional: restart explicito sem snapshot P2P

- Pesquisa web aplicada antes da implementacao:
  - Phoenix Channels documenta entrega at-most-once e perda de mensagens apos
    restart se a aplicacao nao persistir/reconciliar;
  - MDN `restartIce()` reforca que recovery ICE precisa de novo ciclo de
    negociacao pelo canal de sinalizacao;
  - W3C WebRTC recomenda ICE restart em `failed` e sugere stats para decidir
    escalonamento em `disconnected`.
- Decisao: nao persistir SDP/ICE antigo para reaplicar apos restart completo do
  BEAM nesta etapa. Em vez disso, tornar o fluxo explicitamente recomecavel:
  quando um `SessionServer` novo assume uma sessao `connected` sem snapshot de
  sinalizacao, o gate de readiness emite `lobby_start_signaling` com
  `restart: true` e `reason: "signaling_snapshot_lost"`.
- LiveViews que ja tinham hook ativo agora transformam esse evento em
  `lobby_restart`, forçando o browser a descartar o `RTCPeerConnection` antigo
  e criar um ciclo limpo. LiveViews recem-montadas ainda recebem
  `lobby_start_offer`/`lobby_start_answer`.
- `lobby_connected` agora marca `webrtc_started: true` no assign, porque esse
  evento so e possivel depois de um PC real estar ativo no browser. Isso evita
  que um reset futuro seja tratado como primeiro start quando deveria ser
  restart.
- O motivo `signaling_snapshot_lost` passa ate o hook e entra na telemetria de
  recovery com `trigger: "server"`.
- Testes adicionados/ajustados:
  - `SessionServer`: processo reiniciado para sessao `connected` sem snapshot
    pede restart limpo;
  - LiveView P2P: evento server-side de reset reinicia ambos os hooks ativos;
  - LiveView reattach: ao liberar slot stale, o estado fica em recovery real
    `signaling_snapshot_lost` enquanto o novo offer e enviado;
  - JS hook: restart payload preserva `reason` no pedido de renegociacao do
    answerer.
- Verificado:
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/lobby/session_server_test.exs`
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/lobby/session_server_test.exs apps/retro_hex_chat/test/retro_hex_chat/calls/events_test.exs apps/retro_hex_chat/test/retro_hex_chat/p2p apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/prom_ex_test.exs`
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk npm run format:check`
  - `rtk npm run lint` (0 erros, 2 warnings existentes em
    `assets/scripts/bundle_retrohex_css.cjs`)
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`

### 2026-07-28 - Validacao, offer_id e media fallback

- `GroupCallChannel` passou a validar SDP e ICE candidate por tamanho e shape.
- `PeerServer` agora envia erro `group_call_error` quando falha ao aplicar answer
  ou candidate dentro do ExWebRTC.
- Conferencia agora inclui `offer_id` em `group_call_offer`; browser ecoa esse id
  na answer, e o `PeerServer` ignora answers obsoletas.
- O rate limit de reacoes ja existia em `GroupCall.send_reaction/4`; tentativa de
  duplicar no Channel bloqueou a primeira reacao. Mantido um unico rate limit no
  contexto e adicionado teste para o contrato.
- Conferencia agora captura mic/camera on-demand quando o usuario habilita midia
  depois de entrar receive-only ou apos falha inicial.
- P2P agora faz fallback automatico de camera no `devicechange`, simetrico ao
  fallback de microfone, e marca camera off se a recuperacao falhar.
- Verificado:
  - `rtk npm test -- --run test/hooks/group_call/group_call_webrtc_hook.test.js`
  - `rtk npm test -- --run test/hooks/lobby/lobby_media_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`

### 2026-07-28 - Regressao E2E P2P: falha terminal em loop

- O E2E `failed recovery offers retry without closing the P2P console` revelou
  timeout mesmo com o banner de retry visivel.
- O snapshot mostrou centenas de mensagens `P2P connection failed.`. Causa:
  `_handleFailure()` podia ser chamado repetidamente enquanto ja havia retry
  pendente ou estado terminal `failed`.
- `LobbyWebRTCHook` agora controla o ciclo de recovery com:
  - `recoveryTimer` unico;
  - estado terminal `recoveryFailed`;
  - `_notifyFailed/2` idempotente;
  - reset explicito ao conectar, iniciar/reiniciar ou receber estado
    `reconnecting`.
- `p2p_session_events.ex` tambem deduplica `lobby_failed` repetido com a mesma
  reason para evitar crescimento do historico/status mesmo se outro emissor
  repetir o evento.
- Verificado:
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - `rtk npm test -- --project=chromium tests/chat-p2p.spec.ts -g "failed recovery offers retry"` em `e2e/`

### 2026-07-28 - Regressao E2E P2P: video remoto ausente no handshake inicial

- Repetir o E2E P2P com `--retries=0 --repeat-each=5` expôs uma falha real de
  handshake/midia: 4 de 5 execucoes ficavam conectadas, mas sem video remoto vivo
  dentro de 30s.
- Primeiro ajuste: o `LobbyMediaHook` agora recebe `lobby_media_peer_media` e
  sabe quando o peer esta anunciando video. O watchdog cobre tambem o caso
  "video remoto esperado mas nenhuma track chegou", alem do caso anterior de
  track viva porem sem frames.
- Segundo ajuste, que removeu o flake: `P2PSessionConsole` nao trata recovery
  `:reconnecting`/`:failed` como peer desconectado quando a sessao base ja esta
  `:connected`. Antes isso desmontava o `LobbyMediaHook` durante o proprio
  recovery, apagando a superficie de midia e impedindo reattach/republish.
- Verificado:
  - `rtk npm test -- --run test/hooks/lobby/lobby_media_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs --include liveview_feature`
  - `rtk npm test -- --project=chromium tests/chat-p2p.spec.ts -g "failed recovery offers retry" --repeat-each=5 --retries=0` em `e2e/`
  - `rtk npm test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts -g "failed.*recovery|failed recovery" --retries=0` em `e2e/`

### 2026-07-28 - Bateria final

- Verificado sem falhas:
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/p2p apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - `rtk npm run format:check`
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
- `rtk npm run lint` passou com 0 erros e manteve 2 warnings existentes em
  `assets/scripts/bundle_retrohex_css.cjs` (`no-console`).

### 2026-07-28 - Iteracao adicional: rede/deploy/saida de erro

- Pesquisa web aplicada:
  - MDN `restartIce()` confirma que ICE restart so se completa via novo ciclo
    offer/answer e que `negotiationneeded` pode repetir ate o restart ser
    negociado;
  - MDN perfect negotiation reforca controle explicito de colisao/stale offer;
  - MDN `iceConnectionState` separa `disconnected` transitorio de `failed`;
  - W3C WebRTC confirma que `restartIce()` marca a proxima oferta como restart.
- P2P e conferencia agora observam `iceConnectionState` alem de
  `connectionState`, para capturar browsers que sinalizam falha por ICE antes
  de atualizar o estado agregado.
- P2P rehydrate deixou de transformar `:already_joined` em erro terminal
  imediato. A UI entra em `reattach_pending`, tenta anexar com backoff e mantem
  `Retry`/`End` acionaveis enquanto uma janela stale ainda segura o slot.
- O botao `End` no banner de erro P2P passou a ser testado pelo seletor real
  `data-testid="p2p-end-from-recovery"` e abre o mesmo confirm de encerramento.
- Adicionado teste de encerramento durante `reattach_pending`: mesmo com outro
  processo segurando o slot, confirmar `End` fecha a sessao no backend e limpa o
  peer.
- Conferencia ja cobria `group-call-leave-from-error`; a bateria LiveView foi
  rerodada para garantir que o botao continua abrindo confirm.
- Um flake BEAM no teste de stats RTP foi diagnosticado: apos warm-up, o teste
  reenviava sequencias antigas (`1..20`) que podiam ser descartadas como
  duplicadas. O teste agora aquece a rota, drena a fila e usa ranges altos
  monotonicamente crescentes (`100..119`, `130..145`).
- Verificado nesta iteracao:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - `rtk npm test -- --run test/lib/p2p/webrtc.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs:105 --repeat-until-failure 5`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/p2p apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`

### 2026-07-28 - Iteracao adicional: tile remoto preto na conferencia

- `GroupCallWebRTCHook` deixou de anexar stream remoto com `video.srcObject`
  cru; agora usa `attachMediaStream`, o mesmo helper defensivo usado pelo P2P.
- Quando uma track de video remota esta `live`, mas o elemento nao fica pronto
  ou nao ganha dimensoes apos o grace period, o hook publica recovery e pede
  `group_call_request_offer` com `trigger: "remote_video_stalled"`.
- O recovery por stream e idempotente: o mesmo `stream_id` nao dispara retries
  infinitos enquanto continua travado. O mapa e limpo em rejoin, conexao
  restaurada, remocao de participante e cleanup.
- Teste adicionado:
  - `watches remote video tiles for stalled rendering and requests recovery`
  - `requests a fresh offer when a remote video tile stops rendering`
- Verificado:
  - `rtk npm test -- --run test/hooks/group_call/group_call_webrtc_hook.test.js`

### 2026-07-28 - Iteracao adicional: toggle privacy relay em sessao viva

- Antes, `p2p_toggle_privacy` persistia a preferencia e atualizava UI, mas uma
  conexao ja ativa continuava com o `RTCPeerConnection` antigo ate algum retry
  futuro.
- `lobby_restart` agora recebe `ice_servers`, `role` e `turn_only`; o
  `LobbyWebRTCHook` atualiza a configuracao antes de recriar o PC.
- Alternar privacy relay durante `:connected`/`:connecting` dispara restart
  coordenado:
  - lado local entra em recovery `privacy_changed`;
  - peer recebe `lobby_manual_retry` com `reason: "privacy_changed"`;
  - cada lado reinicia com sua propria preferencia `turn_only`.
- Testes adicionados:
  - JS: restart reconstrói PC com `iceTransportPolicy: "relay"` quando payload
    traz `turn_only: true`;
  - LiveView: toggle em sessao conectada envia `lobby_restart` com policy atual
    para criador e peer.
- Verificado:
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs:714 --include liveview_feature`

### 2026-07-28 - Iteracao adicional: falha repetida de ICE candidate no browser

- Pesquisa web aplicada antes da implementacao:
  - MDN `addIceCandidate()` descreve falhas quando nao ha remote description ou
    quando o candidate nao corresponde a mid/ufrag/m-line da descricao remota;
  - W3C WebRTC define `addIceCandidate` como operacao sobre a descricao remota,
    o que torna candidates stale durante renegociacao/restart um erro
    recuperavel no app;
  - Phoenix Channels documenta entrega server-client at-most-once, entao o app
    precisa ter recovery idempotente em vez de depender de replay automatico.
- P2P agora conta falhas seguidas de `addIceCandidate` por ciclo de conexao.
  Falhas isoladas sao toleradas e um candidate aplicado com sucesso zera o
  contador; tres falhas seguidas entram no recovery coordenado existente.
- Conferencia aplica o mesmo padrao no hook SFU: tres falhas seguidas publicam
  recovery `ice_candidate_failed` e pedem fresh offer pelo fluxo existente.
- Testes adicionados:
  - P2P: falhas isoladas/stale nao recuperam cedo, sucesso zera o contador e
    falha repetida aciona `lobby_retry`;
  - Conferencia: sucesso zera o contador e falha repetida aciona recovery
    `ice_candidate_failed`.
- Verificado:
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js`
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk npm run format:check`
  - `rtk npm run lint` (0 erros, 2 warnings existentes em
    `assets/scripts/bundle_retrohex_css.cjs`)
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`

### 2026-07-28 - Iteracao adicional: replay idempotente de sinalizacao P2P

- Pesquisa web aplicada antes da implementacao:
  - Phoenix Channels documenta entrega server-client at-most-once; mensagens
    perdidas durante offline/restart nao sao reenviadas automaticamente;
  - LiveView `push_event/3` e entregue pelo ciclo de patch/evento do LiveView,
    entao evento server-client nao deve ser tratado como duravel;
  - WebRTC deixa a sinalizacao a cargo da aplicacao, logo replay/idempotencia
    precisam ser parte do protocolo do app.
- `SessionServer` agora guarda snapshot em memoria de sinalizacao por papel:
  - ultimo SDP local por papel;
  - ate 64 ICE candidates recentes por papel, deduplicados;
  - ultimo `lobby_renegotiate` do answerer para o initiator.
- O snapshot e limpo quando um participante desconecta, porque o PC antigo nao
  deve ser reaplicado depois de rejoin/deploy; nesse caso o gate de readiness
  inicia um ciclo WebRTC novo.
- `LobbyWebRTCHook` agora:
  - pede replay ao iniciar, ao reconectar LiveView e enquanto startup segue sem
    conexao;
  - aplica lote `lobby_signal_replay` em ordem;
  - ignora answers/offers/candidates ja aplicados;
  - reenvia `lobby_renegotiate` do answerer algumas vezes ate chegar uma nova
    offer;
  - entra no recovery coordenado se a renegociacao reenviada nao recebe offer.
- Verificado:
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/lobby/session_server_test.exs`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs:750 --include liveview_feature`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/lobby apps/retro_hex_chat/test/retro_hex_chat/p2p`
  - `rtk npm run format:check`
  - `rtk npm run lint` (0 erros, 2 warnings existentes em
    `assets/scripts/bundle_retrohex_css.cjs`)
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`

### 2026-07-28 - Iteracao adicional: watchdog de offer inicial da conferencia

- Pesquisa web aplicada antes da implementacao:
  - Phoenix Channels nao reenvia mensagens server-client perdidas;
  - MDN/W3C WebRTC deixam a entrega de offer/answer/ICE para a sinalizacao da
    aplicacao;
  - `restartIce()`/fresh offer sao o caminho correto para reconstruir transporte
    em vez de reaplicar SDP antigo apos queda.
- A conferencia ja tinha replay ativo do lado servidor: `PeerServer.request_offer`
  reenvia a offer pendente se ainda esta em `:have_local_offer`, ou cria uma
  nova offer com ICE restart.
- `GroupCallWebRTCHook` agora agenda watchdog apos `group_call_joined`. Se a
  offer inicial nao chega, o hook:
  - publica recovery real `offer_not_received`;
  - chama `group_call_request_offer` com `trigger: "offer_watchdog"`;
  - respeita `rejoin_required`;
  - apos tentativas limitadas, publica falha manualmente recuperavel.
- O watchdog e limpo quando uma offer e processada, quando a conexao fica
  `connected`, em rejoin e no cleanup.
- Verificado:
  - `rtk npm test -- --run test/hooks/group_call/group_call_webrtc_hook.test.js`

### 2026-07-28 - Iteracao adicional: telemetria operacional de recovery

- Pesquisa web aplicada antes da implementacao:
  - `Telemetry.Metrics` documenta counters/sums derivados de eventos
    `:telemetry` com tags vindas da metadata;
  - Phoenix/LiveDashboard consome `Telemetry.Metrics` para visualizar eventos
    customizados em tempo real;
  - PromEx usa os mesmos eventos para expor series Prometheus.
- Criado `RetroHexChat.Calls.Events` como camada unica para chamadas:
  - `[:retro_hex_chat, :calls, :recovery, :transition]`;
  - `[:retro_hex_chat, :calls, :client_error]`;
  - `[:retro_hex_chat, :calls, :signaling, :replay]`.
- Metadata foi limitada a campos operacionais de baixa cardinalidade
  (`surface`, `state`, `reason`, `trigger`, `manual_retry`, `phase`, attempts e
  contagens). Tokens, ids de usuario/participante, SDP, ICE e mensagens livres
  ficam fora dos eventos.
- P2P agora registra:
  - recovery para `reconnecting`, `failed` e retorno a `connected`;
  - falhas de validacao/rate-limit de sinalizacao;
  - replay de sinalizacao como `served`, `empty` ou `failed`;
  - motivo real de retry vindo do browser (`ice_failed`,
    `connection_disconnected`, `ice_candidate`, `renegotiate_request`, etc.) em
    vez de achatar tudo para `auto_retry`.
- Conferencia agora registra:
  - recovery vindo de `group_call_recovery_state`;
  - `group_call_connection_state` quando o LiveView muda UI diretamente para
    conectado/reconectando/erro;
  - erros client-side e erros de channel em join, answer, ICE e request_offer;
  - retry manual do botao de erro como transicao `negotiating` com
    `reason: "manual_retry"`.
- Corrigido gap de estado: o LiveView da conferencia agora normaliza
  `rejoining`, que ja era publicado pelo hook durante rejoin de endpoint SFU.
- Metrics adicionadas:
  - LiveDashboard (`RetroHexChatWeb.Telemetry.metrics/0`);
  - Prometheus/PromEx (`RetroHexChat.PromEx.Plugins.Domain`).
- Testes adicionados/ajustados:
  - unitario de `RetroHexChat.Calls.Events`;
  - fluxo P2P validando telemetry de restart, retry com reason real, falha e
    replay servido;
  - fluxo de conferencia validando telemetry de erro client-side e recovery.
- Verificado:
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/calls/events_test.exs`
  - `rtk npm test -- --run test/hooks/lobby/lobby_webrtc_hook.test.js`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/prom_ex_test.exs`
  - `rtk npm test -- --run test/hooks/group_call/group_call_webrtc_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js`
  - `rtk npm test -- --run test/lib/p2p/media.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/lib/p2p/webrtc.test.js`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/calls/events_test.exs apps/retro_hex_chat/test/retro_hex_chat/lobby apps/retro_hex_chat/test/retro_hex_chat/p2p apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/prom_ex_test.exs`
  - `rtk npm run format:check`
  - `rtk npm run lint` (0 erros, 2 warnings existentes em
    `assets/scripts/bundle_retrohex_css.cjs`)
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`

### 2026-07-28 - Iteracao adicional: E2E destrutivo de fault injection

- Pesquisa web aplicada antes da implementacao:
  - Playwright `BrowserContext.setOffline()` permite simular queda real de rede
    do contexto do usuario;
  - Playwright actionability exige que `click()` encontre elemento visivel,
    estavel, habilitado e recebendo eventos, entao testes de botoes de erro
    precisam validar o botao real do dialogo e lidar com reconciliacao
    assincrona do DOM.
- Criado `e2e/tests/chat-call-fault-injection.spec.ts` com cobertura E2E para:
  - P2P conectado sofrendo queda curta de LiveView/rede, reconectando e ainda
    permitindo encerrar a sessao;
  - P2P em recovery `failed` abrindo confirmacao pelo botao `End` do banner e
    encerrando a sessao;
  - conferencia conectada sofrendo queda curta de LiveView/rede, reconectando e
    ainda permitindo sair da chamada;
  - conferencia em erro de media/recovery abrindo confirmacao pelo botao
    `Leave` do estado de erro e saindo da chamada.
- A cobertura valida o comportamento reportado pelos usuarios: em erro, o
  botao de encerramento precisa abrir a confirmacao destrutiva e o confirm
  precisa limpar status/window, sem deixar o usuario preso.
- Observacao operacional: a primeira execucao reaproveitando `localhost:4003`
  passou os dois fluxos P2P, mas o servidor E2E ja existente ficou indisponivel
  antes dos fluxos de conferencia. A reexecucao em porta HTTP isolada confirmou
  4/4 cenarios verdes sem retries.
- Verificado:
  - `rtk npx tsc --noEmit`
  - `rtk npm exec prettier -- --check tests/chat-call-fault-injection.spec.ts`
  - `rtk env E2E_PORT=4018 npm test -- --project=chromium tests/chat-call-fault-injection.spec.ts --retries=0`
  - `rtk env E2E_PORT=4017 npm test -- --project=chromium tests/chat-p2p.spec.ts -g "failed recovery offers retry" --retries=0`
  - `rtk env E2E_PORT=4016 npm test -- --project=chromium tests/chat-group-call.spec.ts -g "failed media recovery offers" --retries=0`
  - `rtk npm run format:check`
  - `rtk npm run lint` (0 erros, 2 warnings existentes em
    `assets/scripts/bundle_retrohex_css.cjs`)
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`

### 2026-07-28 - Iteracao adicional: healthcheck operacional de chamadas

- Pesquisa web aplicada antes da implementacao:
  - WebRTC.org reforca que TURN e o componente usado quando conexao direta nao
    e possivel;
  - o sample oficial de Trickle ICE valida TURN pela geracao de candidate
    `relay`, mas isso exige um `RTCPeerConnection` de cliente;
  - ExWebRTC documenta que offer/answer e ICE candidates sao responsabilidade
    da aplicacao/sinalizacao.
- Criado `RetroHexChat.Calls.Health` como snapshot operacional de backend,
  sem gerar alocacao TURN artificial nem peer connection falso:
  - `p2p_signaling`: PubSub, `Lobby.Supervisor`, `SessionRegistry` e ETS de
    rate limit P2P;
  - `turn`: configuracao, supervisor principal, listener supervisor,
    allocation supervisor/registry, drift entre listeners esperados/ativos,
    tipo de ICE config (`stun`/`turn`) e capacidade do range de relay;
  - `conference`: flag de conferencia, supervisores/registries SFU e range de
    portas ICE do SFU.
- Adicionado endpoint publico leve `GET /api/calls/healthz`:
  - retorna JSON com `status` global `ok`, `degraded` ou `down`;
  - retorna HTTP 503 somente quando ha status `down`;
  - nao expoe segredo TURN, nonce secret, credential temporaria, SDP, ICE,
    tokens ou ids de usuario;
  - remove contagem publica de salas/peers ativos, que fica reservada para
    Telemetry/PromEx/LiveDashboard.
- O healthcheck agora detecta antes do usuario:
  - TURN configurado mas sem listeners vivos;
  - drift entre configuracao de listeners e arvore supervisionada;
  - range de relay/ICE inutilizavel;
  - SFU/conferencia desabilitada ou sem supervisor/registry essencial.
- Verificado:
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/calls/health_test.exs`
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/calls_health_controller_test.exs`
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/calls/health_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/calls_health_controller_test.exs`
  - `rtk mix format --check-formatted`
  - `rtk mix compile --warnings-as-errors`
  - `rtk git diff --check`
