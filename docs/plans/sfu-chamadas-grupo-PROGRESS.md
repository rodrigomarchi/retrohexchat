# SFU chamadas em grupo — progresso e aprendizados

> Diario de execucao do plano `sfu-chamadas-grupo-referencias.md`.
> Este arquivo registra o que foi implementado, decisoes aplicadas,
> desvios e aprendizados. Atualizar ao final de cada bloco de trabalho.

## Status por fase

| Fase | Descricao | Status |
|---|---|---|
| F0 | Plano, decisoes fechadas e leitura de contexto | CONCLUIDA (2026-07-09) |
| F1 | Modelagem persistida: rooms, participants, tracks, policy, queries e testes | CONCLUIDA (2026-07-09) |
| F2 | Spike SFU minimo com ExWebRTC, RoomServer, PeerServer e Phoenix Channel | CONCLUIDA (MVP, 2026-07-10) |
| F3 | UI integrada no ChatLive com janela `group-call` | CONCLUIDA (MVP, 2026-07-10) |
| F4 | Grupo N:N, renegociacao serializada, PLI, reconnect e escala | EM ANDAMENTO (lifecycle/reconnect, 2026-07-10) |
| F5 | Hardening de produto, limites, rate limit, moderacao e docs | EM ANDAMENTO (rate limit/moderacao, 2026-07-10) |
| F6 | Infra UDP, public IP mapper, metricas e deploy | EM ANDAMENTO (app config/metricas, 2026-07-10) |
| F7 | Futuro: screen share, active speaker, simulcast, recording, cluster | NAO INICIADA |

## Trabalho atual

### 2026-07-09 — inicio da F1

- Base Git conferida em `main`; `origin/main` estava atualizado via `git fetch`
  e `git pull --ff-only origin main` antes de iniciar alteracoes.
- Criado este diario de progresso.
- Criado o prompt de retomada em `sfu-chamadas-grupo-RESUME-PROMPT.md`.
- Escopo imediato: implementar apenas a F1, sem adicionar `ExWebRTC` ainda.

### 2026-07-09 — F1 concluida

- Criada a migration `20260709120000_create_group_call_tables.exs` com:
  - `group_call_rooms`;
  - `group_call_participants`;
  - `group_call_tracks`;
  - indices parciais para uma chamada ativa por canal, um participante ativo
    por nickname/room e uma track ativa por participante/kind/source.
- Criados schemas:
  - `RetroHexChat.GroupCall.Schema.Room`;
  - `RetroHexChat.GroupCall.Schema.Participant`;
  - `RetroHexChat.GroupCall.Schema.Track`.
- Criados:
  - `RetroHexChat.GroupCall`;
  - `RetroHexChat.GroupCall.Queries`;
  - `RetroHexChat.GroupCall.Policy`.
- `GroupCall.Policy` reutiliza membership e autoridade de moderacao do canal:
  criar/entrar exige usuario registrado e membro do canal; fechar/moderar segue
  roles de moderacao do canal, sem papel separado de host da chamada.
- Testes adicionados:
  - schemas e lifecycle terminal;
  - queries e constraints parciais;
  - policy de criacao, entrada e moderacao.
- Verificacoes executadas:
  - `mix format --check-formatted`: ok;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`: 29 testes,
    0 falhas;
  - `make test`: dominio 2690 testes + 15 properties, web 722 testes,
    0 falhas;
  - `make credo`: strict, 0 issues.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — F2 backend/channel iniciado

- Adicionada dependencia `{:ex_webrtc, "~> 0.17.0"}` em
  `apps/retro_hex_chat/mix.exs`.
- Atualizado `ex_stun` de `0.2.0` para `0.2.1` no lock para resolver a cadeia
  `ex_webrtc -> ex_ice -> ex_stun ~> 0.2.1`.
- Adicionadas configs runtime:
  - `GROUP_CALL_ENABLED`;
  - `GROUP_CALL_MAX_PARTICIPANTS`;
  - `GROUP_CALL_READY_TIMEOUT_MS`;
  - `GROUP_CALL_RECONNECT_TIMEOUT_MS`;
  - `GROUP_CALL_PEERLESS_TIMEOUT_MS`;
  - `SFU_ICE_PORT_RANGE`;
  - `SFU_ICE_TRANSPORT_POLICY`.
- Registradas na supervision tree:
  - `RetroHexChat.GroupCall.RoomRegistry`;
  - `RetroHexChat.GroupCall.PeerRegistry`;
  - `RetroHexChat.GroupCall.Supervisor`.
- Criados runtime modules:
  - `GroupCall.Config`;
  - `GroupCall.JoinToken`;
  - `GroupCall.Registry`;
  - `GroupCall.Supervisor`;
  - `GroupCall.RoomSupervisor`;
  - `GroupCall.PeerSupervisor`;
  - `GroupCall.RoomServer`;
  - `GroupCall.PeerServer`.
- Expandida a fachada `RetroHexChat.GroupCall` com:
  - `create_channel_call/3`;
  - `ensure_room_server/1`;
  - `join_call/5`;
  - `leave_call/3`;
  - `answer/3`;
  - `add_ice_candidate/3`;
  - `set_media_state/3`;
  - `get_summary/1`.
- Criado Phoenix Channel dedicado `RetroHexChatWeb.GroupCallChannel` e registrado
  `channel "group_call:*"` no `UserSocket`.
- Criado hook JS minimo `GroupCallWebRTCHook`, carregado como lazy feature:
  - abre `/socket`;
  - entra em `group_call:<token>` com `JoinToken`;
  - recebe `group_call_offer`;
  - cria `RTCPeerConnection`;
  - captura midia local quando permitido;
  - envia `group_call_answer`;
  - troca ICE via `group_call_ice_candidate`.
- Atualizado `.env.example` com as variaveis SFU.
- Testes adicionados:
  - runtime: criar chamada por canal, negar usuario fora do canal, join gerar
    participante e offer SDP;
  - channel: token obrigatorio, token de outra sala rejeitado, join aceito com
    `group_call_joined` e `group_call_offer`.
- Verificacoes executadas:
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`:
    dominio 32 testes, web 3 testes, 0 falhas;
  - `make test`: dominio 2693 testes + 15 properties, web 725 testes,
    0 falhas;
  - `make credo`: strict, 0 issues.
