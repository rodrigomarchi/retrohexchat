# P2P x conferencia - auditoria e plano de paridade

> Criado em 2026-07-12. Objetivo: elevar a comunicacao P2P para que o usuario
> sinta que P2P e conferencia pertencem ao mesmo produto, mantendo as diferencas
> corretas do contexto 1:1.

## Objetivo

O P2P ja esta integrado ao chat e tem uma base tecnica forte: uma sessao unica
por usuario, janelas de Call/Files/Games/Statistics, PM como conversa da sessao,
WebRTC real, stats, arquivos, jogos, privacy mode e confirmacoes destrutivas.

A lacuna atual nao e "falta P2P funcionar". A lacuna e produto:

- a janela de chamada P2P ainda parece uma superficie mais antiga que a
  conferencia de canal;
- controles, layouts, stats, dialogs, icones e estados nao usam a mesma
  linguagem rica criada na conferencia;
- algumas features de alto valor da conferencia fazem sentido no P2P
  (pre-call setup, screen share, mini mode, reacoes, atalhos, polish visual);
- outras nao fazem sentido no 1:1 e nao devem ser copiadas cegamente
  (mute all, request-to-speak, lock de sala, kick/ban por role de canal).

Resultado esperado: quando o usuario alternar entre uma conferencia de canal e
uma chamada P2P, ele reconhece o mesmo sistema de midia, os mesmos padroes de
confirmacao, os mesmos icones, a mesma qualidade visual e o mesmo rigor de
feedback.

## Regras de implementacao

- P2P continua sendo 1:1 e ancorado ao PM. A conversa da sessao e o PM.
- Continua existindo uma unica sessao P2P por usuario. Trocar de peer exige
  confirmacao e encerra chamada, arquivo e jogo em andamento.
- O P2P continua multiplexando call, file transfer e game no mesmo
  `RTCPeerConnection`; isso e diferencial de produto, nao deve ser removido.
- LiveViews devem continuar finas. Eventos ficam em
  `ChatLive.P2PSessionEvents`; estado visual complexo fica em componentes/ilhas.
- Telas novas devem ser composicao de componentes em `components/ui/**`, com
  wrappers stateful em `chat_live/components/**` somente quando necessario.
- SVG sempre via `RetroHexChatWeb.Icons` ou componente de icone catalogado. Nao
  introduzir emoji como icone de UI.
- Testes precisam validar comportamento real: tracks, `srcObject`,
  `MediaStreamTrack.enabled`, stats, z-index/foco, layout e ausencia de
  overflow. Verificar so que o botao aparece nao basta.
- Toda feature visivel ao usuario deve atualizar Help Topics.
- Gate final: testes focados, `git diff --check` e `make ci`.
- Antes de commit/push em `main`: `git fetch`, `git status`, `git pull
  --ff-only` ou stash/autostash quando houver edicoes locais. Deploy deve usar
  `make deploy`.

## Fontes auditadas

