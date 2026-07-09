# SFU embutido para chamadas em grupo - referências, modelagem e plano

> Pedido: sair do P2P 1:1 para chamadas em grupo com SFU completo, sem subir
> outro servidor. O SFU deve morar dentro do servidor do Retro Hex Chat.
>
> Data da análise: 2026-07-09.

## 1. Decisão técnica

A direção recomendada é implementar um SFU embutido no próprio OTP app
`RetroHexChat`, usando `ExWebRTC` como motor WebRTC e usando o projeto
`Nexus` como blueprint direto de Room/Peer/signaling/RTP forwarding.

O que isso significa na prática:

| Tema | Decisão |
|---|---|
| Servidor adicional | Não. O SFU entra no release atual do Retro Hex Chat. |
| Motor WebRTC | `ExWebRTC`, via Hex, rodando no mesmo BEAM. |
| Arquitetura SFU | Inspirada e parcialmente copiada do `Nexus`: `RoomServer` + `PeerServer` + `DynamicSupervisor` + `Registry`. |
| Modelagem | Inspirada em Fishjam/Membrane: Room, Participant/Peer, Track, Subscription, metadados e lifecycle explícito. |
| Integração com o chat | Novo contexto `RetroHexChat.GroupCall`; não esticar `RetroHexChat.Lobby`, que é 1:1. |
| Criptografia | DTLS-SRTP em cada perna WebRTC. O SFU termina mídia, então não é E2E browser-to-browser. |
| MVP | Chamada por canal, uma chamada ativa por canal, limite configurável com alvo inicial 100, primeiros testes com 4 e escala progressiva, VP8 + Opus, sem simulcast, sem gravação, sem datachannel. |

### 1.1 Decisões fechadas em 2026-07-09

| Tema | Decisão |
|---|---|
| Escopo da chamada | Sempre por canal. Não há chamada em grupo por PM/ad-hoc no escopo atual. |
| Cardinalidade | Uma chamada ativa por canal. |
| Signaling | Phoenix Channel dedicado, não LiveView. |
| Banco | Modelagem persistida completa antes do SFU de produto. |
| UI | Botão ao lado do toggle Chat/Space do canal; clique abre uma janela Windows com quem entrou na chamada. |
| Métricas completas | Última fase da implementação. Antes disso, só logs/inspeção mínima para desenvolvimento. |
| Track | Persistir lifecycle completo das tracks. |
| Moderação | Todos podem falar inicialmente; admins/moderadores do canal podem silenciar, kickar e moderar como em um canal normal. |
| Limite inicial | `GROUP_CALL_MAX_PARTICIPANTS=100`, configurável. Testar primeiro com 4 para validar o caminho, depois escalar progressivamente até o alvo. |
| Reconnect | 30 segundos. Cobre refresh/troca rápida de rede sem segurar recursos por tempo demais. |
| UDP/infra | Configuração operacional fica para a etapa de infraestrutura, depois do produto base. |

### 1.2 Postura de implementação

O limite 100 não é decorativo. Mesmo que os primeiros testes reais comecem com
4 pessoas, o código deve nascer com desenho de SFU sério:

- RTP e RTCP não podem passar por banco, logs verbosos ou estruturas caras no
  hot path;
- o forwarding precisa usar mapas e ids pré-resolvidos, sem buscas lineares por
  pacote;
- updates persistidos de `Track` e `Participant` devem acontecer em eventos de
  lifecycle, não por pacote de mídia;
- renegociação precisa ser serializada por peer, com queue explícita como no
  Nexus;
- fanout, payload de signaling e renderização da janela devem ser medidos com
  benchmarks e testes de carga progressivos;
- quando houver dúvida entre uma implementação fácil e uma referência mais
  robusta, escolher a referência mais robusta e validar com benchmark.

O espírito da implementação é: começar pequeno para validar, mas construir como
se o limite 100 fosse real, porque ele será testado na prática.

O ponto importante: a implementação não deve ser uma abstração genérica de
"WebRTC". Ela precisa ser um domínio de chamada em grupo, com modelagem própria.
O WebRTC é o protocolo de transporte; o produto é a sala de chamada, os
participantes, as trilhas, permissões, estados e eventos de UI.

## 2. Repositórios checkoutados em `~/src`

| Repo local | Upstream | Commit | Uso nesta análise |
|---|---:|---:|---|
| `/Users/rodrigo/src/ex_webrtc` | <https://github.com/elixir-webrtc/ex_webrtc> | `9d4b689` | Motor WebRTC para o SFU embutido. |
| `/Users/rodrigo/src/elixir-webrtc-apps` | <https://github.com/elixir-webrtc/apps> | `6998d3d` | Contém `nexus`, o exemplo SFU mais importante. |
| `/Users/rodrigo/src/ex_webrtc_dashboard` | <https://github.com/elixir-webrtc/ex_webrtc_dashboard> | `15333ec` | Observabilidade/debug de peer connections. |
| `/Users/rodrigo/src/live_ex_webrtc` | <https://github.com/elixir-webrtc/live_ex_webrtc> | `68f315a` | Referência LiveView/browser mais simples. |
| `/Users/rodrigo/src/fishjam` | <https://github.com/fishjam-dev/fishjam> | `b39cb00` | Modelagem de rooms, peers, tracks, lifecycle. |
| `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine` | <https://github.com/fishjam-cloud/membrane_rtc_engine> | `7cd344a` | Modelagem RTC Engine, Endpoint, Track, Subscription. Arquivado. |
| `/Users/rodrigo/src/ex_ice` | <https://github.com/elixir-webrtc/ex_ice> | `4049deb` | ICE usado por `ExWebRTC`. |
| `/Users/rodrigo/src/ex_rtp` | <https://github.com/elixir-webrtc/ex_rtp> | `a604fb3` | RTP usado por `ExWebRTC`. |
| `/Users/rodrigo/src/ex_rtcp` | <https://github.com/elixir-webrtc/ex_rtcp> | `c1fbd4c` | RTCP/PLI usado por `ExWebRTC`. |
| `/Users/rodrigo/src/ex_dtls` | <https://github.com/elixir-webrtc/ex_dtls> | `b88be4d` | DTLS usado por `ExWebRTC`. |
| `/Users/rodrigo/src/ex_sctp` | <https://github.com/elixir-webrtc/ex_sctp> | `2310433` | DataChannel/SCTP. Fora do MVP, mas útil depois. |
| `/Users/rodrigo/src/ex_stun` | <https://github.com/elixir-webrtc/ex_stun> | `a478203` | STUN, já existe uma dependência no Retro Hex Chat. |
| `/Users/rodrigo/src/ex_turn` | <https://github.com/elixir-webrtc/ex_turn> | `1914357` | TURN de referência. O Retro já tem implementação própria. |