- `mix compile --warnings-as-errors` ainda nao e gate limpo por causa do warning
  pre-existente `RetroHexChat.P2P.Registry.registry_name/0` em
  `RetroHexChatWeb.Admin.AppInfoPage`.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — F3 UI integrada no ChatLive

- Lidas as regras de agente em `/Users/rodrigo/.codex/RTK.md`; todos os
  comandos shell desta etapa usaram prefixo `rtk`.
- Revisados os padroes de `docs/AGENT-GUIDE.md` para janelas desktop:
  - `Windows.open/2` continua sendo o unico opener;
  - janelas com WebRTC/hook que precisam sobreviver a hide/show ficam montadas
    enquanto a sessao existe;
  - eventos de tela ficam em modulos dedicados registrados em
    `@event_hook_fns` e `attach_all_hooks/1`.
- Criado `RetroHexChatWeb.ChatLive.GroupCallEvents`:
  - valida canal ativo, nick identificado e registered nick id;
  - cria chamada por canal ou entra na chamada ativa existente;
  - assina `GroupCall.JoinToken`;
  - abre/foca a janela `group-call`;
  - recebe eventos leves espelhados pelo hook (`joined`, `peer_joined`,
    `peer_left`, `media_state`, `track_added`, erros e connection state);
  - controla leave e toggles locais de audio/video.
- Criado `RetroHexChatWeb.ChatLive.Components.GroupCallPanel`:
  - janela com header, status, controles de microfone/camera/sair;
  - ancora `GroupCallWebRTCHook` em subtree `phx-update="ignore"`;
  - video local, area para videos remotos e lista de participantes;
  - indicadores de midia por participante.
- Atualizado `ChatLive`:
  - novo assign `:group_call`;
  - `GroupCallEvents` registrado no pipeline de hooks;
  - botao `Call` na topic bar de canais, ao lado de `Chat`/`Space`;
  - janela desktop `group-call` sempre montada enquanto `@group_call` existe,
    nao managed, para preservar o hook WebRTC em hide/show.
- Atualizado `GroupCallWebRTCHook`:
  - espelha eventos leves do Phoenix Channel para a LiveView;
  - reporta erros de join/signaling;
  - recebe `group_call_set_media_state` para alternar tracks locais e enviar
    `group_call_media_state` pelo canal;
  - estiliza videos remotos criados dinamicamente e oculta placeholder quando
    stream remoto chega.
- Testes adicionados:
  - `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs`;
  - cobre criacao pela topic bar, entrada de segundo usuario na sala ativa,
    eventos do hook populando participantes, toggle de audio e leave.
- Verificacoes executadas nesta etapa:
  - `mix format`: ok;
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    4 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`:
    3 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`:
    3 testes, 0 falhas;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok;
  - `make test`: dominio 2693 testes + 15 properties, web 725 testes,
    0 falhas;
  - `make credo`: strict, 0 issues.
- Observacao i18n:
  - `make i18n.gettext.check` foi executado e apontou catalogos Gettext fora
    de sync;
  - `make i18n.gettext.rebuild` passou, mas gerou centenas de mudancas em
    dominios/catalogos nao relacionados ao SFU;
  - para manter o bloco revisavel, essas mudancas geradas em `priv/gettext`
    foram descartadas e a atualizacao fina de catalogos fica como pendencia
    propria.
- Warning conhecido ainda aparece ao compilar/testar:
  `RetroHexChat.P2P.Registry.registry_name/0` em
  `RetroHexChatWeb.Admin.AppInfoPage`; ja existia antes desta etapa.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — F4 E2E browser e correcoes de runtime

