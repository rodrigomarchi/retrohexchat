# Conferencia de canal — progresso e aprendizados

> Historico/superseded: diario do roadmap inicial de conferencia. Para o estado
> atual da experiencia P2P/conferencia unificada, use
> `docs/reference/media-session-p2p-conference-current.md`.

> Diario de execucao do roadmap `conferencia-canal-roadmap.md`.
> Atualizar ao iniciar e ao concluir cada bloco de trabalho. Nao substituir
> historico; adicionar novas entradas com data.

## Status geral

| Frente | Escopo | Status |
|---|---|---|
| Baseline | Auditoria da implementacao atual da conferencia | CONCLUIDA (2026-07-11) |
| V | Valor imediato: pre-join, dispositivos, screen share, active speaker, indicadores e preferencias | CONCLUIDA no modelo atual (V1-V6, 2026-07-11) |
| M | Moderacao: camera, mute all, lock, request-to-speak, screen share moderation, auditoria e permissoes | CONCLUIDA (M1-M7, 2026-07-11) |
| U | UX refinada: mini mode, fullscreen, layouts avancados, reactions, atalhos, acessibilidade e polish visual | CONCLUIDA (U1-U8, 2026-07-12) |

## Proximo bloco recomendado

Aguardar autorizacao explicita para commit/push/deploy.

Motivo: o roadmap V/M/U esta marcado como concluido no escopo atual, os gates
finais passaram e o worktree deve permanecer sem commit ate autorizacao do
Rodrigo.

## Registro de execucao

### 2026-07-12 — preparacao para commit/push/deploy

- Rodrigo autorizou commit, push e deploy.
- Fluxo git executado antes do commit:
  - trabalho local guardado em stash com untracked;
  - `git pull --ff-only origin main`;
  - main atualizada para `e9c33072`;
  - stash reaplicado sem conflitos;
  - stash consumido, sem stash pendente.
- A main trouxe commits novos de `space`; a conferencia foi validada sobre essa
  nova base antes do commit.
- Problema operacional encontrado:
  - `make ci` passou antes do pull, mas apos atualizar a main passou a falhar no
    stage paralelo de compile com `_build/dev/consolidated/... no such file or
    directory`;
  - `mix compile --warnings-as-errors` e `elixir scripts/ci.exs --only compile`
    passavam isolados;
  - corrigido `scripts/ci.exs` para executar compile primeiro e manter JS
    lint/tests em paralelo depois, evitando corrida local de consolidacao de
    protocolos antes do deploy.
- Gate final nesta base:
  - `make ci`: passou 9/9 em 3m14s.

### 2026-07-12 — auditoria corretiva pos-roadmap

- Bloco executado sem commit, conforme orientacao do Rodrigo.
- Corrigidos gaps encontrados na auditoria profunda:
  - remocao de participante agora usa o canal como fonte autoritativa:
    `Server.ban/4` roda antes da remocao do SFU;
  - criada API `GroupCall.force_kick_participant/4` para expulsao idempotente
    pos-ban, sem depender de membership que acabou de ser alterada;
  - evento `:user_kicked` carrega o canal afetado e o handler fecha a call do
    canal correto;
  - half-operators continuam podendo moderar midia permitida, mas nao veem nem
    conseguem abrir a acao de remover/banir participante;
  - pre-join foi dividido em componentes compostos:
    `MediaPreview`, `PermissionNotice` e `DeviceSelect`;
  - reactions remanescentes em participant row e overlay de video passam a usar
    SVG via `RetroHexChatWeb.Icons`/templates; emoji fica apenas como fallback
    defensivo no hook;
  - janela de stats agora mostra detalhes por peer do SFU: estado de conexao,
    ICE, RTP inbound/outbound, fanout, subscribers e RTCP feedback;
  - fallbacks dinamicos do `GroupCallWebRTCHook` foram passados por `t()`;
  - E2E ganhou caso real de permissao negada no pre-join, com retry e entrada
    receive-only sem tracks locais;
  - E2E de polish visual agora verifica overflow estrutural no desktop/mobile,
    alem de screenshot smoke e SVGs.
- Problemas encontrados e corrigidos durante os testes:
  - o novo E2E de overflow pegou regressao real: toolbar de reacoes/controles
    estourava horizontalmente em janela menor; header/toolbar passaram a aceitar
    wrap controlado;
  - primeiro `make ci` falhou apenas em `mix format --check-formatted` para
    `channel_state.ex`; arquivo formatado e CI repetido com sucesso;
  - Prettier apontou `group_call_webrtc_hook.js` e seu teste; formatado e
    rechecado.
- Testes/checks executados:
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 33 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`: 20 testes, 0 falhas;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js test/hooks/group_call/group_call_prejoin_hook.test.js`: 31 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `npm test --prefix e2e -- chat-group-call.spec.ts --grep "visual polish|permission denial"`: primeiro run expôs overflow; segundo run passou 2/2;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok apos format;
  - `git diff --check`: ok;
  - `make ci`: primeiro run 7/9 por format; segundo run passou 9/9 em 3m21s.
- Aprendizados:
  - banir do canal antes de remover do SFU e a ordem correta para impedir
    reentrada; por isso a remocao do SFU precisa de caminho idempotente pos-ban;
  - testes visuais precisam verificar geometria/overflow, nao apenas bytes de
    screenshot;
  - toolbar rica com muitos icones precisa ser responsiva por construcao; linha
    unica rigida quebra rapido no window manager retro;
  - componentes de pre-join menores deixam o contrato de hook/testid mais claro
    e evitam markup monolitico em tela nova.
- Nenhum commit realizado.

### 2026-07-12 — auditoria final de conclusao reconfirmada

- Roadmap auditado contra o objetivo ativo:
  - todos os itens `V1-V6`, `M1-M7` e `U1-U8` estao com `Status: EXISTE`;
  - checklist final do roadmap marcado como verificado;
  - Help Topic de conferencia e catalogo SVG incluem as features e icones novos;
  - worktree permanece sem commit.
