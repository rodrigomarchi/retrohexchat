# Conferencia de canal — roadmap de produto

> Plano vivo para evoluir a conferencia de canal depois da base SFU ja
> entregue. O foco e atacar tres frentes em paralelo controlado: valor imediato,
> moderacao e UX refinada, sempre com TDD e seguindo a composicao de componentes
> da plataforma.

## Objetivo

Transformar a conferencia de canal em uma experiencia de produto completa:

- previsivel para usuarios comuns;
- segura para operadores/moderadores;
- rica visualmente dentro da estetica retro da plataforma;
- validada por testes reais de midia, nao apenas por presenca de botoes.

## Regras de implementacao

- A conferencia e parte do canal. Quando a acao tem efeito disciplinar, ela
  deve respeitar a mesma politica de canal. Exemplo: kick da conferencia tambem
  remove/bane do canal quando essa for a semantica definida.
- So pode haver uma sessao de conferencia ativa por usuario. Trocar de
  conferencia exige confirmacao e encerra a sessao atual.
- O dominio fica em `apps/retro_hex_chat/lib/retro_hex_chat/group_call/**`.
- LiveViews ficam finas. Eventos em `ChatLive.GroupCallEvents` continuam como
  adaptadores/orquestradores.
- Telas novas devem ser composicao de componentes em
  `components/ui/group_call/**`, com wrappers stateful em
  `chat_live/components/**` apenas quando necessario.
- Hooks JS sao wiring de browser/WebRTC. Regra de negocio e autoridade ficam no
  servidor.
- SVG sempre via `RetroHexChatWeb.Icons`; sem SVG inline.
- Toda feature visivel ao usuario atualiza Help Topics.
- TDD e obrigatorio: dominio/LiveView/JS/E2E conforme o risco da tarefa.
- `make ci` e o gate final. Antes de commit/push em `main`: `git fetch`,
  `git status`, `git pull --ff-only` ou `--autostash` se houver edicoes locais.
- Deploy deve usar `make deploy`, nao comandos que pulem CI.

## Baseline auditado

Estado existente antes deste roadmap:

- Janela de conferencia com layout retro, header, controles, participantes e
  superficie WebRTC.
- Layouts `auto`, `grid`, `focus`, sidebar on/off, self-view `tile/pip/hidden`
  e foco em participante.
- Status bar/taskbar indicando conferencia ativa.
- Dialogs de confirmacao para sair, fechar, trocar de conferencia, encerrar sala
  e kickar participante.
- Estatisticas em janela propria com dados de servidor e browser.
- Kick/ban de participante e mute remoto de audio.
- Testes E2E validando fluxo real de midia, toggles de mic/camera, stats,
  status bar, layout/foco e renegociacao com tres usuarios.

Lacunas principais:

- Sem pre-join com preview e selecao de dispositivos.
- Sem compartilhamento de tela.
- Sem active speaker.
- Sem qualidade resumida por participante na propria conferencia.
- Sem lock/admission, request-to-speak, mute all/camera off all.
- Sem moderacao de camera imposta pelo servidor.
- Sem persistencia de preferencias de layout/dispositivos.
- Sem mini mode/fullscreen/multi-pin/filmstrip/reactions/atalhos.

## Estados

- `EXISTE`: implementado e coberto por testes suficientes.
- `PARCIAL`: existe uma parte, mas falta comportamento, UX, politica ou teste.
- `FALTA`: nao implementado.

## Frente V — valor imediato

### V1 — Pre-join, preview e selecao de dispositivos

Status: `EXISTE`

Nota de arquitetura: o pre-join combina estado server-side de sessao,
preferencias persistidas por usuario para escalares e `localStorage` por usuario
para ids de dispositivos, que sao especificos do browser. Falhas de permissao e
dispositivo ficam acionaveis no dialog sem impedir entrada receive-only.

Entregar:

- Dialog de pre-join antes de entrar na conferencia.
- Preview local de camera antes do join.
- Entrar com mic/camera ligados ou desligados.
- Selecao de microfone, camera e saida de audio quando o browser suportar.
- Estado claro para permissao negada, dispositivo ausente e midia receive-only.
- Persistencia local/per-user dos dispositivos preferidos.
- Botao de retry quando permissao/dispositivo falhar.

Componentes previstos:

- `GroupCall.PreJoinDialog`
- `GroupCall.DeviceSelect`
- `GroupCall.MediaPreview`
- `GroupCall.PermissionNotice`

TDD:

- Vitest do hook para `enumerateDevices`, `getUserMedia`, falhas e retry.
- LiveView tests para abrir pre-join, cancelar, entrar mutado e confirmar troca
  de conferencia.
