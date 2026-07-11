# Prompt de retomada — SFU chamadas em grupo

Use este prompt para reiniciar o trabalho em outra sessao do Codex.

```text
Estamos no projeto `/Users/rodrigo/src/codex/retrohexchat`.

Antes de qualquer comando shell, leia `/Users/rodrigo/.codex/RTK.md` e use
sempre o prefixo `rtk` nos comandos. Antes de operacoes Git relevantes, faca:
`rtk git status --short --branch`, `rtk git fetch origin` e
`rtk git pull --ff-only origin main` quando o working tree estiver limpo.
Nao fazer commit nem push sem permissao explicita do Rodrigo.

Pedido em andamento:
implementar o plano SFU de chamadas em grupo documentado em
`docs/plans/sfu-chamadas-grupo-referencias.md`.

Documentos de acompanhamento:
- `docs/plans/sfu-chamadas-grupo-referencias.md`: plano tecnico principal.
- `docs/plans/sfu-chamadas-grupo-PROGRESS.md`: diario de progresso e
  aprendizados. Atualizar ao final de cada bloco de trabalho.
- `docs/plans/sfu-chamadas-grupo-RESUME-PROMPT.md`: este prompt.

Estado/decisoes:
- Implementar SFU embutido no app Elixir atual, sem servidor separado.
- Criar dominio novo `RetroHexChat.GroupCall`.
- A F1 foi implementada em arquivos ainda nao commitados:
  - `apps/retro_hex_chat/priv/repo/migrations/20260709120000_create_group_call_tables.exs`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call.ex`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/queries.ex`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/policy.ex`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/room.ex`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/participant.ex`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/track.ex`;
  - `apps/retro_hex_chat/test/retro_hex_chat/group_call/*.exs`.
- A F2 backend/channel tambem foi parcialmente implementada, ainda sem commit:
  - dependencia `ex_webrtc ~> 0.17.0`;
  - `ex_stun` atualizado para `0.2.1` no `mix.lock`;
  - configs runtime `GROUP_CALL_*` e `SFU_*`;
  - `GroupCall.Config`, `JoinToken`, `Registry`, `Supervisor`,
    `RoomSupervisor`, `PeerSupervisor`, `RoomServer`, `PeerServer`;
  - `RetroHexChatWeb.GroupCallChannel`;
  - `channel "group_call:*"` no `UserSocket`;
  - hook JS `GroupCallWebRTCHook`;
  - testes de runtime e channel.
- A F3 UI tambem foi implementada, ainda sem commit:
  - `RetroHexChatWeb.ChatLive.GroupCallEvents`;
  - `RetroHexChatWeb.ChatLive.Components.GroupCallPanel`;
  - assign `:group_call` no `ChatLive`;
  - botao `Call` na topic bar de canais;
  - janela desktop `group-call`, nao managed, montada enquanto a chamada existe;
  - ponte JS no `GroupCallWebRTCHook` para espelhar eventos leves do canal
    Phoenix de volta para a LiveView;
  - teste LiveView `group_call_flow_test.exs`.
- A primeira etapa da F4 tambem foi implementada, ainda sem commit:
  - teste Playwright `e2e/tests/chat-group-call.spec.ts` cobrindo dois
    usuarios reais em browser, canal unico, abertura da chamada, video remoto
    vivo nos dois lados, lista de participantes e saida;
  - `e2e/global-setup.ts` e `e2e/helpers/e2eState.ts` agora garantem
    `ecto.create` e `ecto.migrate` em `MIX_ENV=e2e` antes do reset de registro;
  - `RoomServer` e `PeerServer` foram ajustados para usar casts assincronos em
    `mark_ready`, `apply_sdp_answer` e `add_ice_candidate`, evitando deadlock
    circular entre processos;
  - `RoomServer.leave_participant/4` foi corrigido para retornar state, nao
    `:ok`, depois de broadcast;
  - `RoomServer` passou a considerar `pending_participants` junto com
    `participants` ao montar peers ativos, broadcasts e renegociacao, corrigindo
    corrida de entrada simultanea.
- Hardening adicional de compilacao, ainda sem commit:
  - `PeerServer` deixou de usar `%ExWebRTC.RTPCodecParameters{}` em module
    attributes e passou a usar codecs atomicos `[:opus]` e `[:vp8]`, que o
    `ExWebRTC` expande internamente;
  - `SessionDescription` passou a ser criado com `struct/2`;
  - PLI de RTCP passou a ser identificado por `__struct__`, sem pattern match
    direto em `%ExRTCP.Packet.PayloadFeedback.PLI{}`;
  - o teste de channel aumentou timeout do `group_call_offer` para 1000ms.
- Correcao Window Manager da janela de conferencia, ainda sem commit:
  - `group-call` agora monta com `open` inicial verdadeiro;
  - a taskbar ganhou botao `data-window-taskbar="group-call"` /
    `data-testid="group-call-taskbar"` enquanto `@group_call` existir;
  - LiveView e Playwright cobrem a regressao da taskbar/janela.
- UX de sessao ativa e confirmacoes da conferencia, ainda sem commit:
  - `ChatShell`/`StatusBarApp` agora mostram `status-bar-group-call` com canal
    ativo, foco da janela e botao de sair;
  - `GroupCallConfirmDialog` cobre saida, X/close e troca de conferencia;
  - clicar `Call` no mesmo canal foca a janela; clicar em outro canal pede
    confirmacao antes de encerrar a atual e entrar na nova;
  - `GroupCallPanel` recebeu indicadores visuais com mais icones de status,
    participantes, tracks, mic/camera on/off.
- E2E funcional dos botoes de mic/camera, ainda sem commit:
  - `e2e/tests/chat-group-call.spec.ts` nao valida apenas presenca visual;
  - o teste clica nos toggles de microfone e camera, le
    `MediaStreamTrack.enabled` no `srcObject` local e confirma a propagacao do
    estado para o outro usuario via `data-media-audio`/`data-media-video`;
  - `GroupCallPanel` renderiza `aria-pressed` como `"true"`/`"false"` explicito
    nos toggles, corrigindo falha encontrada pelo E2E reforcado.
- F4/F5/F6 hardening local, ainda sem commit:
  - o plano foi ajustado para remover a obrigacao imediata de teste/correcao
    com 4/10/25/50/100 browsers reais; essa bateria fica para uma janela
    dedicada;
  - abertura de portas, firewall, NAT/TURN externo e deploy de infra ficam em
    outra tarefa/repositorio;
  - criado `RetroHexChat.GroupCall.RateLimiter` com limites de create/join/
    signaling e envs correspondentes;
  - `RoomServer` agora cobre reconexao curta, timeout de reconnect, fechamento
    peerless de sala vazia, upsert de tracks reais por participant/kind/source,
    status `muted`/`active` por media state e `ended` em leave/kick/close;
  - adicionadas APIs `close_call/3`, `kick_participant/3`,
    `mute_participant/3`, `unmute_participant/3`;
  - `GroupCallChannel` aplica rate limit no join e em signaling;
  - hook browser aceita mute imposto pelo servidor e eventos de track
    updated/removed/closed;
  - UI da conferencia tem controles de moderador para encerrar chamada com
    confirmacao, mutar/desmutar participante e remover participante;
  - `SFU_PUBLIC_IP` configura `host_to_srflx_ip_mapper` do `ExWebRTC`;
  - `RetroHexChatWeb.Telemetry` ganhou metricas de group call;
  - criada doc `docs/operations/group-call-sfu.md`.
- Auditoria de padroes/seguranca, ainda sem commit:
  - `RoomServer` agora preserva `server_audio_muted` e forca `audio=false`
    quando um cliente tenta religar o proprio microfone depois de mute
    moderado;
  - `RuntimeTest` cobre essa tentativa de burlar o mute;
  - a apresentacao da janela saiu do LiveComponent e foi para
    `RetroHexChatWeb.Components.UI.GroupCall.Panel`;
  - o painel UI foi decomposto em subcomponentes internos de header,
    superficie WebRTC, resumo local, lista/linha de participantes,
    indicadores e erro;
  - `ChatLive.Components.GroupCallPanel` ficou como wrapper stateful com raiz
    HTML estatica, delegando a apresentacao;
  - `aria-pressed` do botao `Call` ficou string explicita e o comentario da
    janela foi atualizado para refletir confirmacao no X/Leave.
- F4 N:N local com 3 browsers, ainda sem commit:
  - `e2e/tests/chat-group-call.spec.ts` agora tem cenario com tres usuarios de
    conferencia;
  - criado `e2e/helpers/groupCallUsers.ts` com nomes semanticos da feature
    (`newGroupCallUser` / `closeGroupCallUsers`);
  - criado `e2e/helpers/syntheticMedia.ts` para a midia fake ficar generica e
    nao depender de nomes/arquivos P2P;
  - o cenario valida Alice/Bob conectados, Carol entrando depois, todos com
    dois videos remotos vivos, Carol saindo e Alice/Bob mantendo midia viva e
    propagacao de estado;
  - `e2e/TEST_CATALOG.md` foi atualizado para 332 testes e adicionou N2.
- F4/F5 reconnect, falha ICE e inspecao local, ainda sem commit:
  - `RuntimeTest` cobre reconexao curta reutilizando o mesmo `participant.id`,
    tracks antigas terminando em `ended` e timeout terminal `failed`;
  - `RuntimeTest` tambem simula `connection_state_change: :failed` no
    `PeerServer`, preservando `participant.reason = "ice_connection_failed"`
    antes do timeout;
  - logs de `RoomServer`, `PeerServer` e `GroupCallChannel` foram ajustados
    para metadata estruturada em join negado, ready timeout, peer down, SDP
    answer e erros de track;
  - criado `RetroHexChat.GroupCall.ScaleInspection` com `run/2`,
    `fanout_plan/2`, `payload_sizes/2` e `sample_peer_processes/0`;
  - criada cobertura `ScaleInspectionTest`;
  - doc operacional ganhou o comando de inspecao local com
    `rtk mix run --no-start`;
  - baseline local: 100 participantes sinteticos = 19800 rotas N:N e payload
    `summary` de 42189 bytes.
- F4/F5 N:N com tracks ativas e UX de falha de midia, ainda sem commit:
  - `RuntimeTest` cobre owner/Bob/Carol conectados, 6 tracks ativas, Bob
    saindo, tracks de Bob `ended` com reason `left`, 4 tracks restantes ainda
    `active` e sala ainda `active`;
  - `GroupCallWebRTCHook` diferencia erros com `code` e emite
    `group_call_client_warning` quando `getUserMedia` falha ou o signaling
    channel fecha inesperadamente;
  - falha de camera/microfone agora entra receive-only e e warning recoverable,
    nao erro terminal;
  - `GroupCallEvents` trata warning inline, `connectionState=disconnected`
    como recuperavel e `connectionState=failed` como erro acionavel com
    mensagem para sair e reentrar;
  - `Components.UI.GroupCall.Panel` ganhou faixas `group-call-warning` e
    `group-call-error`;
  - criado teste JS
    `apps/retro_hex_chat_web/assets/test/hooks/group_call/group_call_webrtc_hook.test.js`;
  - `group_call_flow_test.exs` cobre warning recoverable e erro terminal.
- Nao reaproveitar `RetroHexChat.Lobby`, `lobby_sessions`,
  `Lobby.SessionServer` nem `LobbyWebRTCHook`.
- Chamada em grupo e por canal, uma chamada ativa por canal.
- F1 veio antes de WebRTC: migrations, schemas, queries, policy e testes.
- `ExWebRTC`, RoomServer, PeerServer, Phoenix Channel e UI MVP ja foram
  implementados. Validacao real em browser e hardening ficam para F4/F5.
- Persistir lifecycle frio; o futuro caminho quente de RTP nao pode escrever no
  banco nem fazer trabalho caro.
- Testes ja executados na F1:
  - `mix format --check-formatted`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`;
  - `make test`;
  - `make credo`.
- Testes/validacoes ja executados apos iniciar F2:
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`;
  - `make test`;
  - `make credo`.
- Testes/validacoes executados apos F3:
  - `mix format`;
  - `mix format --check-formatted`;
  - `git diff --check`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`;
  - `make test`;
  - `make credo`.
- Testes/validacoes executados apos a primeira etapa F4/E2E:
  - `mix format`;
  - `mix compile --force`;
  - `mix format --check-formatted`;
  - `git diff --check`;
  - `npx tsc --noEmit` em `e2e/`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_shell_test.exs`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`;
  - `make test`;
  - `make credo`.
- Teste funcional adicional executado apos reforcar os toggles:
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: valida video remoto,
    status/taskbar/dialogo de saida, `MediaStreamTrack.enabled` local para
    audio/video e estado remoto propagado para o outro participante.
- Testes/validacoes executados apos F4/F5/F6 hardening local:
  - `mix format`;
  - `mix compile`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `npx tsc --noEmit` em `e2e/`;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`;
  - `mix format --check-formatted`;
  - `git diff --check`.
- Validacao final apos a ultima retomada:
  - `mix format --check-formatted`;
  - `git diff --check`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - servidor alternativo local na porta 4100/UDP 13478 foi encerrado; servidor
    externo na porta 4000 foi preservado.
- Testes/validacoes executados apos auditoria de padroes/seguranca:
  - `mix compile`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `npx tsc --noEmit` em `e2e/`;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`;
  - `mix format --check-formatted`;
  - `git diff --check`.
- Testes/validacoes executados apos F4 N:N local com 3 browsers:
  - `npx tsc --noEmit` em `e2e/`;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 2 testes, 0 falhas.
- Testes/validacoes executados apos reconnect/ICE/inspecao local:
  - `mix format`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/scale_inspection_test.exs`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `mix run --no-start -e 'report = RetroHexChat.GroupCall.ScaleInspection.run([3, 10, 25, 50, 100]); ...'`.
- Testes/validacoes executados apos N:N com tracks ativas e UX de falha:
  - `mix format`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js`;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`.
- Testes/validacoes executados apos hardening ICE/RTP e fila de offers:
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
- Hardening aplicado nessa ultima rodada:
  - `RetroHexChat.GroupCall.RTPForwarder` usa `ExWebRTC.RTP.Munger` e descarta
    sequencias RTP duplicadas/antigas antes de `send_rtp`;
  - `GroupCall.PeerServer` deixou de usar `P2P.ice_servers/1` no PeerConnection
    servidor; STUN/TURN segue apenas para o browser na offer;
  - PLI agora so e enviada depois do primeiro RTP de video;
  - answers SDP identicas ja aplicadas em estado `:stable` sao ignoradas;
  - hook browser serializa offers e ignora offer identica ja respondida;
  - offers de topologia agora usam `ice_restart: true`;
  - candidatos ICE recebidos em `:have_local_offer` ficam em
    `pending_remote_candidates` e sao aplicados somente depois da answer.
- Resultado dos warnings E2E apos o hardening:
  - `Failed to create allocation, reason: 400` desapareceu;
  - `Unable to protect RTP: :replay_fail` e `Unable to send PLI...` nao
    reapareceram na rodada focada;
  - `Passed the same remote credentials to be set. Ignoring.` desapareceu apos
    ICE restart nas renegociacoes;
  - `Can't add remote candidate without remote credentials...` apareceu na
    primeira tentativa com ICE restart e foi corrigido com fila de candidatos.
- Testes/validacoes executados apos ICE restart/fila de candidatos:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs`;
  - `MIX_ENV=e2e ... mix assets.build`;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 2 testes, 0 falhas,
    sem os warnings de ICE anteriores;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`: 50 testes,
    0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 12 testes,
    0 falhas;
  - `mix format --check-formatted`;
  - `git diff --check`.
- Observacao da ultima rodada: uma primeira execucao de `make test` falhou em
  `AddressBookTest` por sandbox ownership durante `ChatLive.terminate/2`; o
  teste falho passou isolado e a segunda execucao completa de `make test`
  passou.
- I18n escopado retomado apos o commit SFU principal:
  - novas strings da UI/LiveView da conferencia foram movidas para o dominio
    `group_call` no app web;
  - catalogos `group_call.pot`/`group_call.po` foram gerados para os dois apps;
  - traducoes foram preenchidas via venv temporario com Argos/Polib somente
    para `group_call.po`;
  - `scripts/i18n_machine_translate_po.py` passou a mapear `pt_BR` para o
    modelo Argos `pt`;
  - `scripts/i18n_apply_translation_overrides.py` recebeu tres overrides de
    status bar com placeholders;
  - `docs/reference/i18n-catalogs.md` registra o dominio `group_call`;
  - checks focados de placeholder e source fallback passaram com 0 findings.
- Caveat i18n: `make i18n.gettext.check` global continua bloqueado por
  catalogos antigos fora de sync e por mudancas de location em dominios nao
  relacionados ao SFU. O diff amplo de 700+ arquivos do rebuild global foi
  descartado de proposito para manter esta feature revisavel.
- F4 local retomada apos o commit SFU principal:
  - `chat-group-call.spec.ts` agora cobre, com 3 browsers, video off/on e audio
    off/on de Bob enquanto Alice e Carol observam propagacao de `media_state`;
  - apos reativacao, os tres browsers validam dois videos remotos vivos.
- Sincronizacao Git feita antes do commit/push deste bloco:
  - mudancas nao commitadas guardadas com stash;
  - `git fetch origin` trouxe dois commits novos em `origin/main`;
  - `git pull --rebase origin main` reaplicou o commit SFU local sobre
    `origin/main`;
  - `git stash pop` reaplicou este bloco sem conflitos.
- Validacoes finais executadas apos i18n escopado, F4 media transitions e
  sincronizacao com `origin/main`:
  - `mix format`;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`;
  - `mix format --check-formatted`;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call`: 50 testes,
    0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 12 testes,
    0 falhas;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js`: 3 testes,
    0 falhas;
  - `npx tsc --noEmit` em `e2e/`;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`;
  - checks focados de i18n para `group_call.po`: 42 arquivos, 0 findings;
  - `git diff --check`;
  - `MIX_ENV=e2e ... mix assets.build`;
  - `npm test --prefix e2e -- chat-group-call.spec.ts`: 2 testes, 0 falhas.
- `mix compile --warnings-as-errors` falha por warning pre-existente em
  `RetroHexChatWeb.Admin.AppInfoPage` sobre `RetroHexChat.P2P.Registry`.
- Bloco de moderacao/estatisticas/icones de 2026-07-11 ja commitado:
  - kick na conferencia agora abre confirmacao e executa ban do canal via
    `Channels.Server.ban/4`; canal e conferencia sao o mesmo escopo;
  - alvo banido recebe `user_kicked`, perde a conferencia ativa e nao consegue
    reentrar no canal ate unban;
  - `group-call-stats` e janela gerenciada, tem botao proprio na taskbar e
    fechar a janela abre o mesmo dialog de confirmacao da conferencia;
  - fechamento client-side `window_closed` para `group-call` e
    `group-call-stats` roteia para `group_call_window_close` em vez de apenas
    desmontar a janela;
  - `PeerServer.stats/1` usa `ExWebRTC.PeerConnection.get_stats/1` e
    `RoomServer.summary/1` agrega `server_stats` por sala;
  - `ChatLive.GroupCallEvents` mantem `call.stats` (browser) e
    `call.server_stats` (SFU/server);
  - novos arquivos principais: `live/app/group_call_stats.ex` e
    `components/ui/group_call/stats_panel.ex`;
  - passe visual de icones aplicado na conferencia:
    `Icons.icon_conference/1` foi criado em `Icons.Media` e exposto no facade;
    botao `Call`, janela, taskbar, status bar, header, placeholder remoto,
    lista de participantes, estatisticas e dialogs usam icones semanticos;
    tiles remotos sao clonados de `<template>` renderizado pelo LiveView com
    SVGs de usuario/microfone/camera; P2P foi conferido e preservado com
    camera/sinal originais;
  - validacoes desse bloco: `mix format --check-formatted`, `make compile`,
    `mix credo --strict`, `make lint.js`, `make lint.hooks`,
    `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call` com
    50 testes, channel test de `group_call_channel_test.exs` com 4 testes
    quando rerodado isolado, teste JS focado, teste LiveView focado com
    13 testes, `MIX_ENV=e2e ... mix assets.build`,
    `npm test --prefix e2e -- chat-group-call.spec.ts` com 3 testes e
    `git diff --check`.
- Validacoes adicionais do passe visual de icones em 2026-07-11:
  - `npm --prefix apps/retro_hex_chat_web/assets test -- test/hooks/group_call/group_call_webrtc_hook.test.js`:
    8 testes, 0 falhas;
  - `PGPORT=15433 TEST_PORT=4102 mix test --include liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs`:
    13 testes, 0 falhas;
  - `mix format --check-formatted`, `make compile`, `mix credo --strict`,
    `make lint.js`, `make lint.hooks`, `MIX_ENV=e2e ... mix assets.build`,
    `npm test --prefix e2e -- chat-group-call.spec.ts` e `git diff --check`:
    ok.
- Commit criado para o bloco acima:
  - `7940a264 feat(group-call): add conference moderation stats and visual polish`.
- Bloco atual ainda sem commit: indicador visual de conferencia ativa no canal.
  - `RetroHexChat.GroupCall.create_channel_call/3` publica
    `{:group_call_started, ...}` no topico PubSub `channel:<canal>`;
  - `RoomServer.close_room/2` publica `{:group_call_ended, ...}` no mesmo
    topico;
  - `ChatLive` mantem `:group_call_channels` como `MapSet`;
  - `GroupCallEvents` centraliza refresh/marcacao de canal ativo e sincroniza
    ao entrar/ativar canal via `GroupCall.active_room_exists?/1`;
  - handlers PubSub atualizam a LiveView quando uma conferencia inicia ou
    termina;
  - UI mostra indicador no botao `Call` do canal ativo, nas tabs de canal e na
    lista de conversas/canais usando `Icons.icon_conference/1`;
  - testes adicionados em `runtime_test.exs` e `group_call_flow_test.exs`;
  - validacoes executadas: `mix format --check-formatted`, `make compile`,
    `make lint.hooks`, `git diff --check`,
    `PGPORT=15433 mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`
    com 10 testes e
    `PGPORT=15433 TEST_PORT=4102 mix test --include liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs`
    com 14 testes, todos 0 falhas.

Escopo recomendado ao retomar:
1. Conferir `git status`.
2. Ler o progresso atual.
3. Antes de qualquer commit/push futuro, repetir `rtk git fetch origin`,
   `rtk git status --short --branch` e `rtk git pull --ff-only origin main`
   se o working tree permitir.
4. Nao retomar a bateria multi-browser 4/10/25/50/100 ate o Rodrigo pedir.
5. Proximo desenvolvimento tecnico deve ser definido pelo Rodrigo; o bloco
   atual ja tem validacoes focadas registradas.
6. Nao commitar sem autorizacao explicita.
```