- Criado teste Playwright `e2e/tests/chat-group-call.spec.ts`:
  - registra dois usuarios reais pelo fluxo de browser;
  - entra em um canal unico;
  - abre a chamada pelos botoes `Call` dos dois usuarios;
  - valida janela `group-call`, hook WebRTC montado, video remoto vivo nos dois
    lados, lista de participantes e saida de um participante.
- Atualizado setup global E2E:
  - `e2e/global-setup.ts` agora garante `ecto.create` e `ecto.migrate` em
    `MIX_ENV=e2e` antes de resetar a configuracao de registro;
  - isso corrigiu a primeira falha real do browser:
    `Postgrex.Error 42P01 relation "group_call_rooms" does not exist`.
- Falhas expostas e corrigidas pelo E2E:
  - deadlock/timeout entre `RoomServer` e `PeerServer` durante sinalizacao;
  - corrupcao de state no `RoomServer.leave_participant/4`, que retornava
    `:ok` depois de broadcast em vez do state atualizado;
  - corrida de entrada simultanea em que participantes ainda pendentes nao
    eram considerados para renegociacao/broadcast, deixando um lado sem video
    remoto.
- Ajustes aplicados:
  - `mark_ready`, `apply_sdp_answer` e `add_ice_candidate` passaram a usar
    casts assincronos para evitar chamadas circulares bloqueantes entre
    processos OTP;
  - `leave_participant/4` voltou a retornar state em todos os caminhos;
  - `RoomServer` passou a tratar participantes ativos como a uniao de
    `participants` e `pending_participants` para join, leave, broadcasts e
    renegociacao inicial.
- Verificacoes executadas nesta etapa:
  - `mix format`: ok;
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`:
    3 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`:
    3 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    4 testes, 0 falhas;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 1 teste, 0 falhas.
  - `make test`: dominio 2693 testes + 15 properties, web 725 testes,
    0 falhas;
  - `make credo`: strict, 0 issues.
- Warnings observados nos logs E2E, sem quebra do fluxo validado:
  - `Failed to create allocation, reason: 400. Closing client.`;
  - `Passed the same remote credentials to be set. Ignoring.`;
  - `Unable to protect RTP: :replay_fail`.
  Esses pontos ficam como hardening da F4/F5, porque o teste confirmou video
  remoto vivo nos dois sentidos.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — hardening de compilacao apos erro local

- Corrigido erro reportado em compilacao incremental:
  `ExWebRTC.RTPCodecParameters.__struct__/1 is undefined`.
- Causa aplicada:
  - o `PeerServer` usava `%ExWebRTC.RTPCodecParameters{}` em module
    attributes para configurar codecs;
  - isso exige expansao de struct em compile-time e pode quebrar em ambiente
    com dependencia ainda nao compilada/carregada pelo code reloader;
  - `ExWebRTC.PeerConnection.Configuration` aceita atoms de codecs e expande
    internamente.
- Ajustes aplicados:
  - `@audio_codecs` passou a `[:opus]`;
  - `@video_codecs` passou a `[:vp8]`;
  - a criacao de `SessionDescription` passou a usar `struct/2`, evitando
    expansao `%SessionDescription{}` no compile-time do nosso modulo;
  - o handler de PLI deixou de pattern-matchar `%ExRTCP.Packet.PayloadFeedback.PLI{}`
    diretamente e passou a checar `__struct__`;
  - timeout do teste de channel para `group_call_offer` subiu de 100ms para
    1000ms, porque o offer depende de processo WebRTC real e 100ms era fragil.
- Verificacoes executadas apos a correcao:
  - `mix format`: ok;
  - `mix compile --force`: ok;
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`:
    3 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`:
    3 testes, 0 falhas;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 1 teste, 0 falhas.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — correcao Window Manager da janela de conferencia

- Corrigido problema de UX/Window Manager reportado no teste manual:
  - a janela `group-call` era montada, mas nao tinha botao proprio na taskbar;
  - a primeira abertura tambem dependia do `window_command` chegar depois do
    patch que registrava a janela no `WindowManagerHook`.
- Ajustes aplicados:
  - `group-call` agora monta com `open` inicial verdadeiro, garantindo que a
    primeira entrada na chamada abre a janela mesmo se o evento client-side
    chegar antes do registro do DOM;
  - adicionada taskbar button `data-window-taskbar="group-call"` com
    `data-testid="group-call-taskbar"` enquanto `@group_call` existir;
  - o painel WebRTC continua sempre montado enquanto a chamada existe, entao
    hide/show da janela nao derruba o hook nem o canal de sinalizacao.
- Regressao adicionada:
  - LiveView verifica `data-window-initial-open="true"` e taskbar da chamada;
  - Playwright verifica taskbar visivel com o nome do canal e removida ao
    sair da chamada.
- Verificacoes executadas:
  - `mix format`: ok;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    4 testes, 0 falhas;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 1 teste, 0 falhas.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — UX de sessao ativa, confirmacoes e troca de conferencia