- E2E com browser fake media validando preview, join mutado e tracks reais com
  `MediaStreamTrack.enabled`.
- Help topic de conferencia/pre-join/dispositivos.

### V2 — Compartilhamento de tela

Status: `EXISTE`

Nota de arquitetura: a entrega atual usa `replaceTrack` e substitui a camera
publicada pela tela compartilhada. Isso preserva o contrato SFU atual de um par
audio/video por participante remoto. Camera e tela simultaneas continuam fora do
escopo ate evoluir o fanout/transceivers do SFU para multi-video por
participante.

Entregar:

- Botao de iniciar/parar screen share.
- Uso de `navigator.mediaDevices.getDisplayMedia`.
- Track `source=screen` representada no dominio, no resumo e nas estatisticas.
- Tile especial para tela compartilhada, com icone e nameplate proprio.
- Encerramento limpo quando o usuario para pelo browser.
- Uma tela compartilhada por usuario; regra explicita se a sala aceita varias.
- Integracao com layout: tela compartilhada vira foco natural.

Componentes previstos:

- `GroupCall.ScreenShareControl`
- `GroupCall.ScreenTile`

TDD:

- Dominio/runtime para tracks `source=screen` e lifecycle `active/ended`.
- Vitest mockando `getDisplayMedia`, `track.onended` e troca de estado.
- LiveView test para botao/estado/erros.
- E2E validando que a tela compartilhada cria tile remoto e some ao parar.
- Help topic de screen share.

### V3 — Active speaker e qualidade por participante

Status: `EXISTE`

Nota de arquitetura: qualidade por participante e orador ativo sao derivados no
browser do observador a partir de `getStats()`. O dado representa a perspectiva
local sobre participantes remotos, evitando hot path pesado no servidor SFU.

Entregar:

- Deteccao de orador ativo por audio level/getStats.
- Destaque visual no tile e na lista de participantes.
- Ordenacao opcional por speaker no layout auto.
- Badge de qualidade por participante: boa, media, ruim, reconectando.
- Tooltip/popover com resumo de RTT, packet loss, bitrate e freezes.

Componentes previstos:

- `GroupCall.ParticipantQualityBadge`
- `GroupCall.ActiveSpeakerRing`

TDD:

- Vitest para agregacao de stats/audio level e debounce.
- LiveView tests para receber estado resumido e renderizar badges.
- E2E com stats sinteticos ou hook instrumentado validando classes/labels.
- Testes devem evitar hot path pesado no servidor.

### V4 — Recuperacao e estados degradados

Status: `EXISTE`

Nota de arquitetura: a recuperacao usa o browser como sensor de estado
WebRTC/ICE e o servidor SFU como autoridade para emitir uma nova oferta. O
retry manual e automatico reaproveitam a mesma chamada ativa; nao fecham a
janela nem perdem a sessao do canal.

Entregar:

- Estados visuais: conectando, negociando, reconectando, degradado, falhou.
- Retry manual quando ICE/signaling falhar.
- Backoff controlado no hook.
- Mensagens diferentes para falha de permissao, falha de rede, sala encerrada e
  politica de moderacao.
- Botao "sair e entrar novamente" quando a recuperacao automatica esgotar.

TDD:

- Runtime tests para reconnect curto, timeout e encerramento terminal.
- Vitest para channel close, ICE failed/disconnected e backoff.
- E2E simulando desconexao do canal/signaling quando viavel.

### V5 — Indicador rico de conferencia no canal

Status: `EXISTE`

Nota de arquitetura: o indicador usa summaries leves por canal, alimentados por
PubSub de inicio/fim e atualizacoes de presenca da sala. Mensagens de sistema
ficam restritas a inicio/fim para evitar spam. O estado visual `travada` ja e
suportado quando o dominio passar metadata de lock; a politica real de lock
continua em `M3`.

Entregar:

- Badge no channel list/topico com duracao, numero de participantes e estado.
- Popover/tooltip com participantes, speaker atual e acoes rapidas.
- Estados distintos: ativa, lotada, travada, degradada, encerrando.
- Mensagens de sistema no canal para inicio/fim/eventos relevantes, sem spam.

Componentes previstos:

- `GroupCall.ChannelBadge`
- `GroupCall.ChannelCallPopover`

TDD:

- LiveView tests do channel list/topic bar.
- E2E validando badge antes/depois de join/leave/end call.
- Help topic e referencias cruzadas com canais.

### V6 — Preferencias persistidas da conferencia