- Gates executados nesta auditoria:
  - `make ci`: passou 9/9 em 3m12s;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4007 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "conference visual polish"`: 1 teste, 0 falhas.
- Nenhum commit realizado.

### 2026-07-12 — gates finais concluidos

- `make ci`: passou 9/9 em 3m18s.
  - Compile: ok;
  - JS Lint: ok;
  - JS Tests: ok;
  - Format: ok;
  - Credo: ok;
  - CSS Lint: ok;
  - Tests: ok;
  - Feature Tests: ok;
  - Dialyzer: ok.
- `MIX_ENV=e2e mix assets.build`: ok apos os ajustes finais.
- `E2E_PORT=4007 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "conference visual polish"`: 1 teste, 0 falhas.
- `git diff --check`: ok.
- Problemas encontrados e corrigidos durante o gate:
  - formatação global pendente em componentes da conferencia;
  - Credo em alias fora de ordem e nesting/complexidade no `RoomServer`;
  - CSS consistency para classes de componentes/hook;
  - Dialyzer em clauses/fallbacks impossiveis.
- Aprendizados:
  - `make ci` pega dividas que os gates focados nao pegam, especialmente CSS
    consistency e Dialyzer;
  - helpers de callbacks GenServer precisam ficar fora do bloco de `handle_call`
    para evitar warning de agrupamento;
  - lookup atom/string em maps deve preservar `false`, entao `Map.has_key?`
    continua preferivel a `||` nesses normalizadores.
- Nenhum commit realizado.

### 2026-07-12 — U7/U8 concluidos

- Bloco executado sem commit, conforme orientacao do Rodrigo.
- U7 — estados vazios/falhas:
  - `VideoSurface` agora renderiza empty state rico para participantes ausentes;
  - tile local mostra estado receive-only/camera-off com texto sincronizado pelo
    hook WebRTC;
  - warning/erro da conferencia ganharam titulo, icone e acoes claras;
  - sair a partir de warning/erro usa o mesmo dialog de confirmacao do fluxo
    principal.
- U8 — passada visual/iconografica:
  - reactions deixaram de usar emoji nos botoes e passaram a usar SVG via
    `RetroHexChatWeb.Icons`;
  - criados icones `icon_thumbs_up`, `icon_clap`, `icon_laugh` e
    `icon_sparkle` em `Icons.Symbols`;
  - facade `Icons` e `docs/reference/svg-catalog.md` atualizados;
  - Help Topic de conferencia atualizado com estados vazios/falha e keywords de
    receive-only/recovery/reactions/screen share.
- Testes criados/alterados:
  - LiveView: estados vazios, warning, erro, retry e leave com confirmacao;
  - Vitest: sincronizacao real do copy da tile local pelo hook;
  - LiveView: reactions exigem SVG nos botoes e rejeitam volta para emoji;
  - E2E Playwright: captura screenshot em desktop/mobile e valida SVG de
    reactions no fluxo receive-only.
- Verificacoes executadas neste bloco:
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature --only test:"conference renders rich empty and failure states with clear actions"`: ok;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js -- --runInBand`: 28 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature --only test:"conference reactions render on participant rows without chat spam"`: ok;
  - `mix compile --warnings-as-errors`: ok;
  - `mix format ...`: ok;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4007 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "conference visual polish"`: 1 teste, 0 falhas.
- Aprendizados:
  - `phx-update="ignore"` exige que copy vivo dentro da superficie WebRTC seja
    atualizado pelo hook, nao por re-render LiveView;
  - a revisao visual encontrou uma regressao de padrao real: emoji em controles
    onde a plataforma exige SVG via catalogo;
  - screenshot em buffer e uma boa smoke visual local para nao versionar imagens
    enquanto ainda validamos enquadramento desktop/mobile.
- Pendencias resolvidas no gate final acima.

### 2026-07-11 — inicio do bloco M7

- Bloco iniciado sem commit, conforme orientacao do Rodrigo.
- Escopo:
  - matriz explicita de permissoes por role para a conferencia de canal;
  - policy tests por acao de moderacao existente;
  - UI deve esconder/desabilitar acoes que o usuario nao pode executar;
  - documentar o contrato antes de implementar novas moderacoes M1-M6.
- Criterios de aceite iniciais:
  - owner/operator/half-op/voiced/member/guest têm capacidade definida para
    criar, encerrar, mutar remoto e remover participante;
  - testes de policy cobrem permitido/negado por role;
  - LiveView nao mostra acoes de moderacao para quem nao tem permissao;
  - Help Topics explicam que a conferencia segue permissoes do canal.

### 2026-07-11 — M7 concluido

- Criado documento de contrato:
  - `docs/plans/conferencia-canal-permissoes.md`;
  - tabela de papeis `owner/operator/half_operator/voiced/regular/guest`;
  - matriz de criar, entrar, encerrar, mutar remoto e remover/banir.
- Policy/backend:
  - testes explicitam que criar/entrar exige usuario registrado e membro do
    canal;
  - testes explicitam que encerrar exige `half_operator` ou superior;
  - testes explicitam que mute remoto e kick exigem `half_operator` ou superior
    e rank maior que o alvo.
- UI:
  - botoes de mute remoto e kick agora seguem a mesma matriz do servidor;
  - `half_operator` pode remover/mutar alvos de rank inferior;
  - `owner/operator/half_operator` nao ve acoes contra pares ou superiores;
  - usuario sem `channel_role_snapshot` nao recebe acoes de moderacao.
- Ajuda:
  - Help Topic de conferencia informa que moderacao segue permissoes do canal.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/policy_test.exs --include integration`: 16 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 20 testes, 0 falhas.
- Aprendizados:
  - a UI estava divergente do servidor: mute era permissivo demais e kick era
    restrito demais para half-op;
  - a regra correta e simples de manter: rank minimo `half_operator` e rank
    estritamente maior que o alvo;
  - nicks de teste precisam respeitar o limite real de 16 caracteres para nao
    mascarar falhas de policy com erro de changeset.
- Nenhum commit realizado.

### 2026-07-11 — M1 concluido

- Implementada moderacao individual de camera:
  - `GroupCall.block_participant_video/3`;
  - `GroupCall.unblock_participant_video/3`;
  - `RoomServer.set_participant_video/4`;
  - metadata `server_video_blocked`, `video_blocked_by` e `video_blocked_at`.
- Servidor:
  - `set_media_state` preserva `video=false` enquanto
    `server_video_blocked=true`;
  - o alvo recebe `group_call_set_media_state` para desligar a track local;
  - a mesma matriz de `Policy.can_moderate_media?/3` vale para audio e video.
- UI:
  - novo botao semantico de camera-off no participante;
  - botao aparece apenas quando a camera do alvo esta ligada ou bloqueada por
    moderador;
  - camera bloqueada por moderacao tem indicador visual/aria distinto de camera
    desligada pelo proprio usuario;
  - tentativa local de religar camera bloqueada mostra erro e reaplica o estado
    atual.
- Ajuda/E2E:
  - Help Topic de conferencia atualizado;
  - catalogo E2E ganhou `N7`.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 12 testes, 0 falhas na repeticao isolada;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 20 testes, 0 falhas;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js`: 18 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "moderator camera-off"`: 1 teste, 0 falhas.
- Aprendizados:
  - a distincao visual precisa vir de metadata preservada no `normalize_media`;
    apenas `video=false` nao diz se foi decisao do usuario ou moderacao;
  - o controle de camera-off nao deve ligar camera desligada pelo proprio alvo.
    Por isso ele aparece para camera ligada ou bloqueio moderado, mas nao para
    camera off voluntaria;
  - E2E deve validar `MediaStreamTrack.enabled`, porque o comportamento correto
    esta no browser alvo, nao so no participant row remoto.
- Nenhum commit realizado.