- Melhorado o fluxo de produto da janela `group-call`:
  - header da janela ganhou indicadores com icones para status, participantes
    e tracks;
  - toggles e lista de participantes agora alternam entre icones reais de
    mic/camera ligados e desligados (`icon_mute`, `icon_camera_off`);
  - taskbar continua exibindo a chamada enquanto a sessao existe.
- Adicionada indicacao global no status bar, paralela ao P2P:
  - `status-bar-group-call` mostra a chamada ativa e o canal;
  - clicar na area foca/reabre a janela `group-call`;
  - o botao vermelho do status bar abre confirmacao para sair da chamada.
- Adicionado dialogo `GroupCallConfirmDialog` com tres modos:
  - `:leave`: botao vermelho dentro da janela;
  - `:close`: X/menu/Escape da janela, avisando que fechar deixa a chamada;
  - `:switch`: ao clicar `Call` em outro canal, avisa que a conferencia atual
    sera encerrada antes de entrar na nova.
- Fluxo aplicado:
  - clicar `Call` no mesmo canal apenas foca a janela existente;
  - clicar `Call` em outro canal nao derruba nada automaticamente; abre
    confirmacao de troca;
  - confirmar troca encerra a chamada atual e entra na chamada do novo canal.
- Regressao adicionada:
  - `ChatShellTest` cobre a zona `status-bar-group-call`;
  - `GroupCallFlowTest` cobre status bar, cancelamento, confirmacao de saida e
    troca de conferencia;
  - Playwright cobre status bar, taskbar, dialogo de saida e teardown no browser.
- Verificacoes executadas:
  - `mix format`: ok;
  - `mix compile --force`: ok;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_shell_test.exs`:
    5 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    6 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 1 teste, 0 falhas.
  - `make test`: primeira execucao teve uma falha isolada de sandbox ownership
    em `AddressBookTest` durante `ChatLive.terminate/2`; o teste falho passou
    isolado e a segunda execucao completa passou: dominio 2693 testes + 15
    properties, web 726 testes, 0 falhas;
  - `make credo`: strict, 0 issues.
- Pendencia tecnica observada:
  - se o usuario troca de conferencia antes do hook concluir o join e gerar
    `participant_id`, ainda nao existe API dedicada para fechar a sala criada
    sem participante; isso deve entrar no hardening de lifecycle.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — E2E funcional dos botoes de mic/camera

- Reforcado o Playwright `e2e/tests/chat-group-call.spec.ts` para testar
  comportamento real, nao apenas presenca visual dos botoes:
  - apos abrir a conferencia com dois usuarios reais, o teste le o
    `MediaStreamTrack.enabled` de audio e video no `srcObject` do video local;
  - clica no botao de microfone, confirma que o track de audio local muda para
    `false`, e confirma na pagina do outro participante que o estado remoto
    `data-media-audio` virou `false`;
  - clica novamente e confirma audio local/remoto voltando para `true`;
  - repete o mesmo fluxo para camera/video com `data-media-video`;
  - o fluxo de saida continua exigindo dialogo de confirmacao e valida teardown
    da janela, taskbar, status bar e lista remota.
- A primeira execucao do E2E reforcado falhou corretamente:
  - o HEEx omitia `aria-pressed` quando o valor era `false`;
  - isso nao derrubava o track, mas quebrava o contrato de acessibilidade e
    deixava o estado do botao incompleto para regressao.
- Correcao aplicada:
  - `GroupCallPanel` agora renderiza `aria-pressed` como string explicita
    `"true"`/`"false"` nos toggles de microfone e camera.
- Verificacoes executadas:
  - `mix format`: ok;
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    6 testes, 0 falhas;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 1 teste, 0 falhas.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — F4/F5/F6 hardening local sem escala multi-browser

- Decisao de escopo aplicada:
  - removida do plano a obrigatoriedade imediata de testar/corrigir fluxo com
    4/10/25/50/100 browsers reais;
  - essa bateria fica adiada para uma janela operacional propria;
  - abertura de portas, firewall e infra externa ficam fora deste repo.
- F4 lifecycle/reconnect:
  - `RoomServer` agora aceita reconexao de participante `disconnected` dentro
    do timeout configurado, reutilizando o registro de produto;
  - participantes desconectados ganham timer de reconnect e viram terminal
    `failed` se o timeout expirar;
  - salas vazias agora recebem peerless timeout e fecham como `closed/empty`,
    evitando chamada ativa vazia bloqueando o canal;
  - tracks reais recebidas via `track_added` sao upsertadas por
    participant/kind/source;
  - tracks mudam para `muted`/`active` quando o media state muda e para `ended`
    no leave/kick/close.
- F5 produto/seguranca:
  - criado `RetroHexChat.GroupCall.RateLimiter` com limites separados para
    create, join e signaling;
  - `GroupCall.create_channel_call/3` aplica rate limit de criacao;
  - `GroupCallChannel` aplica rate limit em join/signaling (`answer`, ICE e
    `media_state`);
  - adicionadas APIs `close_call/3`, `kick_participant/3`,
    `mute_participant/3` e `unmute_participant/3`;
  - moderação reusa policy do canal: owner/operator/half-op conforme regra
    existente de kick/moderacao;
  - UI da conferencia ganhou controles de moderador: encerrar chamada com
    confirmacao, mutar/desmutar audio de participante e remover participante.
- F6 app config/metricas:
  - `SFU_PUBLIC_IP` agora configura `host_to_srflx_ip_mapper` do `ExWebRTC`
    quando definido;
  - adicionadas envs de rate limit no runtime e `.env.example`;
  - `RetroHexChatWeb.Telemetry` ganhou gauges/contadores de group call;
  - criada doc operacional local `docs/operations/group-call-sfu.md`, deixando
    claro que abertura de portas e NAT/TURN externo pertencem a outra tarefa.
- Ajustes no hook browser:
  - aceita `group_call_set_media_state` vindo do servidor para mute moderado;
  - espelha `group_call_track_updated`, `group_call_track_removed` e
    `group_call_closed` para a LiveView.
- Testes adicionados/reforcados:
  - `GroupCall.RateLimiterTest`;
  - query de track ativa por participant/kind/source;
  - runtime cobrindo lifecycle de track, mute, leave e fechamento peerless;
  - runtime cobrindo mute/kick/close por moderador;
  - channel cobrindo rate limit de signaling;
  - LiveView cobrindo visibilidade dos controles de moderação.
- Verificacoes executadas:
  - `mix format`: ok;
  - `mix compile`: ok, apenas warning pre-existente de
    `RetroHexChat.P2P.Registry.registry_name/0`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`: 38 testes,
    0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    11 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    dominio 38 testes, web 11 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 1 teste, 0 falhas;
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok.
- Validacao final apos retomada:
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    dominio 38 testes, web 11 testes, 0 falhas;
  - servidor alternativo local na porta 4100/UDP 13478 foi encerrado; servidor
    externo na porta 4000 foi preservado.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — Auditoria de padroes e autoridade de produto