Licenças verificadas nas referências principais: Apache-2.0. Quando copiarmos
estrutura ou blocos substanciais, manter atribuição/NOTICE compatível.

## 3. Leitura do estado atual do Retro Hex Chat

### 3.1 O que existe hoje

O projeto já tem chamada P2P entre dois usuários, coordenada por:

| Área | Arquivo | Observação |
|---|---|---|
| Domínio P2P infra | `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex` | Valida `offer`, `answer`, `ice-candidate` e expõe ICE servers. |
| Lobby 1:1 | `apps/retro_hex_chat/lib/retro_hex_chat/lobby/session_server.ex` | Estado fixo com `creator` e `peer`. |
| Persistência do lobby | `apps/retro_hex_chat/lib/retro_hex_chat/lobby/schema/session.ex` | `creator_id`, `peer_id`, status `pending/lobby/connected/...`. |
| Signaling/UI | `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex` | Relay browser-to-browser por PubSub. |
| Cliente WebRTC | `apps/retro_hex_chat_web/assets/js/hooks/lobby/lobby_webrtc_hook.js` | Um `RTCPeerConnection` browser-to-browser, com mídia + datachannels. |
| Supervisor app | `apps/retro_hex_chat/lib/retro_hex_chat/application.ex` | Já segue o padrão `Registry` + `Supervisor` por domínio. |

O `Lobby` atual não deve virar chamada em grupo. Ele tem premissas 1:1 no banco,
no processo, no protocolo e no hook JS:

- papeis fixos `creator` e `peer`;
- uma sessão sempre pertence a exatamente dois usuários;
- o browser cria offer/answer para outro browser;
- datachannels de arquivo/jogo passam pelo mesmo `RTCPeerConnection`;
- signaling atual filtra só `from != p2p.user_id`, sem servidor como endpoint
  WebRTC.

### 3.2 O que deve ser reaproveitado

| Reaproveitar | Como |
|---|---|
| Autenticação/identidade de nickname registrado | Chamada em grupo deve exigir usuário identificado no MVP. |
| `Presence.Tracker` e membership de canal | Entrada em chamada de canal deve depender de estar no canal. |
| `Channels.Policy` | Base para permitir join, kick/moderação e respeitar modos do canal. |
| Ignore list | Bloqueia convites diretos e pode ocultar convites de quem está ignorado. |
| `P2P.ice_servers/1` e configuração TURN/STUN | Reusar para browser; adicionar configuração própria para ICE do servidor SFU. |
| Padrão OTP do app | Novo `GroupCall.Supervisor`, registries e dynamic supervisors como os outros domínios. |
| UI windowed do chat | A chamada em grupo deve ser janela do desktop do chat, não página separada. |

### 3.3 O que não deve ser reaproveitado

| Não reaproveitar | Motivo |
|---|---|
| Tabela `lobby_sessions` | Modelagem 1:1. Vai produzir contornos frágeis para N participantes. |
| `Lobby.SessionServer` | Máquina de estado depende de dois participantes fixos e de single-offerer browser. |
| `LobbyWebRTCHook` | Ele é browser-to-browser e multiplexa datachannels; SFU precisa de outro hook. |
| PubSub `lobby:<token>` como sinal P2P | SFU precisa de browser-to-server, com servidor gerando offers e recebendo answers. |

## 4. Referência principal: Nexus

Local: `/Users/rodrigo/src/elixir-webrtc-apps/nexus`.

Arquivos mais relevantes:

| Arquivo | Função |
|---|---|
| `lib/nexus/room.ex` | GenServer da sala: peers prontos, peers pendentes, timeout, broadcast de join/leave. |
| `lib/nexus/peer.ex` | GenServer por browser: owns `ExWebRTC.PeerConnection`, tracks e forwarding RTP. |
| `lib/nexus/peer_supervisor.ex` | `DynamicSupervisor` para peers. |
| `lib/nexus_web/channels/peer_channel.ex` | Signaling por Phoenix Channel. |
| `assets/js/home.js` | Cliente browser: recebe offer do servidor, responde answer, manda ICE. |

### 4.1 Modelo de processo do Nexus

Nexus tem a peça que falta no Retro Hex Chat: um SFU pequeno e legível em
Elixir puro.

Fluxo:

1. Browser entra no canal Phoenix `peer:signalling`.
2. `PeerChannel` pede `Nexus.Room.add_peer(self())`.
3. `Room` cria um peer id e inicia `Nexus.Peer` no `PeerSupervisor`.
4. `Peer` cria um `ExWebRTC.PeerConnection`.
5. `Peer` cria SDP offer e envia ao browser.
6. Browser cria answer e manda de volta.
7. `Peer` aplica o answer, processa ICE e marca ready.
8. RTP recebido de um peer é encaminhado para os tracks de saída dos outros peers.

O desenho é simples:

```text
Phoenix Channel / LiveView
        |
        v
   RoomServer  <------ monitors peers
        |
        v
 PeerSupervisor
        |
        v
   PeerServer 1..N  ---- owns ---- ExWebRTC.PeerConnection 1..N
```

Esse é o blueprint que devemos copiar/adaptar.

### 4.2 O que copiar do Nexus quase diretamente

| Copiar | Adaptação para Retro Hex Chat |
|---|---|
| Separação `Room`/`Peer` | `RetroHexChat.GroupCall.RoomServer` e `PeerServer`. |
| Um processo por participante WebRTC | Cada browser conectado tem um `PeerServer` dono do `PeerConnection`. |
| Servidor como offerer | Browser nunca oferece para outro browser. O servidor emite `group_call_offer`. |
| `pending_peers` + timeout de ready | Evita peer zumbi que entrou mas não completou SDP/ICE. |
| `peer_pid_to_id` e monitor de processos | Room remove participante se o processo do peer morrer. |
| Queue de renegociação | Se já existe offer local pendente, eventos de join/leave ficam pendurados. |
| RTP forwarding por `PeerConnection.send_rtp/4` | Coração do SFU. |
| Mapeamento de RTCP PLI para o publisher | Quando viewer precisa de keyframe, encaminhar PLI para o peer fonte. |
| Configuração de `ice_port_range` | Essencial em produção para abrir faixa UDP previsível. |