Status: `EXISTE`

Nota de arquitetura: preferencias escalares de conferencia usam
`user_preferences.display_settings["group_call_settings"]`. Preferencias de
dispositivo continuam em `localStorage` escopado por usuario porque `deviceId`
e local ao browser/perfil e nao deve ser tratado como configuracao global da
conta.

Entregar:

- Persistir layout preferido, self-view, sidebar, camera/mic default e
  dispositivos preferidos.
- Usar `message_settings` para preferencias escalares por usuario quando
  adequado.
- Fallback localStorage apenas para dados puramente locais de browser.

TDD:

- Tests de dominio/session settings.
- LiveView tests de carregar e salvar preferencias.
- E2E reiniciando sessao e validando que preferencias reaparecem.

## Frente M — moderacao

### M1 — Moderacao de camera

Status: `EXISTE`

Nota de arquitetura: camera-off remoto usa a mesma policy de media moderation
do canal. O servidor grava `server_video_blocked` e impede `set_media_state` de
religar video enquanto a restricao estiver ativa; o browser alvo recebe
`group_call_set_media_state` e desabilita a track local.

Entregar:

- Moderador pode desligar camera de participante.
- Servidor impede religar enquanto a restricao estiver ativa.
- UI mostra camera desligada por moderacao, diferente de camera desligada pelo
  proprio usuario.

TDD:

- Runtime test tentando burlar camera bloqueada.
- Channel/LiveView tests para evento de moderacao.
- E2E validando track local desabilitada e estado remoto propagado.

### M2 — Mute all / camera off all

Status: `EXISTE`

Nota de arquitetura: acoes em massa iteram participantes ativos e pendentes da
sala, aplicam a mesma matriz de rank por alvo e emitem um resumo PubSub para o
canal somente quando alguem foi afetado. O servidor envia estado forcado para
cada alvo e preserva pares/superiores.

Entregar:

- Acoes de moderador para mutar todos e desligar cameras de todos.
- Excecoes para o proprio moderador/roles superiores quando a politica exigir.
- Confirmacao antes de acoes em massa.
- Mensagem de sistema resumida.

TDD:

- Policy/runtime tests por papel.
- LiveView tests para confirmacao e resultado.
- E2E com tres usuarios validando propagacao real.

### M3 — Lock da conferencia

Status: `EXISTE`

Nota de arquitetura: o lock vive em `room.metadata` como `locked` e
`admission_locked`, para manter compatibilidade com summaries existentes. A
policy de join bloqueia usuarios abaixo de moderador e permite
`half_operator` ou superior entrar em sala travada para destravar ou moderar.
Mudancas de lock emitem resumo PubSub e atualizam o indicador vivo do canal.

Entregar:

- Moderador trava entrada de novos participantes na conferencia.
- Usuarios no canal continuam no canal; a regra de lock afeta join da chamada.
- UI mostra estado travado e explica quem pode destravar.
- Tentar entrar em conferencia travada mostra erro acionavel.

TDD:

- Runtime/policy tests para join negado.
- Channel tests para erro de join.
- E2E validando badge locked e tentativa de entrada negada.

### M4 — Request to speak / levantar mao

Status: `EXISTE`

Nota de arquitetura: o pedido de fala usa `media_state` do participante
(`hand_raised`, `hand_raised_at`, `hand_raised_by`) para evitar tabela nova e
propagar pelo mesmo fluxo de summary/media state da conferencia. A fila e
ordenada por `hand_raised_at`. Moderadores usam `allow_participant_speak`, que
desmuta pelo servidor e baixa a mao no mesmo update, respeitando a policy por
rank.

Entregar:

- Participante pode levantar/baixar mao.
- Moderador ve fila/ordem.
- Integracao com mute all: moderador pode permitir fala.
- Indicador no tile, lista e popover do canal.

TDD:

- Runtime tests para estado e ordenacao.
- LiveView tests para fila e acoes de moderador.
- E2E com dois/tre participantes.

### M5 — Moderacao de screen share

Status: `EXISTE`

Depende de: `V2`

Nota de arquitetura: o bloqueio de screen share reutiliza a mesma policy de
moderacao de midia. O servidor registra `server_screen_blocked` no
`media_state`, interrompe a publicacao ativa, remove ids de screen track/stream
e impede que o browser volte a compartilhar ate um moderador liberar. O hook
recebe estado forcado e tambem trata rejeicao do servidor para impedir
reativacao por race de browser.

Entregar:

- Moderador pode parar screen share de participante.
- Politica para permitir/bloquear screen share por role.
- Bloqueio temporario de novo share quando imposto por moderador.