### 2026-07-11 — M2 concluido

- Implementadas acoes em massa:
  - `GroupCall.mute_all_participants/2`;
  - `GroupCall.block_all_participant_videos/2`;
  - `RoomServer.set_all_participants_media/4`.
- Politica:
  - usa `Policy.can_close?/3` para exigir moderador;
  - aplica `Policy.can_moderate_media?/3` por participante;
  - preserva o proprio moderador, pares e superiores;
  - considera participantes prontos e pendentes da sala.
- UI:
  - botoes de mute all e camera off all no header da conferencia;
  - dialog de confirmacao com impactos e icones;
  - resultado local atualiza participant rows afetados;
  - PubSub emite mensagem resumida no canal apenas quando alguem foi afetado.
- E2E:
  - catalogo ganhou `N8`;
  - tres browsers validam dois alvos forçados e moderador preservado.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 13 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 21 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "bulk moderation"`: 1 teste, 0 falhas.
- Aprendizados:
  - acoes em massa precisam olhar `pending_participants` alem de
    `participants`, porque o browser pode ainda estar no meio do handshake;
  - `media_state` vazio significa midia ligada por default, entao testes devem
    usar fallback explicito em vez de esperar `"audio" => true`;
  - mensagem de sistema deve ser resumo por acao, nao um evento por
    participante afetado.
- Nenhum commit realizado.

### 2026-07-11 — M3 concluido

- Implementado lock/unlock da conferencia:
  - `GroupCall.lock_call/2`;
  - `GroupCall.unlock_call/2`;
  - `RoomServer.set_locked/3`;
  - metadata `locked`, `admission_locked`, `locked_by` e `locked_at`.
- Politica:
  - join em sala travada bloqueia usuarios abaixo de `half_operator`;
  - moderadores podem entrar em sala travada para destravar ou moderar;
  - usuarios continuam no canal, apenas a entrada na conferencia e negada.
- UI:
  - botao de lock no header para moderadores;
  - estado `Locked` aparece no indicador vivo do canal;
  - erro de entrada travada e acionavel no pre-join/join flow;
  - mensagens de sistema resumem lock e unlock.
- Documentacao:
  - roadmap atualizado;
  - matriz de permissoes atualizada;
  - Help Topic da conferencia menciona lock/unlock.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/policy_test.exs --include integration`: 18 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 14 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 22 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "locked conference"`: 1 teste, 0 falhas.
- Aprendizados:
  - o lock deve bloquear admissao, nao expulsar usuarios do canal;
  - permitir entrada de moderadores em sala travada evita deadlock operacional;
  - a UI de canal ja conseguia representar `Locked`, entao bastou alimentar
    metadata e summaries corretamente.
- Nenhum commit realizado.

### 2026-07-11 — M4 concluido

- Implementado request-to-speak:
  - `GroupCall.set_hand_raised/4`;
  - `GroupCall.allow_participant_speak/3`;
  - `RoomServer` persiste `hand_raised`, `hand_raised_at` e `hand_raised_by`
    em `media_state`.
- Politica:
  - participante pode levantar/baixar a propria mao;
  - moderador pode baixar mao/liberar fala de alvo de rank inferior;
  - liberar fala desmuta pelo servidor e baixa a mao no mesmo update.
- UI:
  - botao de levantar/baixar mao no header da conferencia;
  - fila compacta de pedidos de fala na sidebar, ordenada por horario;
  - badge de mao no participant row;
  - icone `icon_raise_hand` adicionado ao catalogo;
  - popover do canal mostra icone de mao para participantes pedindo fala.
- E2E:
  - catalogo ganhou `N10`;
  - cenario valida que usuario mutado levanta mao, moderador ve fila, libera
    fala e o track real de audio do alvo volta a ficar enabled.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 15 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 23 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "request to speak"`: 1 teste, 0 falhas.
- Aprendizados:
  - `hand_raised_at` deve ficar no servidor para ordenar fila de modo
    consistente entre clientes;
  - o toggle local precisa usar fallback em `call.media`, porque summaries de
    sala podem chegar entre eventos e deixar o row proprio momentaneamente fora
    da lista local;
  - a UI de moderacao nao deve depender exclusivamente do row proprio para
    conhecer o papel do usuario atual. `self_role` preserva a permissao local
    entre merges de summary.
- Nenhum commit realizado.

### 2026-07-11 — M5 concluido

- Implementada moderacao de screen share:
  - `GroupCall.block_participant_screen_share/3`;
  - `GroupCall.unblock_participant_screen_share/3`;
  - `RoomServer.set_participant_screen_share/4`;
  - metadata `server_screen_blocked`, `screen_blocked_by` e
    `screen_blocked_at`.
- Servidor:
  - parar screen share remove `screen_track_id` e `screen_stream_id`;
  - `set_screen_share_state` recusa nova publicacao enquanto
    `server_screen_blocked=true`;
  - `set_media_state` preserva o bloqueio mesmo quando o hook envia payloads
    parciais durante renegociacao;
  - o alvo recebe `group_call_stop_screen_share` e estado forcado de midia.
- UI/hook:
  - participant row mostra acao de parar/liberar screen share quando a policy
    permite;
  - controle local fica bloqueado enquanto a restricao do servidor esta ativa;
  - o hook tambem para a captura se o servidor rejeitar uma tentativa tardia de
    reativacao.
- Ajuda/E2E:
  - matriz de permissoes e Help Topic atualizados;
  - catalogo E2E ganhou `N11`.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 16 testes, 0 falhas;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js`: 20 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 24 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "moderator can stop and block participant screen sharing"`: 1 teste, 0 falhas.
- Aprendizados:
  - o bloqueio de screen share precisa sobreviver a payloads parciais de
    `group_call_media_state`; caso contrario, uma renegociacao pode apagar
    `server_screen_blocked` sem intencao do moderador;
  - bloquear no servidor e no hook evita race entre clique local, evento de
    moderacao e resposta do canal websocket;
  - a UI remota deve refletir metadata de moderacao, nao apenas `screen=false`,
    porque parar voluntariamente e bloqueio administrativo tem semanticas
    diferentes.
- Nenhum commit realizado.

### 2026-07-11 — M6 concluido

- Implementada auditoria estruturada da conferencia:
  - novo modulo `RetroHexChat.GroupCall.Audit`;
  - eventos persistidos em `room.metadata["audit_events"]`;
  - limite de 100 eventos por sala;
  - payload com `type`, `actor`, `target`, `kind`, contadores,
    `occurred_at` e metadata auxiliar.
- Eventos cobertos:
  - `conference_started`;
  - `conference_ended`;
  - `participant_muted` / `participant_unmuted`;
  - `participant_camera_blocked` / `participant_camera_unblocked`;
  - `screen_share_started` / `screen_share_stopped`;
  - `screen_share_blocked` / `screen_share_unblocked`;
  - `participant_speak_allowed`;
  - `participant_kicked`;
  - `conference_locked` / `conference_unlocked`;
  - `mute_all` / `camera_off_all` e acoes inversas ja previstas.