### 4.3 O que não copiar do Nexus

| Não copiar | Motivo |
|---|---|
| Sala global única | O Retro precisa de múltiplas rooms, uma ativa por canal. |
| Peer id puramente randômico como identidade de produto | Precisamos de participant id + nickname registrado + role. |
| Ausência de persistência | O Retro precisa auditar lifecycle e permitir reconexão curta. |
| Ausência de policy | O Retro tem canais, ops, registered-only, ignore, bans e moderação. |
| UI demo única | O Retro precisa hook integrado ao chat desktop. |
| Google STUN hardcoded | Usar config existente de ICE/TURN e variáveis do release. |
| Sem modelo de room metadata | Precisamos título, escopo, cap, codec, timestamps, status. |

### 4.4 Detalhe de mídia no Nexus

O ponto de protocolo mais importante:

- cada peer tem tracks inbound para receber áudio/vídeo do browser;
- para cada outro peer, cria tracks outbound;
- quando chega `{:rtp, track_id, rid, packet}` do `ExWebRTC`, o peer identifica
  se é áudio ou vídeo e encaminha o pacote para os outbound tracks dos outros
  peers;
- `ExWebRTC` reescreve detalhes necessários como payload type e SSRC quando
  `send_rtp/4` é usado corretamente;
- quando um browser envia PLI para um outbound track, o SFU descobre quem é o
  publisher e manda `send_pli/3` no inbound video track dele.

Esse padrão deve ser copiado na essência. A diferença é que no Retro quem decide
o conjunto de subscribers deve ser a `RoomServer`, porque teremos policy,
mute, kick, talvez focus/viewport e, depois, active speaker.

## 5. Referência de motor: ExWebRTC

Local: `/Users/rodrigo/src/ex_webrtc`.

Arquivos e guias relevantes:

| Arquivo | Uso |
|---|---|
| `lib/ex_webrtc/peer_connection.ex` | API principal: offer/answer, ICE, transceivers, `send_rtp`, `send_pli`. |
| `lib/ex_webrtc/peer_connection/configuration.ex` | Configuração de ICE, codecs, portas, callbacks e features. |
| `lib/ex_webrtc/media_stream_track.ex` | Criação de tracks audio/video. |
| `guides/introduction/forwarding.md` | Guia direto para forwarding RTP, exatamente o nosso caso. |
| `guides/advanced/mastering_transceivers.md` | Direções e m-lines do SDP. |
| `guides/advanced/simulcast.md` | Útil depois; não usar no MVP. |
| `guides/advanced/debugging.md` | Dashboard e faixa UDP. |

### 5.1 Configurações que interessam

No `PeerConnection.start_link/1`, o `PeerServer` deve passar:

| Opção | Decisão |
|---|---|
| `controlling_process` | O próprio `PeerServer`. |
| `ice_servers` | STUN/TURN vindos da config do Retro. |
| `ice_port_range` | Config nova, por exemplo `50000..50100`. Não deixar aleatório em produção. |
| `ice_transport_policy` | `:all` por default; opção futura `:relay`. |
| `ice_ip_filter` | Útil para evitar IPs privados errados em deploy específico. |
| `host_to_srflx_ip_mapper` | Útil quando há NAT conhecido e IP público fixo. |
| `video_codecs` | MVP: VP8. |
| `audio_codecs` | MVP: Opus. |
| `rtcp_feedbacks` | Garantir PLI para vídeo. |

### 5.2 Constraints do MVP

| Constraint | Consequência |
|---|---|
| Sem simulcast outbound em `ExWebRTC` | MVP envia um encoding por publisher. |
| Sem bandwidth estimation automática | Não tentar adaptação sofisticada de qualidade no MVP. |
| DataChannel depende de SCTP | Não misturar arquivo/jogo no SFU de grupo agora. |
| Server termina mídia | Privacidade precisa ser explicada como SFU, não E2E. |

### 5.3 Dependências esperadas

No app `:retro_hex_chat`, adicionar:

```elixir
{:ex_webrtc, "~> 0.17.0"}
```

Para debug em dev, avaliar:

```elixir
{:ex_webrtc_dashboard, "~> 0.10", only: :dev}
```

Confirmar a versão final no momento da implementação, mas a análise foi feita
com o checkout `ex_webrtc` em `9d4b689`, equivalente à linha atual `0.17.x`.

## 6. Referência de modelagem: Fishjam e Membrane RTC Engine

Locais:

- `/Users/rodrigo/src/fishjam`
- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine`

Membrane RTC Engine está arquivado e não deve ser trazido como dependência nova.
Mesmo assim, a modelagem dele é boa: Engine liga Endpoints; Endpoints publicam
Tracks; outros Endpoints assinam Tracks.

### 6.1 Conceitos úteis do Membrane RTC Engine

| Conceito | Tradução para Retro Hex Chat |
|---|---|
| `Engine` | `GroupCall.RoomServer`, orquestrando mídia da room. |
| `Endpoint` | `GroupCall.PeerServer`, endpoint WebRTC de um participante. |
| `Track` | `GroupCall.Track`, áudio/vídeo/screen de um participante. |
| `Subscription` | Relação subscriber -> publisher track. Pode ser runtime no MVP. |
| Endpoint metadata | Nickname, role, muted state, client capabilities. |
| Track variants | Simulcast futuro: high/medium/low. Não no MVP. |
| Readiness | Participante não entra como conectado até SDP/ICE mínimo. |

### 6.2 Conceitos úteis do Fishjam

Fishjam traz uma camada de produto sobre o engine. Isso é exatamente o que o
Retro precisa, mas com UX de chat.

| Conceito Fishjam | O que copiar conceitualmente |
|---|---|
| `Room.Config` com `room_id`, `max_peers`, codec, timeouts | Config por call: max participants, codec, peerless timeout, reconnect timeout. |
| `Room.State` com peers, engine pid, components, last peer left | Estado runtime da call e encerramento quando vazia. |
| `Peer` com status `connected/disconnected`, metadata, tracks | Participante pode desconectar e voltar por alguns segundos. |
| `Track` app-level com id/type/metadata | Separar track de mídia do track do WebRTC. |
| Eventos `peer_added`, `peer_disconnected`, `track_added` | Eventos de UI e telemetria do Retro. |

### 6.3 O que não trazer de Fishjam/Membrane

| Não trazer | Motivo |
|---|---|
| Pipeline Membrane completo | Grande demais para o objetivo e o repo está arquivado. |
| REST API/server SDK do Fishjam | O Retro tem sessão LiveView/chat própria. |
| Components como HLS, recording, SIP, RTSP | Fora do MVP. |
| Webhooks | Futuro, se houver integração admin. |
| Clustering SFU multi-node | Começar single-node embutido. |

## 7. Modelagem alvo do Retro Hex Chat

### 7.1 Novo contexto

Criar contexto:

```text
RetroHexChat.GroupCall
RetroHexChat.GroupCall.Room
RetroHexChat.GroupCall.Participant
RetroHexChat.GroupCall.Track
RetroHexChat.GroupCall.Subscription
RetroHexChat.GroupCall.Policy
RetroHexChat.GroupCall.Queries
RetroHexChat.GroupCall.RoomServer
RetroHexChat.GroupCall.PeerServer
RetroHexChat.GroupCall.Supervisor
RetroHexChat.GroupCall.RoomSupervisor
RetroHexChat.GroupCall.PeerSupervisor
```

O nome do domínio deve ser `GroupCall`, não `SFU`, porque `SFU` é a estratégia
de mídia. Produto e persistência devem falar em chamada, sala e participante.

### 7.2 Entidades persistidas

#### `group_call_rooms`

Sala lógica da chamada.

| Campo | Tipo | Observação |
|---|---|---|
| `id` | bigint | PK. |
| `token` | string | Token público/opaque para signaling. Único. |
| `channel_name` | string | Nome canônico do canal (`#geral`). A chamada em grupo é sempre por canal. |
| `creator_nick_id` | integer | Referência ao registered nick quando existir. |
| `creator_nickname` | string | Snapshot para histórico. |
| `status` | string | `pending`, `open`, `active`, `closing`, `closed`, `expired`, `failed`. |
| `title` | string | Opcional, UI. |
| `max_participants` | integer | Limite configurável por room. Default/alvo inicial 100, ajustável depois dos testes reais. |
| `media_policy` | map | `audio`, `video`, `screen`, defaults, future flags. |
| `codec_policy` | map | `audio: opus`, `video: vp8`. |
| `ice_policy` | map | Flags de relay/all e porta/mapper efetivos. |
| `metadata` | map | Campos futuros sem migration imediata. |
| `started_at` | utc_datetime_usec | Primeiro participante connected ou chamada aberta. |
| `last_activity_at` | utc_datetime_usec | Para expiração/limpeza. |
| `closed_at` | utc_datetime_usec | Terminal. |
| `closed_reason` | string | `empty`, `host_closed`, `moderation`, `timeout`, `error`. |
| timestamps | utc_datetime_usec | Padrão Ecto. |

Índices:

- unique `token`;
- index `channel_name, status`;
- index `status, last_activity_at`;
- partial unique: uma chamada ativa por `channel_name` quando status in
  `pending/open/active`.

Estados:

```text
pending -> open -> active -> closing -> closed
                    |          |
                    v          v
                 failed      expired
```

Interpretação:

- `pending`: criada, ainda sem peer WebRTC pronto;
- `open`: visível e joinable;
- `active`: pelo menos um participante conectado à sala aberta;
- `closing`: teardown em andamento;
- `closed/expired/failed`: terminal.

#### `group_call_participants`

Participação de um usuário em uma room.

| Campo | Tipo | Observação |
|---|---|---|
| `id` | bigint | PK. |
| `room_id` | bigint | FK. |
| `registered_nick_id` | integer | Se identificado. MVP exige identificado. |
| `nickname` | string | Snapshot do nick no join. |
| `normalized_nickname` | string | Para lookup case-insensitive. |
| `channel_role_snapshot` | string | Role do usuário no canal no momento do join. Autoridade real é sempre recalculada pelo canal. |
| `status` | string | `invited`, `joining`, `connected`, `reconnecting`, `disconnected`, `left`, `kicked`, `failed`. |
| `peer_ref` | string | Id runtime do `PeerServer` atual. Muda em reconnect. |
| `media_state` | map | `audio_muted`, `video_muted`, `screen_sharing`, `deafened`, `server_audio_muted`, `muted_by`, `muted_at`. |
| `client_info` | map | Browser, capabilities, constraints aceitos. |
| `joined_at` | utc_datetime_usec | Join lógico. |
| `connected_at` | utc_datetime_usec | SDP/ICE conectado. |
| `last_seen_at` | utc_datetime_usec | Heartbeat/reconnect. |
| `disconnected_at` | utc_datetime_usec | Queda temporária. |
| `left_at` | utc_datetime_usec | Saída voluntária/terminal. |
| `closed_reason` | string | `left`, `kicked`, `socket_down`, `ice_failed`, etc. |
| timestamps | utc_datetime_usec | Padrão Ecto. |

Índices:

- index `room_id, status`;
- unique parcial `room_id, normalized_nickname` para participantes não-terminais;
- index `registered_nick_id, status`.

Estados:

```text
invited -> joining -> connected -> reconnecting -> connected
                         |             |
                         v             v
                    disconnected -> left
                         |
                         v
                      failed/kicked
```

Observação importante: `Participant` é identidade de produto. `PeerServer` é uma
conexão WebRTC runtime. Em reconnect, o participant pode continuar sendo o
mesmo, mas o peer process/peer connection muda.

#### `group_call_tracks`

Track lógico publicado por participante.

| Campo | Tipo | Observação |
|---|---|---|
| `id` | bigint | PK. |
| `room_id` | bigint | FK. |
| `participant_id` | bigint | FK publisher. |
| `kind` | string | `audio`, `video`. Futuro: `screen_audio`. |
| `source` | string | `microphone`, `camera`, `screen`. |
| `webrtc_track_id` | string | Id inbound recebido de `ExWebRTC`. |
| `stream_id` | string | MediaStream. |
| `mid` | string | M-line/transceiver quando disponível. |
| `rid` | string | Futuro simulcast. Null no MVP. |
| `status` | string | `announced`, `active`, `muted`, `ended`, `failed`. |
| `codec` | string | `opus`, `vp8`. |
| `metadata` | map | width/height/frame_rate/client label. |
| `started_at` | utc_datetime_usec | Quando ficou active. |
| `ended_at` | utc_datetime_usec | Quando terminou. |
| timestamps | utc_datetime_usec | Padrão Ecto. |