- Auditoria executada sobre backend, UI, JS, testes e docs do bloco SFU.
- Achado corrigido em F5:
  - mute moderado era persistido, mas um cliente poderia mandar
    `group_call_media_state` com `audio=true` e reativar o proprio microfone;
  - `RoomServer` agora preserva `server_audio_muted` e forca `audio=false`
    enquanto o moderador nao desmutar;
  - `RuntimeTest` cobre a tentativa de burlar o mute moderado.
- Achado corrigido em UI:
  - `GroupCallPanel` concentrava markup da tela no LiveComponent, destoando do
    padrao do P2P em que a camada LiveView e cola de estado e a apresentacao
    fica em `components/ui`;
  - criado `RetroHexChatWeb.Components.UI.GroupCall.Panel`;
  - o painel foi decomposto em subcomponentes de header, superficie WebRTC,
    resumo local, lista/linha de participantes, indicadores e erro;
  - o LiveComponent `ChatLive.Components.GroupCallPanel` agora e apenas wrapper
    stateful com raiz estatica e delega a apresentacao.
- Ajuste de acessibilidade/consistencia:
  - `aria-pressed` do botao `Call` ficou string explicita;
  - comentario da janela foi atualizado para refletir que X/Leave confirmam a
    saida, em vez de apenas esconder a janela.