Implementacao P2P:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_media_island.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/media_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/lobby_network_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/p2p_stats.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/p2p_connection_diagram.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/p2p_confirm_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/session_card.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/shell/status_bar_app.ex`
- `apps/retro_hex_chat_web/assets/js/lib/p2p/rtc_media_hook_factory.js`
- `apps/retro_hex_chat_web/assets/js/hooks/lobby/lobby_webrtc_hook.js`
- `e2e/tests/chat-p2p.spec.ts`
- `e2e/helpers/p2pFlows.ts`

Referencia da conferencia:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/**`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/group_call_events.ex`
- `docs/plans/conferencia-canal-roadmap.md`
- `docs/plans/conferencia-canal-roadmap-PROGRESS.md`

Documentos historicos P2P:

- `docs/plans/p2p-chat-integracao.md`
- `docs/plans/p2p-chat-integracao-PROGRESS.md`

## Baseline atual do P2P

### O que esta bom e deve ser preservado

- `@p2p_session` e a fonte unica de verdade para status bar, janelas,
  confirmacoes, convites, rehidratacao e lifecycle.
- A sessao P2P e unica por usuario e o switch de sessao ja exige confirmacao.
- O PM absorveu a conversa da sessao; eventos compartilhados usam
  `p2p_system`.
- As janelas `p2p-call`, `p2p-files`, `p2p-games` e `p2p-stats` apresentam a
  sessao no desktop.
- Fechar qualquer janela P2P pede confirmacao e confirmar encerra a sessao
  inteira. Minimizar mantem rodando.
- O WebRTC do P2P usa um unico `RTCPeerConnection` com audio/video,
  `filetransfer` e `gamedata`.
- A chamada P2P suporta audio, video, mute, camera off, enable audio/video,
  PiP, presets de qualidade e troca de dispositivos.
- Stats P2P rodam sempre pela conexao e separam rede, audio, video, game e file.
- File transfer e game ja foram validados coexistindo com chamada ativa.
- Privacy mode TURN-only existe, persiste preferencia e aparece no painel de
  stats.
- E2E atual ja valida conexao WebRTC real, video remoto real, arquivo e jogo na
  mesma conexao.

### Onde o P2P parece mais antigo que a conferencia

- A janela de call P2P e composta pelo `Lobby.MediaPanel`, que ainda concentra
  muita apresentacao em um unico componente e nao tem o mesmo header rico da
  conferencia.
- Layouts P2P sao `focus`, `side_by_side`, `maximized`; conferencia tem
  `auto`, `grid`, `focus`, `speaker`, sidebar, self-view `tile/pip/hidden`,
  foco e pin.
- Nao existe pre-call/pre-join com preview de camera, seletor de dispositivos e
  estado acionavel de permissao antes da entrada.
- Nao existe screen share no P2P.
- Nao existe mini mode especifico do P2P.
- Nao existem reacoes efemeras no P2P.
- Atalhos de teclado de midia/layout ainda nao foram mapeados para P2P.
- O status bar P2P e correto, mas menos rico que o indicador da conferencia:
  nao resume facetas ativas, duracao, qualidade, relay/privacy e acoes rapidas
  com a mesma riqueza.
- O dialog P2P tem confirmacao funcional, mas e menos informativo que os
  dialogs da conferencia, que mostram icone grande e lista de impactos.
- O `P2PConnectionDiagram` ainda usa alguns emojis como iconografia de estado
  e whois. Isso quebra o padrao atual de SVG via catalogo.
- Help topics ainda usam muito a linguagem "P2P Lobby"; precisam refletir a
  experiencia in-chat e as novas features quando a elevacao for feita.

## Matriz de paridade

| Area | Conferencia | P2P hoje | Decisao |
|---|---|---|---|
| Sessao unica | Existe | Existe | Manter; alinhar copy e dialogs |
| Status bar | Rica, com call ativa | Existe, simples | Elevar |
| Pre-join/setup | Existe | Falta | Implementar versao P2P |
| Device preview | Existe | Parcial, so dentro da call | Implementar antes de iniciar midia |
| Audio/video toggles | Existe e testado por track | Existe | Re-testar comportamento real |
| Layouts | Avancados | Basicos | Elevar com semantica 1:1 |
| Focus/pin | Existe | Parcial, so layout focus | Foco faz sentido; pin nao precisa |
| Self-view | tile/pip/hidden | PiP remoto + self-view fixa | Elevar |
| Screen share | Existe | Falta | Implementar |
| Active speaker | Existe | Pouco valor em 1:1 | Nao priorizar; usar audio state simples |
| Qualidade por participante | Existe | Qualidade global | Adaptar para local/peer |
| Stats browser | Existe | Existe forte | Alinhar visual e metricas |
| Stats servidor | SFU server stats | Nao ha SFU | Nao copiar; mostrar signaling/TURN/sessao |
| Reacoes | Existe | Falta | Implementar reacoes 1:1 efemeras |
| Moderacao por role | Existe | Nao se aplica | Nao copiar |
| Mute all/camera off all | Existe | Nao se aplica | Nao copiar |
| Lock/request-to-speak | Existe | Nao se aplica | Nao copiar |
| Kick/ban de canal | Existe | Nao se aplica | Substituir por end/block/ignore quando fizer sentido |
| Confirm dialogs | Ricos | Funcionais | Elevar visual/copy |
| Mini mode | Existe | Falta | Implementar |
| Fullscreen/dock stats | Existe | Parcial pelo WM | Elevar |
| Iconografia SVG | Padrao atual | Parcial | Corrigir |
| E2E visual | Existe para conferencia | Parcial | Adicionar |

## Principios de UX para P2P

### A sessao P2P nao e so uma call

P2P e uma sessao 1:1 com quatro facetas simultaneas: conversa no PM, chamada,
arquivos e jogos. A conferencia e uma sala de midia. A paridade deve alinhar a
experiencia de midia, mas nao reduzir P2P a uma copia da conferencia.

### A chamada P2P deve parecer a mesma familia visual

O usuario deve reconhecer:

- header com peer, estado, qualidade e duracao;
- toolbar de midia com icones SVG e tooltips;
- controles de layout com os mesmos simbolos;
- empty states e falhas com icone, titulo, copy curto e acao clara;
- dialog destrutivo com impacto explicito;
- stats com o mesmo ritmo visual de `GroupCall.StatsPanel`.

### O setup P2P precisa respeitar o contexto 1:1

Na conferencia, pre-join evita entrar em uma sala sem escolher camera/mic. No
P2P, aceitar o convite tambem inicia uma sessao com arquivos/jogos. Portanto o
setup deve ser um "P2P setup" antes de aceitar/entrar, nao apenas um modal de
video.

Proposta:

- aceitar convite abre dialog de setup quando ainda nao ha sessao ativa;
- setup mostra peer, privacy mode, preview local, mic/camera defaults e device
  selects;
- confirmar aceita a sessao e aplica os defaults de midia;
- cancelar nao aceita a sessao;
- se o convite veio de "Audio Call" ou "Video Call", defaults sao semeados pela
  intencao original;
- se veio de `/p2p` generico, usar preferencias do usuario e deixar claro que
  Files/Games tambem ficarao disponiveis.

### O P2P deve continuar rapido

O setup nao deve virar friccao pesada para quem ja prefere auto-start. Depois de
implementado, persistir preferencias:

- mic/camera default;
- ultimo layout;
- self-view;
- devices locais por browser;
- privacy mode ja existente;
- opcao "start media automatically for P2P" se a validacao de UX indicar que
  vale preservar o auto-start atual.

## Roadmap proposto

Estados:

- `EXISTE`: implementado e com testes suficientes.
- `PARCIAL`: existe base, mas falta comportamento, UX ou teste.
- `FALTA`: nao implementado.

### P2P-V1 - Componentes compartilhaveis de midia

Status: `CONCLUIDA`

Objetivo: criar a base para o P2P usar a mesma linguagem visual da conferencia
sem acoplar P2P diretamente a componentes com semantica de canal.

Entregar:

- Extrair ou criar componentes neutros quando fizer sentido:
  `MediaPreview`, `DeviceSelect`, `PermissionNotice`, `CallToolbar`,
  `LayoutControls`, `MetricGrid`, `VideoTile`.
- Criar componentes P2P compostos:
  `P2P.CallPanel`, `P2P.CallHeader`, `P2P.VideoSurface`,
  `P2P.CallLayoutControls`, `P2P.CallStatus`.
- Deixar `P2PMediaIsland` como wrapper stateful, sem markup pesado.
- Preservar `Lobby.MediaPanel` somente se ainda for necessario para legado; nao
  duplicar comportamento sem necessidade.

TDD:

- LiveView/component tests garantindo composicao, icones SVG e estados.
- Teste que rejeita reintroducao de emoji/inline icon em P2P call surface.

### P2P-V2 - Setup antes de aceitar/iniciar midia

Status: `CONCLUIDA`

Objetivo: dar ao usuario o mesmo controle de entrada que a conferencia, adaptado
ao P2P.

Entregar:

- Dialog de setup ao aceitar convite e ao iniciar P2P por menu/context menu.
- Preview local antes de aceitar a sessao quando o usuario pretende iniciar
  midia.
- Toggling inicial de mic/camera.
- Selecao de microfone, camera e saida de audio.
- Estado de permissao negada, camera ausente, microfone ausente e receive-only.
- Privacy mode visivel no setup quando TURN estiver configurado.
- Preferencias persistidas para defaults escalares; device ids no storage local
  escopado por usuario/browser.

TDD:

- Vitest do hook de setup com `getUserMedia`, `enumerateDevices`, permissoes e
  retry.
- LiveView tests para aceitar, cancelar, aceitar com sessao ativa e trocar.
- E2E com fake media validando preview real, join mutado, camera off e
  receive-only.

### P2P-V3 - Redesign da janela de chamada

Status: `CONCLUIDA`

Objetivo: fazer a Call P2P parecer parente direta da conferencia.

Entregar:

- Header com peer, estado WebRTC, duracao, qualidade, privacy/relay e facetas
  ativas.
- Toolbar com mic, camera, screen share, devices, PiP/self-view, layout,
  reactions e end call usando SVG catalogado.
- Empty state rico para "sessao conectada, chamada ainda nao iniciada".
- Estados claros para peer muted, peer camera off, receive-only, reconectando,
  permissao negada e device fallback.
- Manter a regra: end call encerra so a call; fechar janela encerra sessao com
  confirmacao.
- Garantir que patches LiveView nao recriem video nem troquem `srcObject`.

TDD:

- LiveView/component tests de header, toolbar, states e copy.
- Vitest para controles do hook.
- E2E validando tracks reais ao mutar/desmutar e ligar/desligar camera.
- E2E validando identidade do elemento de video e estabilidade de `srcObject`
  apos layout/timer patches.

### P2P-V4 - Layouts 1:1 avancados

Status: `CONCLUIDA`

Objetivo: dar ao P2P a mesma qualidade de layout da conferencia, com semantica
adequada para duas pessoas e possivel tela compartilhada.

Entregar:

- Modos: `auto`, `focus`, `split`, `speaker`/`peer-focus` se fizer sentido,
  `compact`.
- Self-view: `tile`, `pip`, `hidden`.
- Clique no tile remoto para focar/desfocar.
- Se screen share estiver ativo, foco automatico na tela.
- Preservar layout ao minimizar/restaurar e durante patches.
- Responsividade dentro do window manager retro; sem overflow de toolbar.

Nao entregar:

- Pin multiplo. Em 1:1 isso adiciona complexidade sem valor.
- Participant sidebar completa. Pode haver um peer strip compacto, mas nao uma
  lista de sala.

TDD:

- JS/layout tests de classes e selecao de tiles.
- E2E com screenshots desktop/mobile, bounding boxes e canvas/video vivos.

### P2P-V5 - Screen share 1:1

Status: `CONCLUIDA`

Objetivo: trazer uma das features de maior valor imediato da conferencia para o
P2P.

Entregar:

- Botao "share screen" na Call P2P.
- Uso de `navigator.mediaDevices.getDisplayMedia`.
- `source=screen` no estado local/peer e nos stats.
- Badge visual de tela compartilhada.
- Parar pelo browser limpa o estado.
- Em 1:1, permitir substituir camera pela tela inicialmente, igual ao modelo
  atual da conferencia. Camera + screen simultaneos fica fora de escopo ate
  revisar transceivers/multi-video.
- Integrar com layout: tela vira foco natural.

TDD:

- Vitest mockando `getDisplayMedia`, `track.onended` e falhas.
- LiveView tests de estado e badges.
- E2E validando source remoto, badge e retorno para camera/off.

### P2P-V6 - Estatisticas com paridade visual

Status: `CONCLUIDA`

Objetivo: manter a forca das stats P2P, mas alinhar o visual e a leitura com a
janela de stats da conferencia.

Entregar:

- Header da stats window com peer, browser state, session state, privacy/relay
  e facetas ativas.
- Secoes: Session, WebRTC, Browser connection, Audio, Video, Screen, File,
  Game.
- Session/signaling em vez de "Server SFU": role creator/peer, state,
  peer online, TURN-only, relay availability, data channels open/closed.
- Stats por source quando screen share existir.
- Tabs/fieldsets com icones SVG e copy consistente com conferencia.
- Ao fechar stats: manter a regra atual de P2P window close, ou seja,
  confirmacao de encerramento da sessao inteira.

TDD:

- Tests de normalizacao em `P2PStats`.
- Component tests para tabs/metricas e SVG.
- E2E validando stats atualizando durante call + file + game.

### P2P-V7 - Indicadores ricos no chat

Status: `CONCLUIDA`

Objetivo: fazer a sessao P2P ativa ficar tao obvia quanto a conferencia ativa.

Entregar:

- Status bar com peer, duracao de call, qualidade, privacy/relay e facetas
  ativas (call/file/game).
- PM tab glyph com estados: pending, connected, media active, transfer active,
  game active.
- Session card vivo com copy alinhado ao novo setup.
- Popover/tooltip opcional com acoes rapidas: focus windows, open call, open
  stats, end session.
- Mensagens `p2p_system` somente para eventos relevantes, sem spam.

TDD:

- LiveView tests para derivacao de display.
- E2E validando status bar antes/depois de call/file/game e troca de sessao.

## Frente de seguranca e moderacao contextual

P2P nao tem moderador de sala. A equivalencia correta de "moderacao" aqui e
seguranca 1:1, consentimento e controle da sessao.

### P2P-S1 - Confirmacoes destrutivas ricas

Status: `CONCLUIDA`

Entregar:

- Elevar `P2PConfirmDialog` para o padrao da conferencia:
  icone grande, corpo curto e lista de impactos.
- Modos: end session, close window, switch session, decline/cancel pending,
  end call, maybe block/ignore.
- Copy explicito: call, file transfer e game param ao encerrar/switch.
- Confirmacao de fechar stats/call/files/games continua encerrando a sessao
  inteira.

TDD:

- LiveView tests por modo.
- E2E fechando Call e Stats e validando que a sessao encerra so apos confirmar.

### P2P-S2 - Block/ignore como acao de seguranca

Status: `CONCLUIDA`

Entregar:

- Auditar ignore/block existente e garantir que:
  - convite P2P respeita ignore;
  - ignorar um peer ativo oferece encerrar a sessao;
  - peer ignorado nao consegue reabrir convite;
  - estado fica claro no PM.
- Considerar acao "End and ignore" no dialog, se consistente com a plataforma.

Nao entregar:

- Kick/ban por role de canal. Isso e semantica de canal, nao P2P.

TDD:

- Domain/LiveView tests para convite bloqueado e encerramento por ignore.
- E2E de tentativa de novo convite apos ignore.

### P2P-S3 - Privacidade e relay como parte da experiencia

Status: `CONCLUIDA`

Entregar:

- Mostrar privacy mode no setup, status bar e stats.
- Copy clara: TURN relay protege IP mas pode piorar latencia.
- Quando TURN nao estiver configurado, mostrar estado indisponivel sem botao
  confuso.
- Registrar preference atual como parte do setup P2P.

TDD:

- LiveView tests com `turn_configured` true/false.
- E2E visual do badge e persistencia da preferencia.

## Frente de UX refinada

### P2P-U1 - Mini mode, maximize e dock stats

Status: `CONCLUIDA`

Entregar:

- Mini mode da call P2P com mic/camera/end/expand.
- Dock stats ao lado da call sem roubar foco.
- Maximize/restore validado com video vivo.
- Posicionamento inteligente dentro do desktop.

TDD:

- E2E com bounding boxes, foco da janela primaria e video vivo apos alternar.

### P2P-U2 - Reacoes efemeras 1:1

Status: `CONCLUIDA`

Entregar:

- Reacoes `heart`, `thumbs_up`, `clap`, `laugh`, `wow` reusando icones SVG ja
  criados para conferencia.
- Overlay no tile remoto/local e indicador curto no header.
- Rate limit leve por sessao.
- Nao virar mensagem de chat por padrao.

TDD:

- Domain/LiveView/JS conforme arquitetura escolhida.
- E2E validando propagacao entre peers sem criar mensagem no PM.

### P2P-U3 - Atalhos de teclado

Status: `CONCLUIDA`

Entregar:

- Atalhos consistentes com conferencia para mute, camera, layout, foco,
  screen share e leave/end.
- Escopo: so quando a janela P2P/call esta ativa ou foco esta em chrome que nao
  seja input.
- Help topic atualizado.

TDD:

- E2E disparando atalhos e validando `MediaStreamTrack.enabled` quando aplicavel.

### P2P-U4 - Passada visual/iconografica

Status: `CONCLUIDA`

Entregar:

- Remover emojis restantes de UI P2P:
  - badge de call/file/verifying no `P2PConnectionDiagram`;
  - whois rows de screen/language/timezone/cores/color/touch.
- Criar ou catalogar icones SVG que faltarem.
- Garantir toolbar sem texto onde icone+tooltip resolve.
- Verificar overflow em todos os headers/toolbars.
- Atualizar `docs/reference/svg-catalog.md`.

TDD:

- Component tests garantindo SVG nos controles/reacoes.
- E2E smoke desktop do window manager e verificacao de overflow nos componentes.

### P2P-U5 - Help e linguagem de produto

Status: `CONCLUIDA`

Entregar:

- Atualizar `/p2p`, P2P in Chat, Universal Lobby, Video Call, Audio Call,
  Media Devices, Network Stats e Privacy Settings.
- Reduzir linguagem de "Lobby" quando a experiencia real e in-chat.
- Documentar setup, screen share, mini mode, stats, close vs minimize,
  privacy mode e sessao unica.

TDD:

- Compile/help embed tests existentes.
- Revisao manual de links cruzados.

## Nao copiar da conferencia

Estes itens sao bons na conferencia, mas nao devem virar P2P sem nova decisao:

- `mute all`;
- `camera off all`;
- lock/admission de sala;
- request-to-speak;
- fila de maos levantadas;
- lista grande de participantes;
- kick/ban por role de canal;
- matriz de permissao owner/operator/half-op para controlar o peer;
- server stats de SFU como se houvesse fanout RTP.

Equivalentes corretos no P2P:

- end session;
- switch session;
- privacy mode;
- block/ignore;
- confirmacoes claras;
- session/signaling/TURN stats;
- PM como historico persistente da comunicacao.

## Ordem recomendada

### Rodada 1 - Fundacao e call parity

1. `P2P-V1` componentes e split do call panel.
2. `P2P-S1` dialogs ricos.
3. `P2P-V3` redesign da janela de call.
4. E2E de toggles reais de mic/camera e close-confirm em Call/Stats.

Motivo: resolve a percepcao imediata de "duas features separadas" com menor
risco no WebRTC.

### Rodada 2 - Setup, preferencias e indicadores

1. `P2P-V2` setup/pre-call.
2. `P2P-S3` privacy no setup/status/stats.
3. `P2P-V7` status bar/PM/tab/session card ricos.
4. Help topics minimos.

Motivo: alinha entrada, consentimento, privacidade e discoverability.

### Rodada 3 - Features de valor alto

1. `P2P-V5` screen share.
2. `P2P-V6` stats parity incluindo screen/source.
3. `P2P-U1` mini/dock/maximize.

Motivo: aumenta valor real do P2P alem de polish visual.

### Rodada 4 - Refinamento

1. `P2P-V4` layouts avancados.
2. `P2P-U2` reacoes.
3. `P2P-U3` atalhos.
4. `P2P-U4` passada visual/iconografica.
5. `P2P-U5` help completo.

Motivo: fecha a sensacao premium e reduz divergencias restantes.

## Checklist de aceite final

- Call P2P e conferencia usam a mesma linguagem visual de header, toolbar,
  layout, stats e dialogs.
- P2P preserva suas diferencas: PM, file transfer, games, privacy mode e uma
  conexao unica.
- Nenhuma tela nova fica como markup dedicado em LiveView host.
- Nenhum novo icone visual e emoji ou SVG inline fora do catalogo.
- Fechar Call/Files/Games/Stats mostra confirmacao e so encerra apos confirmar.
- End call encerra so midia; end session encerra call/file/game.
- Status bar deixa claro quando existe sessao P2P e quais facetas estao ativas.
- Toggling de mic/camera e validado por track real, nao por botao visivel.
- Layout/mini/maximize/dock nao recriam o video nem perdem `srcObject`.
- Screen share, quando entregue, tem source/badge/stats e cleanup ao parar.
- Help topics explicam a experiencia in-chat atual.
- `make ci` passa antes de qualquer commit.

## Cobertura de regressao atual

Cobertura forte:

- setup do criador antes de enviar convite, com cancelamento sem sessao pendente;
- aceitar convite e conectar no chat;
- setup do convidado com preview/devices/receive-only/privacy relay;
- status bar conectado em ambos os peers;
- call auto-start com video remoto real;
- file transfer durante call;
- game durante call;
- video continua fluindo depois de file/game;
- screen share com `getDisplayMedia`, badge remoto e source `screen` em stats;
- mini mode, dock de stats, maximize/restore e video vivo;
- stats normalizadas com source camera/screen;
- ignore/block encerrando sessao ativa e bloqueando novo convite;
- iconografia P2P sem emoji nos componentes principais e catalogo atualizado;
- decline/cancel;
- close window com confirmacao encerrando a sessao.

Cobertura complementar mantida em testes focados:

- mic mute/unmute validado por `MediaStreamTrack.enabled`;
- camera off/on validado por `MediaStreamTrack.enabled` e indicador remoto;
- device selection e fallback de device;
- permission denied e receive-only no fluxo P2P;
- layout/foco/self-view com identidade de video preservada;
- stats window atualizando durante screen/file/game e close-confirm em Stats/Call;
- privacy mode persistido e refletido no setup/status/stats;
- visual overflow desktop no window manager;
- SVG/icon audit sem emoji;
- atalhos de teclado;
- reacoes efemeras sem mensagem no PM.

## Riscos

- Pre-call setup pode conflitar com a experiencia atual de auto-start. Mitigar
  com preferencia persistida e defaults por origem da acao.
- Extrair componentes compartilhados de conferencia pode gerar churn alto. Fazer
  em passos pequenos e manter wrappers de dominio (`GroupCall.*`, `P2P.*`).
- Screen share em P2P mexe em transceivers/renegociacao. Comecar substituindo
  camera por screen, como na conferencia atual.
- Stats P2P nao devem fingir dados de SFU. A paridade e visual e conceitual,
  nao campo-a-campo.
- Reacoes em P2P podem virar ruido se persistirem no PM. Devem ser efemeras.

## Decisao principal

A evolucao correta nao e "copiar a conferencia para o P2P". E criar uma camada
comum de experiencia de midia e aplicar ao P2P com semantica 1:1:

- conferencia = sala de canal, participantes, moderacao e SFU;
- P2P = PM, peer unico, privacidade, call/file/game numa conexao.

Com isso, a plataforma fica coerente sem perder as capacidades especificas de
cada modo de comunicacao.