- Mensagens administrativas:
  - eventos relevantes usam PubSub `:group_call_moderation`;
  - `ChannelState` traduz cada acao em mensagem de sistema sem markup dedicado;
  - `:group_call_updated`, `set_media_state`, ready/presenca e updates de
    midia continuam silenciosos no chat para evitar spam.
- Bug corrigido:
  - no fechamento da sala, o evento era colocado no struct antes do changeset.
    Como o changeset comparava contra o proprio struct ja alterado, `metadata`
    nao era persistido. O fechamento agora usa o room original como base do
    update e persiste o metadata auditado corretamente.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 18 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 25 testes, 0 falhas.
- Aprendizados:
  - evento estruturado nao e o mesmo que mensagem de sistema. O metadata guarda
    suporte/debug; a mensagem de canal deve ser apenas para evento humano
    relevante;
  - updates frequentes precisam continuar fora de `:group_call_moderation`,
    senao o canal vira log de midia;
  - ao alterar metadata em struct Ecto antes de chamar `Repo.update`, e facil
    esconder a mudanca do changeset. Para writes terminais, usar o registro
    original como base evita esse falso negativo.
- Nenhum commit realizado.

### 2026-07-11 — U1 concluido

- Implementado mini mode da conferencia:
  - `call.layout.mini` controla o modo compacto;
  - o mesmo `GroupCallPanel` alterna entre header completo e header compacto;
  - `VideoSurface` permanece montado no mesmo subtree com o mesmo token;
  - controles compactos incluem microfone, camera, expandir e sair;
  - participant rail e controles avancados somem no modo compacto para reduzir
    densidade visual sem encerrar a sessao.