- Verificacoes executadas nesta auditoria:
  - `mix compile`: ok, apenas warning pre-existente de
    `RetroHexChat.P2P.Registry.registry_name/0`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`:
    5 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    7 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    dominio 38 testes, web 11 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 1 teste, 0 falhas;
  - `mix format --check-formatted`: ok;
  - `git diff --check`: ok.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — F4 N:N local com 3 browsers

- Prosseguimento local da F4 sem retomar a bateria adiada 4/10/25/50/100.
- Reforcado `e2e/tests/chat-group-call.spec.ts` com cenario N:N:
  - cria tres usuarios de conferencia com midia sintetica e nomes semanticos
    (`newGroupCallUser` / `closeGroupCallUsers`);
  - Alice e Bob entram primeiro e validam video remoto vivo;
  - Carol entra depois e cada browser precisa enxergar pelo menos dois videos
    remotos vivos;
  - Carol sai com confirmacao;
  - Alice e Bob continuam com video remoto vivo e a mudanca de camera do Bob
    continua propagando para Alice.
- Criados helpers `e2e/helpers/groupCallUsers.ts` e
  `e2e/helpers/syntheticMedia.ts` para nao vazar nomes de P2P no spec de
  conferencia. O teste fala na linguagem da feature atual
  (`newGroupCallUser` / `closeGroupCallUsers`) e a midia sintetica ficou
  generica.
- Atualizado `e2e/TEST_CATALOG.md`:
  - 332 testes Playwright;
  - novo fluxo N2 para renegociacao de chamada em grupo com tres usuarios.
- Verificacoes executadas:
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 2 testes, 0 falhas.
- Warnings ICE/SRTP continuam aparecendo no E2E e seguem como pendencia tecnica;
  agora tambem foi observado warning de PLI em cenario N:N.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — F4/F5 inspecao local, reconnect e falha ICE

- Fechada a lacuna de teste da reconexao curta no runtime:
  - participante desconectado por queda de `PeerServer` permanece
    `disconnected` dentro do timeout;
  - reentrada antes do timeout reutiliza o mesmo `participant.id`, limpa
    `disconnected_at`/`reason` e volta para `joining`;
  - se o timeout expira, o participante vira terminal `failed`;
  - tracks antigas terminam em `ended`, liberando a unique parcial de source.
- Adicionado teste especifico de falha ICE:
  - evento `connection_state_change: :failed` do `PeerServer` derruba o peer;
  - `RoomServer` agora registra `participant.reason` como
    `ice_connection_failed`, em vez de perder tudo como `peer_down`;
  - apos o reconnect timeout, o participante vira `failed`.
- Melhorados logs estruturados do bloco SFU:
  - `RoomServer` usa metadata de Logger para join negado, ready timeout,
    peer down e erros de track;
  - `PeerServer` usa metadata para erro de SDP answer e fechamento do
    `PeerConnection`;
  - `GroupCallChannel` registra join negado com `room_token`/`reason`.
- Criado `RetroHexChat.GroupCall.ScaleInspection`:
  - `run/2` gera linha de base deterministica para fanout N:N e payloads;
  - `fanout_plan/2` calcula rotas publisher/subscriber/track esperadas;
  - `payload_sizes/2` mede bytes JSON dos eventos UI/signaling da chamada;
  - `sample_peer_processes/0` amostra memoria, mailbox e reducoes dos
    `PeerServer`s vivos, retornando lista vazia quando o Registry nao esta
    iniciado para permitir `mix run --no-start`.
- Criado `ScaleInspectionTest` cobrindo:
  - cardinalidade do fanout;
  - crescimento de payload;
  - formatos de eventos medidos;
  - campos de pressao BEAM em processo registrado no `PeerRegistry`.
- Linha de base local via
  `mix run --no-start -e 'report = RetroHexChat.GroupCall.ScaleInspection.run([3, 10, 25, 50, 100]); ...'`:
  - 3 participantes: 12 rotas, `summary` 1402 bytes;
  - 10 participantes: 180 rotas, `summary` 4289 bytes;
  - 25 participantes: 1200 rotas, `summary` 10604 bytes;
  - 50 participantes: 4900 rotas, `summary` 21129 bytes;
  - 100 participantes: 19800 rotas, `summary` 42189 bytes.
- Atualizada a doc operacional `docs/operations/group-call-sfu.md` com o comando
  da inspecao local de escala e o escopo do que ela mede.
- Verificacoes executadas:
  - `mix format`: ok;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`:
    8 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/scale_inspection_test.exs`:
    4 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`: 45 testes,
    0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    11 testes, 0 falhas.
- Warning conhecido ainda aparece ao compilar/testar:
  `RetroHexChat.P2P.Registry.registry_name/0` em
  `RetroHexChatWeb.Admin.AppInfoPage`.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

### 2026-07-10 — F4 N:N com tracks ativas e UX de falha de midia

- Reforcado `RuntimeTest` com cenario N:N de tres participantes conectados:
  - owner, Bob e Carol entram na mesma chamada;
  - cada participante anuncia audio e video, totalizando 6 tracks ativas;
  - Bob sai da chamada;
  - as 2 tracks de Bob viram `ended` com reason `left`;
  - as 4 tracks dos participantes restantes continuam `active`;
  - a sala permanece `active` e os participantes restantes continuam ativos.
- Melhorada a UX de falhas no `GroupCallWebRTCHook`:
  - erro de join/signaling/negociacao agora carrega `code`;
  - fechamento inesperado do canal de signaling em chamada ativa emite warning;
  - falha de `getUserMedia` nao vira erro terminal: o usuario entra
    receive-only e recebe warning recoverable.
- Melhorado `GroupCallEvents`:
  - novo evento `group_call_client_warning` grava warning inline e adiciona
    mensagem de sistema;
  - `connectionState = disconnected` mostra warning recoverable:
    "Trying to recover";
  - `connectionState = failed` vira erro acionavel:
    "Leave and rejoin the call to retry";
  - erro terminal limpa warning anterior.
- Melhorado `RetroHexChatWeb.Components.UI.GroupCall.Panel`:
  - adicionada faixa `group-call-warning` com icone de warning;
  - faixa `group-call-error` ganhou `data-testid` para regressao;
  - warning e erro continuam na camada UI, nao no wrapper LiveComponent.
- Criado teste JS `assets/test/hooks/group_call/group_call_webrtc_hook.test.js`
  cobrindo fallback de captura de midia como warning recoverable.
- Regressao LiveView adicionada:
  - warning de captura de midia aparece no painel sem mudar status para erro;
  - estado `disconnected` preserva chamada com warning recoverable;
  - estado `failed` muda para `:error`, mostra erro e remove warning.