Índices:

- index `room_id, status`;
- index `participant_id, kind, source`;
- unique parcial `participant_id, kind, source` onde status in `announced/active/muted`.

Persistir o lifecycle completo de `Track`: anúncio, ativação, mute/unmute,
falha e encerramento. A tabela deve ser atualizada por eventos do `PeerServer`.
As decisões de forwarding ainda ficam em memória no MVP.

#### `group_call_subscriptions`

Relação entre quem assiste e qual track recebe. Recomendação: começar runtime
em memória e só persistir se precisarmos de auditoria/analytics.

Modelo lógico:

| Campo | Tipo | Observação |
|---|---|---|
| `room_id` | bigint | Room. |
| `subscriber_participant_id` | bigint | Quem recebe. |
| `publisher_participant_id` | bigint | Quem publica. |
| `track_id` | bigint | Track publicada. |
| `status` | string | `pending`, `active`, `paused`, `ended`. |
| `variant` | string | Futuro simulcast: `high/medium/low`. |

### 7.3 Estado runtime

#### `GroupCall.RoomServer`

Estado sugerido:

```elixir
%{
  room: %GroupCall.Room{},
  participants: %{
    participant_id => %{
      participant: %GroupCall.Participant{},
      peer_pid: pid() | nil,
      ready?: boolean(),
      tracks: %{track_id => track_state},
      subscriptions: MapSet.t(track_id)
    }
  },
  pending_participants: %{participant_id => timer_ref},
  peer_pid_to_participant_id: %{pid() => participant_id},
  tracks: %{track_id => track_state},
  timers: %{
    peerless: reference() | nil,
    cleanup: reference() | nil
  },
  config: %{
    max_participants: pos_integer(),
    ready_timeout_ms: pos_integer(),
    reconnect_timeout_ms: pos_integer(),
    peerless_timeout_ms: pos_integer()
  }
}
```

Responsabilidades:

- validar join/leave;
- iniciar e monitorar `PeerServer`;
- manter lista de participantes e tracks;
- aplicar policy de assinatura;
- mandar eventos de UI por PubSub/LiveView;
- decidir quando renegociar peers;
- encerrar sala vazia;
- persistir mudanças importantes de lifecycle.

#### `GroupCall.PeerServer`

Estado sugerido:

```elixir
%{
  room_id: integer(),
  room_token: String.t(),
  participant_id: integer(),
  nickname: String.t(),
  signal_pid: pid(),
  pc: pid(),
  pc_id: reference(),
  inbound_tracks: %{
    webrtc_track_id => %{track_id: integer(), kind: :audio | :video, source: atom()}
  },
  outbound_tracks: %{
    {publisher_participant_id, track_id} => %{webrtc_track_id: String.t(), kind: atom()}
  },
  peer_tracks: %{
    publisher_participant_id => %{audio: track_state, video: track_state}
  },
  pending_negotiation: :none | :queued,
  signaling_state: atom(),
  connected?: boolean(),
  stats: map()
}
```

Responsabilidades:

- ser o `controlling_process` do `ExWebRTC.PeerConnection`;
- criar offer;
- aplicar answer;
- adicionar ICE candidates;
- criar transceivers/tracks;
- receber RTP inbound;
- encaminhar RTP outbound;
- receber RTCP PLI e pedir keyframe ao publisher;
- avisar `RoomServer` sobre track added/removed e connected/disconnected.

## 8. OTP supervision tree proposta

Adicionar em `RetroHexChat.Application`, perto dos domínios P2P/Lobby:

```elixir
{Registry, keys: :unique, name: RetroHexChat.GroupCall.RoomRegistry},
{Registry, keys: :unique, name: RetroHexChat.GroupCall.PeerRegistry},
RetroHexChat.GroupCall.Supervisor
```

`GroupCall.Supervisor`:

```text
RetroHexChat.GroupCall.Supervisor
  |
  +-- RetroHexChat.GroupCall.RoomSupervisor   DynamicSupervisor
  +-- RetroHexChat.GroupCall.PeerSupervisor   DynamicSupervisor
```

Registry keys:

| Registry | Key |
|---|---|
| `RoomRegistry` | `{:room, room_token}` and `{:channel, channel_name}`. |
| `PeerRegistry` | `{:peer, room_id, participant_id}`. |

API pública esperada:

```elixir
GroupCall.create_channel_call(channel_name, creator_session)
GroupCall.join_call(token, user_session, signal_pid)
GroupCall.leave_call(token, nickname)
GroupCall.answer(token, participant_id, sdp_answer)
GroupCall.add_ice_candidate(token, participant_id, candidate)
GroupCall.set_media_state(token, participant_id, media_state)
GroupCall.mute_participant(token, actor_session, participant_id)
GroupCall.unmute_participant(token, actor_session, participant_id)
GroupCall.close_call(token, actor_session, reason)
GroupCall.get_summary(token)
GroupCall.active_call_for_channel(channel_name)
```

## 9. Protocolo de signaling

### 9.1 Diferença essencial para o P2P atual

Hoje:

```text
Browser A <--- Phoenix/PubSub relay ---> Browser B
```

Com SFU:

```text
Browser A <--- signaling ---> Retro SFU PeerServer A
Browser B <--- signaling ---> Retro SFU PeerServer B
Browser C <--- signaling ---> Retro SFU PeerServer C
```

O servidor não é só relay de JSON. Ele é participante WebRTC em cada conexão.

### 9.2 Eventos sugeridos

Browser -> servidor:

| Evento | Payload |
|---|---|
| `group_call_join` | `{token, media_constraints, client_info}` |
| `group_call_answer` | `{token, participant_id, sdp}` |
| `group_call_ice_candidate` | `{token, participant_id, candidate}` |
| `group_call_leave` | `{token}` |
| `group_call_media_state` | `{audio_muted, video_muted, screen_sharing}` |
| `group_call_request_keyframe` | `{track_id}` opcional, se necessário. |

Servidor -> browser:

| Evento | Payload |
|---|---|
| `group_call_joined` | `{room, participant, participants}` |
| `group_call_offer` | `{sdp, ice_servers, participant_id}` |
| `group_call_ice_candidate` | `{candidate}` |
| `group_call_peer_joined` | `{participant}` |
| `group_call_peer_left` | `{participant_id, reason}` |
| `group_call_track_added` | `{track, participant_id}` |
| `group_call_track_removed` | `{track_id}` |
| `group_call_renegotiate` | Pode ser implícito via novo `group_call_offer`. |
| `group_call_error` | `{code, message}` |

### 9.3 Transporte de signaling

Decisão: usar Phoenix Channel dedicado.

Canal:

```text
group_call:<token>
```

Motivos:

- isola signaling pesado de mídia do `ChatLive`;
- fica mais próximo do Nexus, que já usa Phoenix Channel;
- mantém a janela do chat como UI, sem transformar o LiveView root em media router;
- facilita reconnect do hook sem depender do lifecycle completo do LiveView.

O `ChatLive` continua responsável por exibir o botão ao lado do toggle
Chat/Space, abrir a janela Windows da chamada e renderizar estado resumido. O
Phoenix Channel dedicado fica responsável por SDP, ICE, join, leave, track
events e erros de mídia.

## 10. Fluxo completo de uma chamada

### 10.1 Criar chamada em canal

1. Usuário no canal clica o botão de chamada ao lado do toggle Chat/Space.
2. `GroupCall.Policy.can_create_channel_call?/2` valida:
   - usuário identificado;
   - usuário está no canal;
   - usuário tem permissão conforme a policy do canal;
   - não há chamada ativa para o canal.
3. `GroupCall.create_channel_call/2` cria `group_call_rooms`.
4. `RoomSupervisor` inicia `RoomServer` para o token.
5. Chat publica mensagem de sistema no canal: chamada iniciada.
6. UI mantém o botão do canal em estado ativo.
7. Clique no botão abre/foca a janela Windows `group-call`.

### 10.2 Join do participante

1. Browser envia `group_call_join`.
2. `RoomServer` valida policy e limite.
3. Persiste/atualiza `Participant` como `joining`.
4. `PeerSupervisor` inicia `PeerServer`.
5. `PeerServer` cria `ExWebRTC.PeerConnection`.
6. `PeerServer` cria transceivers de entrada para áudio/vídeo do browser.
7. `PeerServer` adiciona outbound tracks para publishers já existentes.
8. `PeerServer` cria offer.
9. Browser aplica offer, adiciona tracks locais, cria answer e manda `group_call_answer`.
10. `PeerServer` aplica answer.
11. ICE conecta.
12. `RoomServer` marca participant `connected` e anuncia para os outros.

### 10.3 Novo participante entra com sala já ativa

1. O novo `PeerServer` recebe outbound tracks dos publishers atuais.
2. Os `PeerServer`s antigos precisam receber outbound tracks para o novo
   publisher quando ele publicar áudio/vídeo.
3. Isso gera renegociação nos peers antigos.
4. Se um peer antigo está em `:have_local_offer`, a alteração entra em queue.
5. Quando o answer chega, aplica a próxima renegociação pendente.

Esse é um dos pontos para copiar cuidadosamente do Nexus. Sem a queue, join/leave
rápido em grupo tende a quebrar signaling state.

### 10.4 Encaminhamento RTP

Fluxo runtime:

```text
Browser publisher
  -> RTP
PeerServer publisher
  -> {:rtp, inbound_track_id, rid, packet}
RoomServer/PeerServer mapping
  -> subscribers
PeerServer subscriber
  -> PeerConnection.send_rtp(outbound_track_id, packet)
Browser subscriber
```

Regra MVP:

- enviar áudio/vídeo de cada publisher para todos os outros participantes
  conectados;
- não enviar mídia do participante para ele mesmo;
- se participante está muted, parar de publicar ou marcar track muted;
- se participante está deafened no futuro, pausar subscriptions dele.

### 10.5 PLI/keyframe

Fluxo:

1. Browser subscriber precisa de keyframe.
2. Envia RTCP PLI no outbound track que recebe.
3. `PeerServer subscriber` recebe PLI de `ExWebRTC`.
4. Mapeia outbound track -> publisher participant/track.
5. Pede ao `PeerServer publisher` para enviar PLI no inbound video track.
6. Publisher browser emite keyframe.

Copiar a estratégia do Nexus.

## 11. Policy e segurança

### 11.1 MVP de permissões

| Ação | Regra MVP |
|---|---|
| Criar chamada em canal | Usuário identificado e presente no canal. |
| Entrar em chamada de canal | Usuário identificado e presente no canal. |
| Fechar chamada | Mesma autoridade de moderação do canal. |
| Kick da chamada | Mesma autoridade de kick do canal, usando `Channels.Policy.can_kick?/3`. |
| Silenciar participante | Mesma autoridade de moderação do canal. |
| Falar/publicar mídia | Todos os participantes da chamada podem falar inicialmente, salvo se silenciados por moderação. |
| Max participants | Configurável por room/env. Alvo inicial 100; primeiros testes com 4 e escala progressiva. |
| Guest | Fora do MVP. |

Não há uma autoridade paralela de "host da chamada" no MVP. O criador aparece
como iniciador no histórico, mas moderação segue o canal: quem modera o canal
pode silenciar, kickar e encerrar conforme as mesmas regras de autoridade.

### 11.2 Privacidade

Com SFU, o servidor recebe e reenvia mídia. Isso é normal para chamada em grupo,
mas muda a promessa do P2P:

- P2P atual: mídia browser-to-browser quando ICE permite.
- SFU: mídia browser-to-server-to-browser sempre.

O UI/help deve usar linguagem clara: "chamada em grupo via servidor", não
"chamada P2P em grupo". DTLS-SRTP protege as pernas de transporte, mas o
servidor consegue processar mídia. E2EE real seria fase futura com SFrame ou
insertable streams, com limitações grandes para SFU.

### 11.3 Rate limit

Reusar a lógica de rate limit para signaling como base, mas criar chaves novas:

```text
group_call:join:<nickname>
group_call:signal:<participant_id>
group_call:create:<channel>:<nickname>
```

Sem isso, ICE candidate flood ou join/leave loop pode afetar o BEAM.

## 12. Configuração de deploy

Novas variáveis sugeridas:

| Env | Exemplo | Uso |
|---|---|---|
| `GROUP_CALL_ENABLED` | `true` | Feature flag. |
| `GROUP_CALL_MAX_PARTICIPANTS` | `100` | Default/alvo inicial configurável por room; testar primeiro com 4 e escalar progressivamente. |
| `GROUP_CALL_READY_TIMEOUT_MS` | `10000` | Join pendente. |
| `GROUP_CALL_RECONNECT_TIMEOUT_MS` | `30000` | Reconexão curta. |
| `GROUP_CALL_PEERLESS_TIMEOUT_MS` | `60000` | Fechar sala vazia. |
| `SFU_ICE_PORT_RANGE` | `50000-50100` | Faixa UDP do servidor. |
| `SFU_PUBLIC_IP` | `203.0.113.10` | Mapper host -> srflx quando aplicável. |
| `SFU_ICE_TRANSPORT_POLICY` | `all` | Futuro: `relay`. |
| `SFU_VIDEO_CODEC` | `vp8` | MVP. |
| `SFU_AUDIO_CODEC` | `opus` | MVP. |

Ponto operacional: "sem subir outro servidor" não significa "sem abrir portas".
O mesmo release vai precisar de uma faixa UDP exposta para ICE do `ExWebRTC`,
além do HTTP/WebSocket e do TURN existente. A configuração fina de UDP/infra
fica para a etapa de infraestrutura, depois do produto base, mas a aplicação já
deve nascer aceitando essas variáveis.

## 13. UI e cliente browser

Criar hook novo, não adaptar `LobbyWebRTCHook`:

```text
apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js
```

Responsabilidades:

- criar um `RTCPeerConnection` contra o servidor SFU;
- receber `group_call_offer`;
- adicionar tracks locais;
- criar `answer`;
- enviar ICE candidates;
- renderizar remote tracks por participant/track;
- manter estado local de mute/camera;
- receber eventos do Phoenix Channel dedicado;
- notificar a UI local sobre estado resumido e erros.

Diferenças para o hook P2P:

| P2P Lobby Hook | GroupCall Hook |
|---|---|
| Browser offerer/answerer entre dois usuários. | Servidor sempre offerer. |
| Um peer remoto. | N peers remotos recebidos do SFU. |
| Datachannels de arquivo/jogo. | Sem datachannel no MVP. |
| Feature multiplexada. | Apenas mídia de chamada em grupo. |
| Sessão 1:1. | Room com participantes/tracks. |

Superfície UI:

- botão de chamada fica ao lado do toggle Chat/Space da janela do canal;
- botão inativo cria/entra na chamada do canal;
- botão ativo abre ou foca a janela Windows `group-call`;
- janela `group-call` mostra a comunicação e somente quem entrou na chamada;
- participantes conectados exibem mídia e estado de mute/camera;
- admins/moderadores do canal têm ações para silenciar ou remover participante
  da chamada;
- a chamada continua sendo por canal, não por PM e não global.

## 14. Observabilidade e testes

### 14.1 Observabilidade

Métricas completas ficam para a última fase da implementação. Antes disso, o
necessário é instrumentação mínima para depurar o SFU durante desenvolvimento:

- logs estruturados para join/leave/answer/ICE failure;
- inspeção via `ex_webrtc_dashboard` em dev;
- contadores locais temporários quando ajudarem a validar forwarding.

Na fase final, adicionar métricas PromEx:

| Métrica | Tipo |
|---|---|
| rooms ativas | gauge |
| participants connected | gauge |
| peer connections by state | gauge |
| RTP packets forwarded | counter |
| RTCP PLI forwarded | counter |
| renegotiations | counter |
| join failures by reason | counter |
| ICE failures | counter |

Em dev, integrar `ex_webrtc_dashboard` para inspecionar peer connections desde
cedo, mesmo antes das métricas completas.

### 14.2 Testes

Camadas:

| Camada | Testes |
|---|---|
| Unit | changesets, policy, state transitions de Room/Participant/Track. |
| GenServer | RoomServer join/leave, timeout, monitor DOWN, reconnect. |
| PeerServer com mocks | answer/ICE/track events sem browser real. |
| Integração local | 2 e 4 browsers Playwright entrando numa call, depois carga progressiva. |
| Network | ICE conectado via host e via TURN quando aplicável. |
| UI | mute/camera/leave/kick e grid sem quebrar layout. |

Para RTP real, começar com teste manual/dev usando dois browsers e dashboard,
subir para 4, e então executar os degraus de benchmark/carga. Automatizar mídia
WebRTC em CI depois que o MVP estiver estável.

### 14.3 Benchmarks obrigatórios

Benchmarks entram antes da liberação do grupo real. Eles não substituem métricas
de produção, mas impedem que o SFU nasça com gargalos óbvios.

| Benchmark | O que medir |
|---|---|
| Fanout de tracks | Custo de calcular subscribers e outbound tracks para 4/10/25/50/100 participantes. |
| Roteamento RTP | Overhead do caminho `inbound_track_id -> subscribers -> send_rtp`, sem browser. |
| Renegociação | Tempo e mailbox ao adicionar/remover participantes em sequência. |
| Signaling join burst | Payload e latência quando vários peers entram perto do mesmo tempo. |
| Persistência lifecycle | Custo de persistir room/participant/track sem tocar no hot path de RTP. |
| UI payload | Tamanho dos eventos enviados à janela `group-call` para 4/10/25/50/100 participantes. |

Referências de comparação:

- Nexus para o desenho Room/Peer e queue de renegociação;
- guias de forwarding do `ExWebRTC` para manter RTP fora de abstrações caras;
- Fishjam/Membrane para separar lifecycle de produto do hot path de mídia.

## 15. Matriz "copiar vs inspirar"

| Origem | Copiar | Inspirar | Não usar |
|---|---|---|---|
| Nexus | Room/Peer process split, server-offer, RTP forwarding, PLI routing, pending peers, renegotiation queue. | Estrutura de signaling e cliente JS simples. | Sala única, ausência de auth/persistência, STUN hardcoded. |
| ExWebRTC | API via dependência Hex, uso de `send_rtp`, `send_pli`, transceivers, `ice_port_range`. | Guias de forwarding/debugging. | Simulcast no MVP, datachannel no MVP. |
| Fishjam | Vocabulário Room/Peer/Track, configs, timeouts, disconnected peer. | Eventos e lifecycle de produto. | REST/server SDK, components, cloud/multi-node. |
| Membrane RTC Engine | Modelo Endpoint/Track/Subscription. | Separar media engine de produto. | Dependência/pipeline Membrane, repo arquivado. |
| Retro Lobby P2P | ICE config, rate limit, UX windowed, integração com chat. | Mensagens de sistema e padrões de lifecycle. | Banco 1:1, hook WebRTC P2P, SessionServer 1:1. |

