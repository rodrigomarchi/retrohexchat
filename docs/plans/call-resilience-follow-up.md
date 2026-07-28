# Call resilience follow-up

Data: 2026-07-28

Este documento registra o que ainda deve continuar depois do hardening atual de
P2P e conferencia. O estado detalhado da implementacao fica em
`docs/plans/call-resilience-hardening-PROGRESS.md`; o mapa tecnico fica em
`docs/reference/call-handshake-resilience-map.md`.

## Fora deste projeto: dashboards e alertas

Dashboards/alertas pertencem a outro projeto, mas esta aplicacao ja passou a
emitir os sinais necessarios para eles.

Metricas/eventos a consumir:

- `[:retro_hex_chat, :calls, :recovery, :transition]`
  - tags principais: `surface`, `state`, `reason`, `trigger`,
    `manual_retry`;
  - uso: taxa de retries, falhas terminais e recoveries que voltam a
    `connected`.
- `[:retro_hex_chat, :calls, :client_error]`
  - tags principais: `surface`, `code`, `phase`;
  - uso: erros de join/answer/ICE/request_offer/sinalizacao no cliente ou
    channel.
- `[:retro_hex_chat, :calls, :signaling, :replay]`
  - tags principais: `surface`, `action`, `reason`;
  - uso: medir replay P2P `served`, `empty` e `failed` apos reconnect/deploy.

Healthcheck operacional disponivel neste projeto:

- `GET /api/calls/healthz`
  - status global: `ok`, `degraded` ou `down`;
  - HTTP 503 apenas para `down`;
  - checks: `p2p_signaling`, `turn` e `conference`;
  - nao expoe segredo TURN, credential temporaria, SDP, ICE, tokens ou ids de
    usuario.

Alertas recomendados:

- P2P ou conferencia com aumento sustentado de
  `state="failed"` por `reason`.
- Aumento de `reason="ice_failed"`, `reason="ice_candidate_failed"` ou
  `reason="offer_not_received"`.
- Aumento de `phase="request_offer"` com `code="rejoin_required"` ou
  `code="request_offer_failed"`.
- `signaling.replay` com `action="failed"` maior que zero em janela curta.
- Queda de taxa de `state="connected"` depois de `state="reconnecting"`.
- Alertas especificos de TURN/relay usando as mesmas tags quando
  `reason="ice_failed"` cresce em modo relay-only.

## Ainda pendente neste projeto

Prioridade alta:

- Persistir historico/auditoria de sinalizacao P2P se for necessario diagnostico
  pos-incidente. O fluxo ja e explicitamente recomecavel apos perda do snapshot
  em memoria: sessao `connected` sem snapshot dispara restart limpo com
  `reason="signaling_snapshot_lost"`, mas SDP/ICE antigos nao sao guardados em
  storage duravel.
- Expandir a cobertura destrutiva E2E alem da suite inicial
  `chat-call-fault-injection.spec.ts`, que ja cobre queda curta de rede/LiveView,
  botoes `End/Leave` em erro, reload durante offer inicial P2P/SFU e
  `PeerServer` encerrado antes de `request_offer`, alem de retries manuais
  simultaneos dos dois peers P2P:
  - perda de rede enquanto `iceConnectionState` fica `disconnected`, idealmente
    com netem/Network Link Conditioner/lab de navegador. O comportamento de UI
    e state machine ja esta coberto por unit/LiveView; Playwright/CDP local com
    `packetLoss` nao produziu a transicao ICE de forma deterministica em
    loopback.

Prioridade media:

- Calibrar em producao o limite de deferrals baseado em `getStats()` para
  `disconnected`. O hardening atual ja segura retries enquanto bytes/pacotes ou
  mensagens ainda avancam, com limite pequeno; o proximo passo e ajustar esse
  limite por dados reais de rede, sem aumentar tempo preso em falha real.
- Unificar o helper visual de watchdog de video local/remoto entre P2P,
  prejoin e conferencia, para reduzir divergencia entre superficies.
- Adicionar amostragem/telemetria de qualidade WebRTC a partir de stats
  normalizados: RTT, packet loss, jitter, frames dropped/frozen e selected
  candidate pair.

Prioridade baixa:

- Criar runbook operacional para incidentes de chamada: como identificar se a
  falha e TURN, signaling, LiveView reconnect, SFU/PeerServer ou device/media.
- Criar uma tela/admin debug apenas para operadores com estado tecnico da chamada
  atual, sem expor dados sensiveis: surface, state, reason, trigger, attempts e
  ultima transicao.

## Referencias usadas

- Phoenix Channels documenta entrega server-client at-most-once:
  https://hexdocs.pm/phoenix/channels.html
- MDN `iceConnectionState` diferencia `disconnected` transitorio de `failed`:
  https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/iceConnectionState
- MDN `restartIce()` descreve o ICE restart via novo ciclo de negociacao:
  https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/restartIce
- W3C WebRTC recomenda ICE restart em `failed` e sugere usar `getStats()` para
  decidir se `disconnected` precisa de restart:
  https://w3c.github.io/webrtc-pc/
- MDN `getStats()`:
  https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/getStats
- W3C WebRTC Stats:
  https://www.w3.org/TR/webrtc-stats/
- Playwright `BrowserContext.setOffline()`:
  https://playwright.dev/docs/api/class-browsercontext#browser-context-set-offline
- Playwright actionability:
  https://playwright.dev/docs/actionability
- Playwright WebSocket/WebSocketRoute:
  https://playwright.dev/docs/api/class-websocketroute
- Phoenix LiveView mount/reconnect params:
  https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
- Phoenix JS Channels lifecycle/rejoin:
  https://hexdocs.pm/phoenix/js/