- Verificacoes executadas:
  - `mix format`: ok;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`:
    9 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`: 46 testes,
    0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    8 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`:
    12 testes, 0 falhas;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js`:
    1 teste, 0 falhas;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok.
- Warning conhecido ainda aparece ao compilar/testar:
  `RetroHexChat.P2P.Registry.registry_name/0` em
  `RetroHexChatWeb.Admin.AppInfoPage`.
- Nenhum commit feito. Aguardando permissao explicita do Rodrigo.

## Decisoes aplicadas

- O dominio novo se chama `RetroHexChat.GroupCall`.
- Os schemas ficaram em `RetroHexChat.GroupCall.Schema.*`, seguindo o padrao
  local de `Lobby` e `Arcade`.
- Nao reutilizar `RetroHexChat.Lobby`, `lobby_sessions`,
  `Lobby.SessionServer` ou `LobbyWebRTCHook`.
- A chamada em grupo e por canal, com no maximo uma chamada ativa por canal.
- O servidor sera o endpoint WebRTC na F2; na F1 ficamos apenas na persistencia
  e nas regras de produto.
- Persistencia acontece em eventos de ciclo de vida. O futuro caminho quente de
  RTP nao pode bater no banco.
- Nao fazer commit sem permissao explicita do Rodrigo.

## Aprendizados

- A base P2P atual resolve bem sessoes 1:1, mas o modelo e o protocolo sao
  inadequados para SFU. A implementacao nova precisa nascer como contexto
  proprio.
- O padrao correto para runtime futuro e o mesmo do projeto: dominio puro em
  `apps/retro_hex_chat`, supervisao OTP e Phoenix apenas no app web.
- A primeira entrega deve ser pequena e verificavel: migrations, schemas,
  changesets, queries, policy e testes.
- Indices parciais no Postgres sao o guardrail correto para invariantes
  concorrentes da F1. Checks apenas em processo/Registry nao bastam, porque o
  banco e a fonte autoritativa depois de crash/restart.
- `Channels.Server.get_state/1` retorna snapshot publico (`members:
  [{nickname, role}]`), nao a struct interna `Membership`. GroupCall precisa
  reconstruir `Membership.t` a partir desse snapshot antes de chamar policy.
- `ExWebRTC` puxa uma cadeia nativa (`ex_dtls`, `ex_libsrtp`, `ex_ice`,
  `ex_rtp`, `ex_rtcp`); a primeira compilacao local compila NIFs/libsrtp.
- Em runtime SFU, evitar `GenServer.call/3` em caminhos que podem formar ciclo
  RoomServer -> PeerServer -> RoomServer. Sinalizacao assincrona com casts
  reduziu deadlocks e manteve a ordem aceitavel para SDP/ICE.
- Durante join simultaneo, `pending_participants` tambem sao peers ativos para
  renegociacao. Considerar apenas `participants` ja prontos perde eventos entre
  usuarios que entram quase ao mesmo tempo.
- Teste de conferencia deve usar nomes semanticos da feature. Reaproveitar
  infraestrutura generica e aceitavel; vazar nomes `P2P` no spec/helper de
  group call prejudica leitura e revisao.
- O setup E2E precisa aplicar migrations antes do servidor Playwright subir;
  novos dominios com migrations quebram browser tests com banco antigo mesmo
  quando os testes unitarios estao verdes.
- Evitar structs de dependencias externas em module attributes quando atoms ou
  construtores runtime resolvem o mesmo problema. Isso reduz falhas em
  recompilacao incremental/code reloader depois de introduzir uma dependencia.
- Janelas WebRTC nao-managed ainda precisam aparecer no Window Manager visual:
  primeira montagem deve ser `open`, e a taskbar precisa ter botao dedicado
  enquanto a sessao existir.
- Fechar janela de uma sessao viva nao deve ser ambiguo. Para chamadas, o X,
  o botao de sair e o status bar precisam convergir para confirmacao explicita;
  minimizar e o gesto de "manter rodando".
- Reconnect curto precisa separar identidade de produto (`Participant`) da
  conexao runtime (`PeerServer`): o registro pode sobreviver por 30s, mas as
  tracks antigas devem terminar para liberar a unique parcial de source.
- Falha ICE precisa preservar motivo operacional especifico no participant
  antes do timeout terminal. Tratar tudo como `peer_down` dificulta diagnostico.
- A bateria de browser real foi adiada, mas fanout/payload ainda precisam de
  baseline local. Uma helper deterministica no dominio e melhor que um script
  solto porque fica testavel e reaproveitavel em IEx/dev.
- Sala vazia sem fechamento terminal bloqueia a unique de uma chamada ativa por
  canal; peerless timeout precisa fechar a room mesmo sem infra externa.
- Moderacao de midia deve empurrar estado para o browser alvo, nao apenas mudar
  a lista de participantes dos outros clientes.
- Mute moderado precisa ser autoridade de servidor. O browser alvo pode refletir
  estado local, mas nao pode desfazer `server_audio_muted` por signaling comum.