## 16. Fases propostas

### F0 - Documento e decisão

Este documento.

Aceite:

- referências clonadas;
- arquitetura escolhida;
- modelagem alvo revisada antes de código.

### F1 - Modelagem persistida completa

Objetivo: introduzir o domínio certo antes do SFU de produto.

Entregas:

- migrations `group_call_rooms`, `group_call_participants`, `group_call_tracks`;
- changesets e queries;
- policy baseada nas permissões do canal;
- lifecycle completo de room, participant e track;
- unique parcial de uma chamada ativa por canal;
- limpeza de rooms vazias/expiradas.

### F2 - Spike SFU embutido mínimo sobre o banco real

Objetivo: provar `ExWebRTC` dentro do Retro Hex Chat com dois browsers usando o
contrato persistido de F1.

Entregas:

- adicionar dependência `ex_webrtc`;
- criar `GroupCall.Supervisor`, registries e supervisors;
- implementar `RoomServer`/`PeerServer` mínimo copiando a essência do Nexus;
- criar Phoenix Channel `group_call:<token>`;
- hook JS mínimo usando o channel dedicado;
- áudio/vídeo 2 participantes via SFU;
- persistir lifecycle de participantes e tracks durante o teste.

### F3 - UI de canal no ChatLive

Objetivo: produto usável em canal.

Entregas:

- botão de chamada ao lado do toggle Chat/Space;
- criar/entrar/focar chamada pelo botão;
- janela Windows `group-call`;
- lista de participantes que entraram na chamada;
- grade de mídia dos participantes conectados à chamada;
- participantes conectando/desconectando;
- leave/close/kick/mute.

### F4 - Grupo real com alvo 100 configurável

Objetivo: estabilizar join/leave/renegociação para mais de dois participantes,
começando com 4 usuários reais e escalando progressivamente até o alvo
configurável de 100.

Entregas:

- forwarding N:N;
- queue de renegociação;
- PLI routing;
- reconexão curta;
- testes com 4 browsers;
- testes progressivos 4 -> 10 -> 25 -> 50 -> 100 quando a infra permitir;
- benchmarks de fanout/roteamento de tracks no BEAM;
- benchmarks de payload de signaling em join/leave;
- inspeção de CPU, memória, mailbox e reduções dos `PeerServer`s;
- proteções de backpressure/limites por publisher se os dados mostrarem necessidade.

### F5 - Hardening de produto e policy

Objetivo: tornar seguro de operar.

Entregas:

- rate limit;
- enforcement do limite configurável;
- moderação seguindo policy do canal;
- logs estruturados;
- testes de falha ICE;
- documentação de uso e comportamento de privacidade.

### F6 - Infra UDP e métricas completas

Objetivo: fechar a operação em produção.

Entregas:

- `SFU_ICE_PORT_RANGE`;
- `SFU_PUBLIC_IP`/mapper quando necessário;
- documentação de portas UDP;
- dashboard em dev;
- PromEx/métricas completas;
- testes de deploy com NAT/TURN;
- documentação operacional.

### F7 - Recursos futuros

Fora do MVP:

- screen share;
- active speaker;
- simulcast/SVC se o stack suportar bem;
- layout/viewport-aware subscriptions;
- gravação;
- SIP/HLS;
- E2EE com insertable streams/SFrame;
- cluster/multi-node.

## 17. Riscos

| Risco | Mitigação |
|---|---|
| CPU/banda no mesmo servidor do chat | Código desenhado para alvo 100, testes progressivos com benchmark e ajuste do limite com dados reais. |
| UDP/ICE difícil em deploy | Deixar aplicação configurável desde o início e fechar infra em F6. |
| Renegociação quebrando com join/leave rápido | Copiar queue do Nexus e testar com 4 browsers antes da escala progressiva. |
| Misturar P2P 1:1 e SFU no mesmo código | Novo contexto `GroupCall`, hook novo. |
| Privacidade confundida com P2P | UI/help explícitos: SFU server-relayed. |
| Membrane/Fishjam parecerem tentadores demais | Usar só modelagem; não trazer pipeline arquivado. |
| Browser incompatível com codec | MVP VP8/Opus; fallback H264 só se necessário depois. |

## 18. Decisões de escopo fechadas

| Tema | Decisão |
|---|---|
| Escopo | Sempre por canal. |
| Cardinalidade | Uma chamada ativa por canal. |
| Limite inicial | `GROUP_CALL_MAX_PARTICIPANTS=100`, configurável; primeiros testes com 4 e escala progressiva. |
| Signaling | Phoenix Channel dedicado. |
| Banco | Completo antes do SFU de produto. |
| UI | Botão ao lado do toggle Chat/Space, abrindo janela Windows `group-call`. |
| Track | Lifecycle completo persistido. |
| Moderação | Todos podem falar inicialmente; admins/moderadores do canal podem silenciar, kickar e encerrar conforme permissões do canal. |
| Reconnect | 30 segundos. |
| Métricas completas | Última fase. |
| UDP/infra | Configurar depois, em fase própria de infraestrutura. |
| Eventos no chat | Persistir start/end/kick; não persistir todo mute/unmute. |
| Guest | Não entra no MVP. |
| Datachannels | Não reutilizar para chamadas em grupo. Arquivo/jogo continuam no P2P 1:1 por enquanto. |

## 19. Próximo passo técnico

Implementar F1 em branch pequena:

1. criar migrations `group_call_rooms`, `group_call_participants` e
   `group_call_tracks`;
2. criar schemas e changesets;
3. criar `GroupCall.Policy` usando as permissões do canal;
4. criar queries para chamada ativa por canal;
5. criar testes de lifecycle e unique parcial;
6. só então portar/adaptar `Nexus.Peer` e `Nexus.Room` para o SFU embutido.

O banco vem antes porque agora a chamada é produto de canal, não apenas spike
de protocolo. A implementação SFU deve encaixar no lifecycle persistido desde
o primeiro commit funcional.