- Testes:
  - LiveView valida alternar mini/normal, manter `group-call-webrtc` pelo mesmo
    token e expor controles compactos;
  - E2E N12 valida dois browsers, video remoto vivo, mesma identidade do
    elemento `<video>`, mute real via controle compacto e propagacao remota.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 26 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "mini mode keeps the call alive"`: 1 teste, 0 falhas.
- Aprendizados:
  - mini mode nao deve ser outra janela nem outro componente WebRTC; manter o
    subtree ignorado no mesmo lugar evita recriar midia;
  - validar apenas que botoes aparecem seria insuficiente. O E2E precisa
    comparar identidade do elemento remoto e estado real do track local;
  - modo compacto deve expor apenas acoes essenciais para nao virar outra
    conferencia completa espremida.
- Nenhum commit realizado.

### 2026-07-11 — U2 concluido

- Implementada organizacao de janelas para conferencia + estatisticas:
  - `WindowManagerHook` ganhou comando `dock_pair`;
  - o comando abre duas janelas lado a lado, respeita min-width/min-height,
    remove maximize/minimize e mantem foco na janela primaria;
  - header da conferencia ganhou botao `group-call-dock-stats`;
  - LiveView monta a stats window quando necessario e envia o comando sem
    codificar geometria de DOM no servidor.
- Fullscreen/maximize:
  - maximize/restore existente do window manager continua sendo a superficie
    de fullscreen/maximize;
  - E2E valida maximize/restore da conferencia depois do dock, com stats ainda
    visivel.
- Verificacoes executadas:
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/ui/window_manager_hook.test.js`: 65 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 27 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "dock statistics beside"`: 1 teste, 0 falhas.
- Aprendizados:
  - organizacao de janela pertence ao hook generico de desktop; a LiveView deve
    enviar intencao (`dock_pair`), nao manipular pixels de DOM;
  - stats nao pode roubar foco da conferencia. O comando deixa a primaria como
    `focusedId` e apenas torna a secundaria visivel;
  - validar bounding boxes no E2E cobre melhor overlap do que apenas verificar
    que duas janelas estao visiveis.
- Nenhum commit realizado.

### 2026-07-12 — inicio do bloco U3

- Bloco iniciado sem commit, conforme orientacao do Rodrigo.
- Escopo:
  - speaker view com foco dinamico no orador ativo;
  - filmstrip lateral coerente com foco/sidebar;
  - multi-pin para destacar participantes sem remontar streams;
  - compact grid para 5+ participantes;
  - regras responsivas preservando o subtree WebRTC `phx-update="ignore"`.
- Criterios de aceite iniciais:
  - layout speaker acompanha `active_speaker_participant_id` vindo do hook;
  - pin/despin altera apenas metadados/classes de layout e nao recria videos;
  - grids com muitos tiles recebem densidade visual propria;
  - controles continuam em componentes `components/ui/group_call/**`;
  - testes JS/LiveView/E2E validam comportamento real, nao so presenca visual.

### 2026-07-12 — U3 concluido

- Implementados layouts avancados:
  - novo modo `speaker` no layout da conferencia;
  - speaker view segue `active_speaker_participant_id` sem recriar elementos de
    video;
  - filmstrip lateral reaproveita o layout focus/sidebar e ganha comportamento
    responsivo;
  - multi-pin por participante com botao proprio na lista e novo `icon_pin`;
  - compact/dense grid aplicado no hook para chamadas com 5+ participantes.
- UI/componentes:
  - `LayoutControls` ganhou botao speaker;
  - `Panel` ganhou acao de pin por participante;
  - `VideoSurface` expoe `pinned_participant_ids` para o hook;
  - catalogo SVG documenta `icon_pin`.
- Testes/verificacoes executadas:
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js`: 22 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 28 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "layout controls focus tiles"`: 1 teste, 0 falhas.
- Aprendizados:
  - o tile remoto ainda pode iniciar sem `participant_id` por causa do fanout do
    SFU. O E2E precisa obter o id pela lista LiveView e deixar o hook associar o
    unico tile remoto sem dono pela instrumentacao de qualidade;
  - speaker view deve alterar apenas `data-focused`/classes. Comparar a
    identidade do `<video>` no E2E protege contra remontagem acidental;
  - pins sao estado de layout, nao regra de dominio. O servidor guarda a escolha
    local e o hook so aplica metadados/classes no grid.
- Nenhum commit realizado.

### 2026-07-12 — inicio do bloco U4

- Bloco iniciado sem commit, conforme orientacao do Rodrigo.
- Escopo:
  - reacoes temporarias em participantes/tiles;
  - rate limit leve no servidor para evitar spam;
  - propagacao entre participantes da mesma conferencia;
  - overlay visual retro e icones via catalogo;
  - Help Topic e testes de dominio/LiveView/JS/E2E quando aplicavel.
- Criterios de aceite iniciais:
  - usuario consegue enviar uma reacao rapida pela conferencia;
  - os demais clientes recebem a reacao no tile/lista sem virar mensagem de
    chat persistente;
  - excesso de reacoes retorna erro acionavel;
  - overlays expiram automaticamente no hook/browser;
  - testes validam propagacao e expiracao, nao apenas presenca do botao.

### 2026-07-12 — U4 concluido

- Implementadas reactions efemeras da conferencia:
  - `GroupCall.send_reaction/4`;
  - `RoomServer.send_reaction/4` com allowlist `heart/thumbs_up/clap/laugh/wow`;
  - `RateLimiter.check_reaction_rate/2` por sala/usuario;
  - canal Phoenix `group_call_reaction` e erro especifico
    `group_call_reaction_error`;
  - hook envia pelo canal, renderiza overlay temporario no tile e limpa timers;
  - LiveView espelha a ultima reaction por participante na lista.
- UI:
  - toolbar ganhou grupo de reactions;
  - tile remoto mostra bolha efemera;
  - participant row mostra badge visual curto;
  - Help Topic atualizado.
- Robustez corrigida:
  - fallbacks do hook para quality/reaction/screen share agora procuram tiles
    remotos por DOM + Map interno. Isso cobre o caso em que o SFU ja criou o
    tile no DOM mas a associacao interna ainda nao foi preenchida.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 19 testes, 0 falhas;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js`: 24 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 29 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "conference reactions propagate"`: 1 teste, 0 falhas.
- Aprendizados:
  - reactions nao devem virar mensagem de chat nem evento de auditoria; sao
    sinal efemero de sala;
  - o E2E precisa esperar o remetente ter `participant_id` local antes do clique,
    senao a mensagem pode ser recusada por `:not_joined`;
  - buscar tiles remotos apenas no Map interno do hook era fragil. O DOM e a
    fonte visivel, entao fallback DOM+Map reduz flakiness sem remontar midia.
- Nenhum commit realizado.

### 2026-07-12 — inicio do bloco U5

- Bloco iniciado sem commit, conforme orientacao do Rodrigo.
- Escopo:
  - atalhos de teclado para mic, camera, leave, foco/layout e push-to-talk
    quando aplicavel;
  - preservar atalhos globais do chat e inputs editaveis;
  - expor descoberta via Help Topic;
  - validar comportamento real de track quando possivel.
- Criterios de aceite iniciais:
  - atalhos so atuam quando ha conferencia ativa;
  - eventos em input/textarea/contenteditable nao disparam controles de call;
  - mute/camera por teclado alteram `MediaStreamTrack.enabled`;
  - sair por teclado respeita o dialog de confirmacao existente;
  - testes de hook/LiveView/E2E cobrem caminho funcional.

### 2026-07-12 — conclusao do bloco U5

- Implementado:
  - novas acoes de keybinding `group_call_toggle_audio`,
    `group_call_toggle_video`, `group_call_leave`,
    `group_call_layout_next` e `group_call_focus_next`;
  - categoria `Conference` no registry/cheatsheet;
  - dispatcher global preservando atalhos existentes e ignorando atalhos de
    conferencia quando o foco esta em `input`, `textarea`, `select`,
    `contenteditable` ou `role="textbox"`;
  - atalhos padrao estaveis com `Ctrl+Shift`: mic `ArrowUp`, camera
    `ArrowLeft`, layout `ArrowRight`, foco `ArrowDown`, sair `Q`;
  - push-to-talk no hook WebRTC com `Ctrl+Shift+Z`, usando keydown/keyup
    real para alterar `MediaStreamTrack.enabled`, publicar estado no SFU e
    espelhar no LiveView;
  - preservacao de flags de moderacao de audio/video/screen em atualizacoes
    parciais de midia no hook, evitando que atalhos locais reabram midia
    bloqueada pelo servidor;
  - Help Topics atualizados com descoberta dos atalhos.
- Aprendizados:
  - pontuacao com `Shift` pode virar outro `KeyboardEvent.key` por layout de
    teclado/browser; por isso os atalhos funcionais usam setas e letra em vez
    de `,`/`.` para mic/camera;
  - `Ctrl+Shift+Space` nao foi entregue de forma confiavel pelo browser no e2e
    local em macOS, entao o push-to-talk ficou em `Ctrl+Shift+Z`;
  - push-to-talk precisa viver no hook browser-side, nao apenas no dispatcher
    LiveView, porque depende de `keyup` e de alteracao imediata do track;
  - o servidor continua sendo o estado de autoridade via `group_call_media_state`
    e `group_call_media_state_forced` mantem a UI local coerente durante PTT.
- Testes executados:
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/input/shortcut_dispatcher_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js`: 35 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e`: 0 erros;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: keybindings passaram; no arquivo LiveView apareceu uma falha de sandbox em cleanup do RoomServer no teste existente de raised-hand, a investigar/revalidar;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs:658 --include liveview_feature`: teste novo de atalhos passou isolado.
  - Revalidacao apos ajustes:
    - `mix test apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 85 testes, 0 falhas;
    - `env MIX_ENV=e2e mix assets.build`: 0 falhas;
    - `env E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "conference keyboard shortcuts"`: 1 teste, 0 falhas.

### 2026-07-12 — conclusao do bloco U6

- Implementado:
  - regiao nomeada para o painel da conferencia e para a superficie WebRTC;
  - video grid com `role="group"` e placeholder remoto com `role="status"` e
    `aria-live="polite"`;
  - toolbars nomeadas para controles principais, layout e reactions;
  - lista de participantes com `role="list"` e linhas com `role="listitem"`;
  - fila de raised hand anunciavel com `role="status"`;
  - warning como `role="status"`/`aria-live="polite"` e erro como
    `role="alert"`/`aria-live="assertive"`;
  - e2e de atalhos passou a focar explicitamente o tile local, provando foco
    keyboard-first na superficie da call.
- Aprendizados:
  - o e2e precisa focar um alvo da conferencia antes de atalhos browser-side;
    isso evita depender do foco residual do composer e torna o fluxo mais fiel
    ao uso por teclado;
  - atributos `aria-live` nos estados de warning/erro precisam ficar no
    componente UI, nao no wrapper LiveView.
- Testes executados:
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 31 testes, 0 falhas;
  - `env E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts --grep "conference keyboard shortcuts"`: 1 teste, 0 falhas.

### 2026-07-11 — inicio do fechamento V1/V6

- Bloco iniciado sem commit, conforme orientacao do Rodrigo.
- Escopo:
  - fechar lacunas de permissao/dispositivo do pre-join;
  - retry acionavel para preview local;
  - mensagens diferenciadas para permissao negada, dispositivo ausente e entrada
    receive-only;
  - persistencia mais robusta das preferencias de entrada/dispositivos conforme
    padroes existentes do projeto.
- Criterios de aceite iniciais:
  - falha de `getUserMedia` no pre-join nao deixa o usuario sem acao;
  - usuario consegue tentar novamente sem fechar o dialog;
  - entrar receive-only continua possivel e explicito;
  - preferencias reaparecem ao reabrir o pre-join;
  - testes cobrem hook, LiveView e E2E quando o browser fake media permitir.

### 2026-07-11 — V1/V6 concluido no modelo atual

- Fechado o fluxo de pre-join/dispositivos/preferencias:
  - retry de preview no proprio dialog, com icone e mensagem acionavel;
  - retry forca nova tentativa mesmo com as mesmas constraints;
  - mensagens diferenciadas para permissao negada, dispositivo ausente, device
    em uso, device selecionado indisponivel e receive-only;
  - estado vazio do preview indica receive-only/camera indisponivel;
  - preferencias de browser agora sao escopadas por usuario;
  - LiveView guarda a ultima preferencia da sessao para reabrir o pre-join sem
    depender do timing do hook;
  - escalares de conferencia sao persistidos em
    `user_preferences.display_settings["group_call_settings"]`;
  - ids de dispositivos continuam apenas em `localStorage`, por serem locais ao
    browser/perfil.
- Bug corrigido:
  - o normalizador de pre-join usava `||` e perdia booleanos `false` vindos de
    estado interno/persistido. Agora usa coalescencia que preserva `false`.
- Testes criados/alterados:
  - Vitest para warning de permissao e retry real;
  - LiveView para carregar preferencias escalares persistidas;
  - E2E N3 para cancelar/reabrir pre-join e confirmar que mic/camera off
    reaparecem antes de entrar.
- Verificacoes executadas:
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js test/hooks/group_call/group_call_prejoin_hook.test.js`: 20 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 19 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts`: 7 testes, 0 falhas.
- Aprendizados:
  - preferencia de device nao deve ir para banco como verdade global, porque o
    `deviceId` muda por browser/perfil;
  - o hook precisa reaplicar localStorage em `updated()`, pois patches do
    LiveView podem reescrever inputs depois do `mounted()`;
  - testes devem preservar `false` vindo de estado interno, nao apenas string
    `"false"` vinda de form submit.
- Nenhum commit realizado.

### 2026-07-11 — inicio do bloco V5

- Bloco iniciado sem commit, conforme orientacao do Rodrigo.
- Escopo:
  - indicador rico de conferencia no canal;
  - badge/popover com estado, duracao, participantes, speaker atual e acoes
    rapidas;
  - mensagens de sistema para eventos relevantes sem spam.
- Criterios de aceite iniciais:
  - usuario ve no canal que existe conferencia ativa antes de abrir a janela;
  - indicador usa componentes `components/ui/group_call/**`, nao markup dedicado
    pesado na LiveView;
  - estado reflete participante conectado, reconnect/falha, lock quando existir
    no dominio e encerramento;
  - acoes rapidas respeitam a regra de uma conferencia ativa por usuario;
  - testes LiveView e E2E validam o comportamento real do badge antes/depois de
    join/leave/end call.

### 2026-07-11 — V5 concluido

- Implementado indicador rico de conferencia no canal:
  - novo componente `Components.UI.GroupCall.ChannelBadge`;
  - topic bar usa entrada composta com botao `Call`, badge vivo e popover;
  - abas e sidebar usam glyph compacto reutilizando a mesma derivacao visual;
  - badge mostra estado, participantes, capacidade e duracao;
  - popover mostra participantes, speaker quando conhecido, icones de midia e
    acao rapida `Join/Open`.
- Dominio/SFU:
  - payload de sala passou a incluir `inserted_at`, `opened_at`,
    `activated_at` e `metadata`;
  - `RoomServer` publica `:group_call_updated` em join/leave de participante;
  - LiveView guarda `group_call_channel_summaries` sem remover o
    `group_call_channels` usado pelos pontos existentes.
- UX/mensagens:
  - eventos de inicio/fim da conferencia aparecem como mensagem de sistema
    apenas quando o canal esta visivel;
  - joins/leaves de participantes atualizam o indicador, mas nao geram spam no
    chat;
  - estado `Locked` ja e renderizado quando o dominio passar metadata de lock,
    deixando a UI pronta para `M3`.
- Ajuda:
  - topico `feature-channel-conference` atualizado com indicador de canal.
- Testes criados/alterados:
  - LiveView cobre summary por canal, badge rico, popover e limpeza ao encerrar;
  - E2E N1 valida que Bob ve `Live`, `1/100` e Alice no popover antes de entrar
    na conferencia;
  - runtime segue cobrindo lifecycle da sala depois do novo broadcast.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 18 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 12 testes, 0 falhas;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts`: 7 testes, 0 falhas.
- Aprendizados:
  - `group_call_started` acontece antes de o primeiro participante completar o
    join WebRTC; por isso o indicador precisa de updates posteriores de
    presenca da sala, nao apenas do evento inicial;
  - mensagens de sistema para cada join/leave ficariam ruidosas. O melhor
    contrato e: inicio/fim no chat, presenca dinamica no badge;
  - manter `group_call_channels` e adicionar summaries evita churn nos pontos
    que so precisam de booleano.
- Nenhum commit realizado.

### 2026-07-11 — V4 concluido

- Implementada recuperacao acionavel para estados degradados da conferencia:
  - o hook observa `connectionState` do `RTCPeerConnection`;
  - estados `connecting`, `connected`, `disconnected` e `failed` viram estado
    visual na LiveView;
  - falha/desconexao agenda retry automatico com backoff `1s/2s/4s`;
  - ao esgotar tentativas, a UI mostra erro com botao manual `Retry`;
  - retry manual pede uma nova oferta ao SFU sem fechar a janela e sem encerrar
    a sessao.
- Dominio/SFU:
  - `GroupCall.request_offer/2`;
  - `RoomServer.request_offer/2`;
  - `PeerServer.request_offer/2`;
  - canal websocket `group_call_request_offer`.
- UI:
  - status `:reconnecting` na janela;
  - mensagens separadas para negociacao, reconexao e falha;
  - botao de retry com icone no erro acionavel;
  - secao de ajuda atualizada com recuperacao.
- Testes criados/alterados:
  - runtime para pedir nova oferta em peer ativo e tratar peer ausente;
  - Vitest para retry automatico com backoff e retry manual imediato;
  - LiveView para estados recuperaveis, erro acionavel e push de retry;
  - E2E N6 validando que o retry manual nao fecha a conferencia nem derruba o
    video remoto.
- Verificacoes executadas:
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 12 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 18 testes, 0 falhas;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js test/hooks/group_call/group_call_prejoin_hook.test.js`: 19 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts`: 7 testes, 0 falhas.
- Aprendizados:
  - `PeerConnection.get_pending_local_description/1` nao e seguro nesta versao
    da dependencia: ele falhou com `:badkey :current_pending_desc` durante
    renegociacao. O caminho estavel para reenviar oferta ativa e
    `PeerConnection.get_local_description/1`;
  - simulacao real de falha de rede em browser tende a ser flaky. O E2E valida a
    UI com instrumentacao deterministica `group-call:recovery-state` e os testes
    de hook cobrem o backoff/solicitacao de oferta;
  - recuperacao precisa preservar a janela e as tracks remotas existentes. Fechar
    e recriar a sessao mascara bugs e quebra a regra de uma conferencia ativa.
- Nenhum commit realizado.

### 2026-07-11 — inicio do bloco V2

- Bloco iniciado sem commit, conforme orientacao do Rodrigo.
- Escopo:
  - `V2` Compartilhamento de tela;
  - integracao minima com estados ja existentes da conferencia: resumo,
    estatisticas, layout/foco e controles de midia.
- Criterios de aceite iniciais:
  - botao de iniciar/parar screen share dentro da janela de conferencia;
  - hook usa `navigator.mediaDevices.getDisplayMedia` e encerra limpo quando o
    browser para a captura;
  - dominio representa `source=screen` separado de `source=camera`;
  - resumo/estatisticas expõem track de tela como dado proprio;
  - UI mostra estado de tela compartilhada e erro acionavel quando o browser nao
    suporta ou nega a permissao;
  - testes cobrem dominio, LiveView, hook JS e E2E quando o fluxo estiver
    disponivel no browser fake media.
- Observacao tecnica inicial:
  - o SFU atual encaminha um par fixo audio/video por peer remoto. A primeira
    passada de V2 precisa preservar esse contrato ou evolui-lo com testes antes
    de prometer multi-video remoto por participante.

### 2026-07-11 — V2 concluido no modelo atual

- Implementado compartilhamento de tela por substituicao da camera publicada:
  - o botao `group-call-screen-share-toggle` usa gesto direto do usuario para
    chamar `navigator.mediaDevices.getDisplayMedia`;
  - o hook faz `RTCRtpSender.replaceTrack` para trocar camera por tela e restaura
    a camera ao parar;
  - parar pelo browser chama o mesmo fluxo de encerramento e propaga o estado.
- Dominio/SFU:
  - `GroupCall.set_screen_share_state/4` registra `media_state.screen`,
    `screen_track_id` e `screen_stream_id`;
  - tracks de video passam a carregar `source` (`camera` ou `screen`);
  - estatisticas de servidor incluem `screen_track_count`.
- UI:
  - novo componente `Components.UI.GroupCall.ScreenShareControl`;
  - tiles e participantes mostram badge/nameplate de tela compartilhada;
  - tela compartilhada vira foco natural no layout quando o evento chega;
  - janela de stats mostra contagem de screen tracks.
- Ajuda:
  - topico de conferencia atualizado com secao de compartilhamento de tela.
- Testes criados/alterados:
  - runtime/domain para `source=screen` e estatisticas;
  - LiveView para estado, foco, controles e stats;
  - Vitest para `getDisplayMedia`, `replaceTrack`, `track.onended` e fallback
    de tile remoto;
  - E2E real com dois browsers validando que a tela substitui a camera, aparece
    no remoto como `source=screen` e volta para `camera` ao parar.
- Verificacoes executadas:
  - `npm run format --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js test/hooks/group_call/group_call_prejoin_hook.test.js`: 15 testes, 0 falhas;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts`: 5 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 11 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 17 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok;
  - `git diff --check`: ok.
- Aprendizados:
  - o bundle E2E precisa ser reconstruido com `MIX_ENV=e2e mix assets.build`
    antes de confiar no Playwright; caso contrario ele pode testar JS antigo;
  - o SFU gera stream ids remotos proprios, entao o hook nao pode depender
    apenas do `stream_id` persistido pelo browser de origem para marcar o tile;
  - o evento de screen share precisa atualizar tambem o cache local de
    `participantsById`, senao parar a tela pode manter o badge ativo por causa
    de `media_state.screen=true`;
  - o modelo atual e corretamente limitado a camera ou tela por participante.
    Camera e tela simultaneas exigem evolucao explicita do contrato SFU.
- Pendencias explicitas:
  - multi-video por participante fica fora de V2 atual;
  - politicas de moderacao especificas para screen share entram na frente M;
  - qualidade/active speaker entram no proximo bloco V3.
- Nenhum commit realizado.

### 2026-07-11 — V3 concluido

- Implementado active speaker e qualidade por participante na perspectiva local
  do browser:
  - o hook reutiliza um unico `getStats()` por tick e deriva stats agregadas e
    stats por participante;
  - `audioLevel` remoto escolhe o orador ativo quando disponivel;
  - RTT, jitter, perda, bitrate, FPS e freezes viram nivel
    `excellent/good/fair/poor/reconnecting`;
  - participantes e tiles recebem `data-active-speaker` e `data-quality-level`.
- Componentes criados:
  - `Components.UI.GroupCall.ParticipantQualityBadge`;
  - `Components.UI.GroupCall.ActiveSpeakerRing`.
- UI:
  - a linha do participante mostra badge de qualidade com tooltip tecnico;
  - o participante falando recebe indicador visual na lista;
  - o tile remoto recebe ring retro e badges de speaking/qualidade;
  - o hook tem fallback para associar qualidade ao unico tile remoto sem dono,
    necessario porque o SFU pode gerar stream ids remotos diferentes dos ids
    persistidos.
- Hook/browser:
  - `collectFeatureSnapshotFromReports/1` evita duas chamadas de `getStats()`;
  - evento DOM `group-call:participant-quality` permite instrumentacao
    deterministica de UI/E2E sem depender de `audioLevel` real do fake media.
- Ajuda:
  - topico `feature-channel-conference` atualizado com speaker e quality.
- Testes criados/alterados:
  - Vitest para derivacao de active speaker/quality via `RTCStatsReport`;
  - Vitest para instrumentacao deterministica do hook;
  - LiveView test para evento `group_call_participant_quality`, badges e estado;
  - E2E N5 com dois browsers validando tile ignorado, linha LiveView, badge de
    qualidade e badge de speaking.
- Verificacoes executadas:
  - `npm run format --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npx prettier --write tests/chat-group-call.spec.ts TEST_CATALOG.md` em
    `e2e/`: ok;
  - `mix format ...`: ok;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_webrtc_hook.test.js test/hooks/group_call/group_call_prejoin_hook.test.js`: 17 testes, 0 falhas;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 18 testes, 0 falhas;
  - `mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs --include integration`: 11 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `MIX_ENV=e2e mix assets.build`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts`: 6 testes, 0 falhas;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok;
  - `git diff --check`: ok.
- Aprendizados:
  - qualidade por participante deve ser tratada como perspectiva local do
    observador, nao como verdade global da sala;
  - `audioLevel` em fake media/browser real pode variar, entao E2E precisa de
    instrumentacao deterministica para validar UI sem flaky;
  - tiles remotos ainda podem existir sem `participant_id` por causa do fanout do
    SFU. Qualquer feature visual por participante precisa fallback controlado
    para o unico tile remoto sem dono.
- Pendencias explicitas:
  - ordenacao automatica do layout por speaker ainda nao foi ativada; para evitar
    reordenar tiles/remontar midia, fica para U3/layouts avancados;
  - qualidade do proprio usuario continua sendo agregada na janela de stats, nao
    como badge por participante remoto.
- Nenhum commit realizado.

### 2026-07-11 — inicio do bloco V1/V6

- Bloco iniciado sem commit, conforme orientacao do Rodrigo.
- Escopo:
  - `V1` Pre-join, preview e selecao de dispositivos;
  - parte minima de `V6` necessaria para defaults de entrada: mic/camera
    ligados ou desligados, layout/self-view/sidebar e dados locais de
    dispositivos quando aplicavel.
- Criterios de aceite iniciais:
  - clicar `Call` no canal abre um dialog de pre-join antes de entrar na SFU;
  - cancelar nao cria participante nem abre janela de conferencia;
  - entrar com mic/camera desligados cria a conferencia com estado de midia
    correto;
  - o hook so entra no canal de signaling depois da confirmacao do pre-join;
  - testes validam comportamento real dos tracks quando houver browser/E2E;
  - progresso e aprendizados sao registrados ao final do bloco.

### 2026-07-11 — V1/V6 parcial concluido

- Implementado pre-join antes da entrada real na SFU:
  - clicar `Call` abre `group-call-prejoin-dialog`;
  - cancelar nao cria room/participant nem monta `GroupCallWebRTCHook`;
  - confirmar cria/entra na call e abre conferencia/stats como antes.
- Criado componente visual:
  - `Components.UI.GroupCall.PreJoinDialog`;
  - mantem markup de tela fora da LiveView;
  - usa `Dialog`, `Button` e icones via `Icons`.
- Criado hook de browser:
  - `GroupCallPreJoinHook`;
  - enumera microfone/camera/speaker;
  - abre preview local;
  - salva/carrega preferencias em `localStorage`;
  - sincroniza preferencias com o servidor sem abrir socket SFU.
- Ajustado `GroupCallWebRTCHook`:
  - respeita `audio_input_id`, `video_input_id` e `audio_output_id`;
  - nao chama `getUserMedia` quando mic e camera entram desligados;
  - usa stream vazio para manter a UI local coerente nesse caso.
- Ajustado fluxo LiveView:
  - novo assign `:group_call_prejoin`;
  - `group_call_open` abre pre-join quando nao ha call ativa;
  - troca de conferencia continua usando confirmacao propria e reaproveita as
    preferencias da call atual.
- Atualizada ajuda:
  - novo topico `feature-channel-conference`;
  - novo template `feature_channel_conference.html.heex`.
- Atualizado E2E:
  - `chat-group-call.spec.ts` passa pelo pre-join;
  - novo cenario valida entrar com mic/camera desligados e propagacao do estado
    para outro participante;
  - `e2e/TEST_CATALOG.md` atualizado para 333 casos.
- Verificacoes executadas:
  - `mix format ...`: ok;
  - `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`: 16 testes, 0 falhas;
  - `npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js`: 12 testes, 0 falhas;
  - `npx tsc --noEmit` em `e2e/`: ok;
  - `npm run format:check --prefix apps/retro_hex_chat_web/assets`: ok;
  - `npm run lint --prefix apps/retro_hex_chat_web/assets`: ok;
  - `E2E_PORT=4003 PGPORT=5433 npm test --prefix e2e -- chat-group-call.spec.ts`: 4 testes, 0 falhas.
- Aprendizados:
  - o dialog real do sistema tem a superficie visivel em `#<id>-surface`; o root
    modal e wrappers podem nao ter caixa propria para `toBeVisible`;
  - `getUserMedia({audio: false, video: false})` nao deve ser chamado em browser
    real; stream vazio e o caminho correto para entrada totalmente muted;
  - device picker precisa sincronizar DOM, servidor e localStorage para evitar
    re-render sobrescrever a escolha antes do submit.
- Nenhum commit realizado.

### 2026-07-11 — plano de roadmap criado

- Lidas/consideradas as regras duraveis do projeto:
  - `CLAUDE.md`;
  - `docs/AGENT-GUIDE.md`;
  - `/Users/rodrigo/.codex/RTK.md`.
- Conferidos os componentes e eventos atuais da conferencia:
  - `Components.UI.GroupCall.Panel`;
  - `Components.UI.GroupCall.LayoutControls`;
  - `Components.UI.GroupCall.VideoSurface`;
  - `Components.UI.GroupCall.StatsPanel`;
  - `ChatLive.GroupCallEvents`;
  - `ChatLive.Components.GroupCallConfirmDialog`;
  - `assets/js/hooks/group_call/group_call_webrtc_hook.js`;
  - `RetroHexChat.GroupCall.RoomServer`.
- Confirmado que a implementacao atual segue a diretriz principal:
  apresentacao em componentes UI, LiveView como adaptador/orquestrador e hook JS
  como wiring WebRTC/browser.
- Criado `docs/plans/conferencia-canal-roadmap.md` com backlog estruturado em:
  - `V*` valor imediato;
  - `M*` moderacao;
  - `U*` UX refinada.
- Criado este diario para registrar progresso e aprendizados daqui em diante.
- Nenhum commit realizado.

## Aprendizados da auditoria

- A base visual da conferencia ja esta mais madura que um MVP: tem header,
  sidebar, foco, layout, self-view, status bar, taskbar, dialogos de
  confirmacao e stats server/browser.
- A maior lacuna de primeiro uso nao e mais "abrir a chamada"; e entrar com
  controle: preview, permissao, device picker, defaults e estado receive-only.
- A moderacao ja tem duas fundacoes importantes: kick/ban e mute de audio
  imposto pelo servidor. O proximo salto e generalizar essa politica para
  camera, screen share, acoes em massa e lock.
- Estatisticas ja existem em janela propria, mas ainda falta transformar parte
  desses dados em sinais pequenos dentro da experiencia principal: qualidade por
  participante, degraded state e active speaker.
- O hook atual usa `getUserMedia` diretamente no join. Para pre-join e screen
  share, sera preciso separar melhor captura previa, captura da sessao e troca
  de tracks sem recriar a janela.
- `GroupCallEvents` ja centraliza a regra de uma conferencia ativa por usuario.
  Novas entradas de UX devem preservar esse fluxo de confirmacao.
- Qualquer melhoria de UI deve continuar compondo `components/ui/group_call/**`;
  markup dedicado em LiveView/LV component vira divida arquitetural rapidamente.

## Regras de registro

- Ao iniciar um bloco, adicionar uma secao com data, ID da tarefa e objetivo.
- Ao concluir, registrar:
  - arquivos principais alterados;
  - testes criados/alterados;
  - comandos executados;
  - problemas encontrados;
  - aprendizados;
  - pendencias explicitas.
- So registrar commit/push/deploy quando o Rodrigo autorizar e a operacao for
  efetivamente executada.