- LiveComponents stateful precisam renderizar uma tag HTML estatica na raiz.
  Para seguir composicao, usar um wrapper estatico e delegar a apresentacao para
  function components em `components/ui`.
- Falha de captura de camera/microfone em chamada em grupo nao deve encerrar a
  sessao: o usuario ainda pode consumir a chamada receive-only, entao isso deve
  ser warning recoverable e nao erro terminal.
- O PeerConnection do SFU nao deve usar `P2P.ice_servers/1` no lado servidor.
  Quem recebe STUN/TURN e o browser no payload da offer; o endpoint SFU deve
  anunciar candidatos host/public-mapped via `sfu_ice_*`. Reusar o helper P2P no
  servidor fazia o BEAM tentar alocacao TURN contra o proprio TURN local e gerava
  `Failed to create allocation, reason: 400`.
- `ExWebRTC.RTP.Munger` e o ponto certo para normalizar timestamp/sequence no
  encaminhamento RTP. Encaminhar pacote bruto demais deixa duplicatas/ pacotes
  antigos chegarem ao SRTP de saida como replay.

### 2026-07-10 — Hardening ICE/RTP e fila de offers

- Criado `RetroHexChat.GroupCall.RTPForwarder`:
  - prepara tracks de subscriber com munger por midia;
  - descarta sequencias RTP duplicadas/antigas antes de chamar `send_rtp`;
  - reseta o munger quando um novo track de entrada chega para a mesma midia;
  - cobre duplicate packet, reset de stream e rollover de sequencia por ExUnit.
- Atualizado `GroupCall.PeerServer`:
  - o PeerConnection do servidor nao usa mais `P2P.ice_servers/1`; a lista
    STUN/TURN continua sendo enviada apenas ao browser na offer;
  - PLI so e enviada depois do primeiro RTP de video, evitando pedido de
    keyframe antes de o receiver ter SSRC;
  - answer SDP identica ja aplicada em estado `:stable` e ignorada.
- Atualizado `GroupCallWebRTCHook`:
  - `_handleOffer` agora serializa offers numa fila de promises;
  - offer identica ja respondida nao gera nova answer;
  - testes Vitest cobrem fallback receive-only, offer duplicada e offers
    sequenciais no mesmo `RTCPeerConnection`.
- Resultado do E2E focado apos o ajuste:
  - `chat-group-call.spec.ts`: 2 testes, 0 falhas;
  - o warning `Failed to create allocation, reason: 400` desapareceu;
  - os warnings `Unable to protect RTP: :replay_fail` e `Unable to send PLI...`
    nao reapareceram na rodada focada;
  - a rodada ainda expunha `Passed the same remote credentials to be set.
    Ignoring.`, tratado na etapa seguinte com ICE restart em renegociacoes.
- I18n reavaliado:
  - a documentacao do projeto proibe editar `.po` manualmente;
  - `make i18n.gettext.rebuild`/`extract` e global e nao tem flag por dominio;
  - manter a pendencia de catalogos `chat`/`group_call` para uma rodada propria,
    sem misturar centenas de mudancas geradas em `priv/gettext`.
- Validacoes executadas nesta rodada:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `mix format --check-formatted`;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`;
  - `npx tsc --noEmit` em `e2e/`;
  - `MIX_ENV=e2e ... mix assets.build`;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 2 testes, 0 falhas;
  - `git diff --check`.

### 2026-07-10 — ICE restart nas renegociacoes

- Atualizado `GroupCall.PeerServer` para chamar
  `PeerConnection.create_offer(ice_restart: true)` em offers de topologia
  (entrada/saida de participante), mantendo a offer inicial sem restart.
- Adicionada fila `pending_remote_candidates`:
  - candidatos ICE recebidos enquanto o servidor esta em `:have_local_offer`
    ficam pendentes;
  - a fila e drenada depois de `set_remote_description` aplicar a answer;
  - isso evita aplicar candidato antes de o ICE agent receber credenciais
    remotas.
- Teste de regressao em `RuntimeTest`: candidato recebido antes da answer fica
  em `pending_remote_candidates`.
- Resultado E2E focado apos a correcao:
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 2 testes, 0 falhas;
  - os warnings `Passed the same remote credentials to be set. Ignoring.` e
    `Can't add remote candidate without remote credentials...` nao aparecem
    mais nos logs da rodada.
- Validacoes executadas nesta rodada:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs`;
  - `MIX_ENV=e2e ... mix assets.build`;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `mix format --check-formatted`;
  - `git diff --check`.

## Pendencias abertas

- F4: confirmar forwarding RTP ponta a ponta em mais cenarios alem do fluxo
  local com 3 browsers.
- F4 adiado: bateria multi-browser 4/10/25/50/100 em janela dedicada.
- I18n: atualizar catalogos Gettext de forma escopada para as novas strings
  `chat`/`group_call`, sem carregar a reescrita ampla gerada pelo rebuild.
- F6 externo: abrir portas UDP/firewall, validar NAT/TURN e ajustar deploy no
  repositorio/tarefa de infraestrutura.