TDD:

- Runtime tests para bloqueio de `source=screen`.
- Vitest/E2E validando parada forcada no browser.

### M6 — Auditoria e mensagens administrativas

Status: `EXISTE`

Nota de arquitetura: eventos administrativos da conferencia sao persistidos em
`room.metadata["audit_events"]` com limite de 100 itens por sala e payload
estruturado (`type`, `actor`, `target`, `kind`, contadores e timestamp).
Eventos relevantes tambem seguem por PubSub como `:group_call_moderation` para
mensagens de sistema no canal ativo. Updates frequentes de presenca/midia
continuam em `:group_call_updated`/eventos de hook e nao viram spam no chat.

Entregar:

- Historico estruturado de eventos: iniciou, encerrou, kickou, mutou,
  desligou camera, travou, destravou, screen share iniciado/parado.
- Eventos relevantes aparecem como mensagem de sistema no canal.
- Dados suficientes para suporte/debug sem vazar informacao sensivel.

TDD:

- Domain tests de audit event.
- LiveView tests de mensagem de sistema.
- Tests garantindo que eventos de alta frequencia nao viram spam.

### M7 — Matriz explicita de permissoes

Status: `EXISTE`

Nota de arquitetura: a conferencia herda a hierarquia do canal. A matriz viva
esta documentada em `docs/plans/conferencia-canal-permissoes.md`; o servidor
continua autoridade final e a UI apenas esconde acoes que a policy recusaria.

Entregar:

- Documento e tests para permissoes por role: owner/operator/half-op/voiced/
  member/guest.
- Cada acao de moderacao tem policy test proprio.
- UI esconde acoes que o usuario nao pode executar.

TDD:

- Policy unit tests por acao.
- LiveView tests garantindo botoes ocultos por role.

## Frente U — UX refinada

### U1 — Mini mode

Status: `EXISTE`

Nota de arquitetura: mini mode e estado de layout da chamada
(`call.layout.mini`) e nao uma segunda janela. O mesmo `GroupCallPanel` troca a
composicao visual, mantendo `VideoSurface` e o subtree `GroupCallWebRTCHook`
montados com o mesmo token para preservar streams, peer connection e raw
signaling.

Entregar:

- Modo compacto persistente enquanto o usuario navega pelo chat.
- Mantem controles essenciais: mic, camera, sair, expandir.
- Nao desmonta hook nem recria streams.

TDD:

- LiveView tests para alternar mini/normal.
- E2E validando que video remoto continua vivo depois da troca.

### U2 — Fullscreen, maximize e organizacao de janelas

Status: `EXISTE`

Nota de arquitetura: maximize/restore continua no WindowManager generico. Para
organizar conferencia + estatisticas, o hook ganhou `window_command`
`dock_pair`, que posiciona duas janelas lado a lado, abre a secundaria quando
necessario e mantem foco na primaria. A conferencia expoe isso por um botao
composto no header, sem acoplar geometria a LiveView.

Entregar:

- Modo fullscreen/maximize para conferencia.
- Posicionamento inteligente da janela de stats sem roubar foco.
- Opcao de dock/snap da stats window ao lado da conferencia.
- Confirmacao continua valendo ao fechar stats/conferencia.

TDD:

- Window manager tests.
- E2E com screenshots desktop/mobile para evitar overlap incoerente.

### U3 — Layouts avancados

Status: `EXISTE`

Nota de arquitetura: layouts avancados continuam como estado leve em
`call.layout` e payload `group_call_layout_state`. O hook aplica speaker view,
pins e densidade de grid no DOM ignorado pelo LiveView, sem recriar videos ou
streams. Speaker view usa `active_speaker_participant_id` derivado no browser;
quando o SFU ainda nao associou o tile ao participante, a instrumentacao de
qualidade conserva o fallback de unico tile remoto sem dono.

Entregar:

- Speaker view.
- Filmstrip inferior/lateral.
- Multi-pin.
- Compact grid para muitas pessoas.
- Regras responsivas para 1/2/3/4/5+ participantes.

TDD:

- JS/layout tests para classes e selecao de tiles.
- E2E com 2 e 3 browsers reais; cenarios maiores ficam em janela dedicada.
- Screenshot assertions para regressao visual.

### U4 — Reactions

Status: `EXISTE`

Nota de arquitetura: reactions sao eventos efemeros da sala enviados pelo canal
SFU (`group_call_reaction`) e validados no dominio com rate limit leve por
usuario/sala. O RoomServer faz broadcast para os sockets da conferencia; o hook
renderiza overlays temporarios dentro dos tiles e a LiveView espelha um resumo
curto para a lista de participantes, sem persistir mensagens no chat.

Entregar:

- Reacoes temporarias no tile e na lista.
- Rate limit leve para evitar spam.
- Historico curto opcional no canal ou apenas overlay efemero.

TDD:

- Runtime/rate limit tests.
- LiveView tests para renderizacao.
- E2E validando propagacao entre usuarios.

### U5 — Atalhos de teclado

Status: `EXISTE`

Entregar:

- Atalhos para mute, camera, leave, foco, layout e push-to-talk se definido. `EXISTE`
- Descoberta via Help Topics. `EXISTE`
- Nao conflitar com atalhos globais do chat. `EXISTE`

TDD:

- Keyboard event tests. `EXISTE`
- E2E disparando atalhos e validando track real quando aplicavel. `EXISTE`

### U6 — Acessibilidade

Status: `EXISTE`

Entregar:

- Navegacao completa por teclado na janela. `EXISTE`
- Focus order previsivel. `EXISTE`
- Labels especificos por acao/participante. `EXISTE`
- Estados `aria-pressed`, `aria-live` e mensagens de erro consistentes. `EXISTE`

TDD:

- LiveView tests para atributos criticos. `EXISTE`
- E2E keyboard-only nos fluxos principais. `EXISTE`

### U7 — Estados vazios e falhas de permissao

Status: `EXISTE`

Entregar:

- Empty states ricos para aguardando participantes, camera indisponivel,
  permissao negada, chamada travada, sala cheia e reconnect. `EXISTE`
- Acoes claras em cada estado: retry, abrir configuracoes, sair, pedir fala.
  `EXISTE`

TDD:

- Component tests/LiveView tests por estado. `EXISTE`
- E2E para permissao negada e receive-only. `EXISTE`

### U8 — Passada visual e iconografica

Status: `EXISTE`

Entregar:

- Revisar todos os controles para iconografia semantica. `EXISTE`
- Criar novos icones SVG no catalogo quando nao houver icone adequado. `EXISTE`
- Garantir que labels nao estourem em desktop/mobile. `EXISTE`
- Atualizar showcase/catalogo quando novos icones forem adicionados. `EXISTE`

TDD:

- `make lint.css`/catalog checks. `EXISTE`
- Screenshot pass via Playwright nos tamanhos principais. `EXISTE`

## Ordem de execucao recomendada

### Rodada 1 — valor imediato fundacional

1. `V1` Pre-join, preview e selecao de dispositivos.
2. `V6` Preferencias persistidas minimas usadas pelo pre-join.
3. `V2` Screen share.
4. `V3` Active speaker e qualidade por participante.
5. `V5` Indicador rico de conferencia no canal.

### Rodada 2 — moderacao completa

1. `M7` Matriz explicita de permissoes.
2. `M1` Moderacao de camera.
3. `M2` Mute all / camera off all.
4. `M3` Lock da conferencia.
5. `M4` Request to speak.
6. `M5` Moderacao de screen share.
7. `M6` Auditoria e mensagens administrativas.

### Rodada 3 — UX refinada

1. `U1` Mini mode.
2. `U2` Fullscreen/maximize e organizacao de janelas.
3. `U3` Layouts avancados.
4. `U4` Reactions.
5. `U5` Atalhos.
6. `U6` Acessibilidade.
7. `U7` Estados vazios/falhas.
8. `U8` Passada visual/iconografica.

## Checklist por bloco de trabalho

Antes de implementar:

- [x] Atualizar `conferencia-canal-roadmap-PROGRESS.md` com o bloco iniciado.
- [x] Escrever ou ajustar testes que expressem o comportamento esperado.
- [x] Confirmar onde cada responsabilidade vive: dominio, LiveView adapter,
      componente UI, hook JS ou help docs.

Durante a implementacao:

- [x] Componentes de tela ficam em `components/ui/group_call/**`.
- [x] Wrappers LiveComponent ficam sem markup dedicado pesado.
- [x] Hook JS nao ganha regra de negocio de dominio.
- [x] SVGs novos passam pelo catalogo/facade `Icons`.
- [x] Estados de erro/warning sao acionaveis.

Antes de concluir:

- [x] Teste funcional prova comportamento real, nao apenas presenca visual.
- [x] Help Topics atualizados.
- [x] `git diff --check`.
- [x] Testes focados relevantes.
- [x] `make ci` antes de considerar o bloco pronto para commit/deploy.
- [x] Atualizar progresso e aprendizados.
