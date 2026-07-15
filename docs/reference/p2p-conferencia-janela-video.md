# P2P x conferencia - janela de video

> Fotografia do comportamento atual em 2026-07-15. Escopo restrito as janelas
> de video/chamada: `P2P Call` e `Group Call`. Setup, stats, arquivos, jogos,
> topic bar, status bar e taskbar so aparecem aqui quando afetam diretamente a
> janela de video.

## Resumo da diferenca

| Tema | P2P Call | Group Call |
|---|---|---|
| Janela | `p2p-call` | `group-call` |
| Corpo | `P2PMediaIsland` + `P2P.CallPanel` | `GroupCallPanel` + `GroupCall.Panel` |
| Escopo | 1:1 com um peer | N:N em um canal |
| Video principal | Tile remoto do peer | Grid de tiles locais/remotos |
| Self-view | Tile, PiP ou hidden | Tile, PiP ou hidden |
| Painel lateral | Nao tem | Participantes, fila de maos, moderacao |
| Toolbar | Left rail de view + rodape de midia/reacoes/end | Header de janela/moderacao + left rail de layout + rodape de midia/reacoes/leave |
| X da janela | Confirma encerrar sessao P2P inteira | Confirma sair da conferencia |
| Botao interno de encerrar | `End call` encerra so a midia da call | `Leave` sai da conferencia |

## Layout lado a lado

```text
+============================ P2P Call ============================+   +============================ Group Call ===========================+
| Window chrome                                                     |   | Window chrome                                                     |
| [camera] <peer ou P2P Call>                           [_][ ][X]   |   | [conference] #canal                                   [_][ ][X]   |
|                                                                  |   |                                                                  |
| +-- Header -----------------------------------------------------+ |   | +-- Header -----------------------------------------------------+ |
| | [P2P 32] peer/status/tracks/duration/flags                   | |   | | [Conf 32] #canal/status/users/tracks [Stats][Mini][Moderation]| |
| +---------------------------------------------------------------+ |   | +---------------------------------------------------------------+ |
|                                                                  |   |                                                                  |
| +-- Stage -----------------------------------------------+      |   | +-- Stage --------------------------------+ +-- Participants --+ |
| | Rail: layout/self-view/PiP/devices/stats/mini          |      |   | | Rail: auto/grid/focus/speaker/sidebar  | | rows/actions 32  | |
| |                                                        |      |   | | Media grid: local + remote tiles       | | quality/media 32 | |
| | Remote tile + local self-view + reaction overlays      |      |   | | waiting/local empty 64, badges 32      | | raised hands     | |
| +--------------------------------------------------------+      |   | +---------------------------------------+ +-----------------+ |
|                                                                  |   |                                                                  |
| +-- Bottom controls -------------------------------------------+ |   | +-- Bottom controls -------------------------------------------+ |
| | [Mic 32] [Camera 32] [Screen 32] [React 32] [End 32]         | |   | | [Mic 32] [Camera 32] [Screen 32] [Raise 32] [React] [Leave]  | |
| +---------------------------------------------------------------+ |   | +---------------------------------------------------------------+ |
| +-- Device selects expansivel, se carregados ------------------+ |   | +-- Error/warning strip, se houver -----------------------------+ |
| | microphone/camera/speaker                                    | |   | | [Warning 32] message [Retry 32] [Leave 32]                   | |
| +---------------------------------------------------------------+ |   | +---------------------------------------------------------------+ |
+==================================================================+   +==================================================================+
```

## P2P Call em detalhe

### Janela desktop

```text
+--------------------------- p2p-call ---------------------------+
| title: <peer_nick> ou "P2P Call"                               |
| default: x=496 y=48 width=460                                  |
| mini: width=300 height=236 anchor bottom_right                  |
| min: 260 x 180                                                  |
| body: p-1                                                       |
| on_close: p2p_window_close                                      |
+----------------------------------------------------------------+
```

Regras da janela:

| Acao | Resultado |
|---|---|
| Abrir/focar `p2p-call` | Mostra a janela de chamada da sessao P2P ativa |
| Minimizar | Mantem WebRTC e sessao vivos |
| X da janela | Abre confirmacao para encerrar a sessao P2P inteira |
| `End call` interno | Encerra a midia da chamada e fecha a janela de call, mas a sessao P2P pode continuar |
| `Mini call window` | Reduz geometria e esconde controles secundarios |
| `Expand call window` | Volta para geometria normal |

### Estado desconectado

```text
+------------------------- P2P media offline --------------------+
|                           [P2P icon]                           |
|                       P2P media is offline                      |
|              Connect to start an audio or video call.           |
+----------------------------------------------------------------+
```

Renderiza quando a sessao P2P ainda nao esta conectada.

### Estado conectado, sem midia local/remota

```text
+----------------------- Ready for private media ----------------+
|                            [WebRTC icon]                       |
|                    Ready for private media                     |
|  Start audio or video - or the peer can, independently.         |
|  You'll join automatically.                                    |
|                                                                |
|                  [Start audio] [Start video]  <peer>           |
+----------------------------------------------------------------+
```

Esse estado e importante: P2P nao exige que os dois liguem midia ao mesmo
tempo. Cada peer controla a propria camera/microfone.

### Chamada ativa

```text
+--------------------------- Active P2P Call --------------------+
| Header                                                         |
| +------------------------------------------------------------+ |
| | [P2P] Direct call with <peer>                              | |
| | status icon + label | 1:1 | track summary                  | |
| | duration, se houver | peer mic/camera/screen flags         | |
| +------------------------------------------------------------+ |
|                                                                |
| Video area                                                     |
| +------------------------------------------------------------+ |
| | Remote tile                                                | |
| |  - quality badge, se houver                               | |
| |  - <video id=lobby-remote-video>                           | |
| |  - camera-off state quando peer camera off                 | |
| |  - nameplate: peer + mute/camera/screen icons              | |
| |  - peer reaction stack                                     | |
| |                                                            | |
| |        +-- Local tile --------------------------------+     | |
| |        | <video id=lobby-local-video>                 |     | |
| |        | nameplate: You ou Your screen                |     | |
| |        | local reaction stack                         |     | |
| |        +----------------------------------------------+     | |
| |                                                            | |
| | <audio id=lobby-remote-audio>                              | |
| +------------------------------------------------------------+ |
|                                                                |
| Peer muted strip, se peer estiver mutado                       |
| +------------------------------------------------------------+ |
| | [mute] <peer> is muted                                     | |
| +------------------------------------------------------------+ |
|                                                                |
| Left rail                                                      |
| +------------------------------------------------------------+ |
| | layout/self-view/PiP/devices/stats/mini                    | |
| +------------------------------------------------------------+ |
|                                                                |
| Bottom controls                                                |
| +------------------------------------------------------------+ |
| | audio/video/screen/react/end                               | |
| +------------------------------------------------------------+ |
+----------------------------------------------------------------+
```

### Controles P2P

| Controle | Zona | Quando aparece | Acao |
|---|---|---|---|
| `Turn on microphone` | Rodape | Call ativa sem audio local | Liga microfone |
| `Mute` / `Unmute` | Rodape | Audio local ativo | Alterna mute local |
| `Turn on camera` | Rodape | Call ativa sem video local | Liga camera |
| `Camera Off` / `Camera On` | Rodape | Video local ativo | Alterna camera local |
| `Share screen` / `Stop sharing screen` | Rodape | Sempre na call ativa | Inicia/para captura de tela |
| `React` | Rodape | Nao-mini | Abre flyout de reacoes |
| `Heart` / `Thumbs up` / `Clap` / `Laugh` / `Sparkle` | Flyout `React` | Nao-mini | Envia reacao efemera |
| `Picture-in-Picture` | Left rail | Peer tem video | Aciona PiP via hook |
| `Devices` | Left rail | Nao-mini | Pede/mostra seletores de dispositivos |
| `Dock statistics` | Left rail; rodape no mini | Sempre na call ativa | Abre `p2p-stats` e doca ao lado |
| `Mini call window` / `Expand call window` | Left rail; rodape no mini | Sempre na call ativa | Alterna mini mode |
| `End call` | Rodape | Sempre na call ativa | Encerra midia da chamada |

### Controles de layout P2P

So aparecem fora do mini mode quando ha video local ou remoto.

```text
[Auto] [Focus] [Split] [Speaker] [Compact] [Self-view cycle]
```

| Layout | Intencao |
|---|---|
| `auto` | Escolha automatica; hoje cai no comportamento tipo split quando self-view e tile |
| `focus` | Peer remoto em foco |
| `split` | Remote/local lado a lado quando self-view e tile |
| `speaker` | Variante focada em quem fala/remote principal |
| `compact` | Superficie de video menor |
| self-view cycle | `tile -> pip -> hidden -> tile` |

### Mini mode P2P

```text
+---------------- Mini P2P Call ---------------+
| Header compacto + video principal             |
| controles essenciais:                         |
|   mic/camera/screen/stats/expand/end          |
| sem reacoes, sem layout toolbar, sem devices  |
+-----------------------------------------------+
```

O mini mode e uma geometria da janela. Ele nao encerra midia nem troca a
sessao.

## Group Call em detalhe

### Janela desktop

```text
+--------------------------- group-call -------------------------+
| title: #canal ou "Group Call"                                  |
| default: x=448 y=72 width=640 height=430                       |
| min: 500 x 320                                                  |
| body: h-full min-h-0 overflow-hidden p-1                       |
| on_close: group_call_window_close                              |
+----------------------------------------------------------------+
```

Regras da janela:

| Acao | Resultado |
|---|---|
| Abrir/focar `group-call` | Mostra a conferencia ativa |
| Minimizar | Mantem conferencia e WebRTC vivos |
| X da janela | Abre confirmacao "Close Group Call?" com acao `Leave call` |
| Confirmar close/leave | Sai da conferencia |
| Cancelar close | Reabre a janela que tentou fechar |
| `Leave` interno | Abre confirmacao para sair |
| `Switch to compact conference mode` | Alterna mini mode |

### Header normal

```text
+---------------------------- Header ----------------------------+
| [conference] #canal                                            |
|              status | participant count | track count          |
|                                                                |
| Window controls:                                               |
|   [dock conference statistics] [mini mode]                     |
|                                                                |
| Moderation controls, se o usuario pode moderar:                |
|   [end group call] [lock/unlock] [mute all] [camera off all]   |
+----------------------------------------------------------------+
```

Layout/view ficam no left rail:

```text
[auto] [grid] [focus] [speaker] [sidebar] [self-view] [clear focus]
```

Midia/participacao ficam no rodape:

```text
[microphone] [camera] [screen share] [raise hand] [reactions] [leave]
```

### Header mini

```text
+---------------------- Mini conference header ------------------+
| [conference] #canal                      [mic] [camera] [expand] [leave] |
| status | participant count                                           |
+----------------------------------------------------------------+
```

No mini mode:

- o painel de participantes nao aparece;
- os controles ficam reduzidos a mic, camera, expand e leave;
- a video surface continua montada.

### Superficie de video

```text
+--------------------------- Video surface ----------------------+
| Hook raiz: GroupCallWebRTCHook                                 |
|                                                                |
| +-- Remote placeholder --------------------------------------+ |
| | [conference icon] Waiting for participants                  | |
| | Remote cameras and shared screens appear here as people join| |
| +------------------------------------------------------------+ |
|                                                                |
| +-- Local tile ----------------------------------------------+ |
| | <video data-group-call-local-video>                        | |
| | empty state quando camera/tela nao renderiza:              | |
| |   - Sharing screen                                         | |
| |   - Receive-only mode                                      | |
| |   - Camera off                                             | |
| |   - Camera preview starting                                | |
| | nameplate: nickname + audio/video/screen badges            | |
| +------------------------------------------------------------+ |
|                                                                |
| +-- Remote tile template ------------------------------------+ |
| | nameplate: remote nickname                                 | |
| | badges: audio, video, screen, active speaker, quality       | |
| | reacoes efemeras no tile                                   | |
| +------------------------------------------------------------+ |
+----------------------------------------------------------------+
```

O subtree do hook usa `phx-update="ignore"` para a camada de midia sobreviver a
patches LiveView sem recriar os elementos de video.

### Grid principal com participantes

```text
+---------------------------- Group Call body -------------------+
| +-- Video grid --------------------------------+ +-- Sidebar --+ |
| | local tile                                  | | Participants| |
| | remote tiles                                | | count       | |
| | focused/pinned/active speaker states        | | raised hand | |
| | quality/reaction overlays                   | | rows        | |
| +---------------------------------------------+ +-------------+ |
+----------------------------------------------------------------+
```

O body usa duas colunas quando `sidebar_open` esta ativo e a janela nao esta em
mini mode:

```text
grid-cols-[minmax(0,1fr)_14rem]
```

Quando o painel lateral esta fechado, ou no mini mode, a janela vira uma coluna
so com a video surface.

### Painel de participantes

```text
+------------------------- Participants -------------------------+
| Header: Participants + count                                   |
|                                                                |
| Requests to speak, se houver                                   |
| +------------------------------------------------------------+ |
| | posicao | nickname                       [allow speak]      | |
| +------------------------------------------------------------+ |
|                                                                |
| Participant row                                                |
| +------------------------------------------------------------+ |
| | role icon | nickname | active speaker | hand | reaction     | |
| | status line                                                 | |
| | [More] abre focus, pin, allow speak, moderacao,             | |
| |        indicadores audio/video/screen e quality             | |
| +------------------------------------------------------------+ |
+----------------------------------------------------------------+
```

Controles por participante:

| Controle | Quando aparece | Acao |
|---|---|---|
| Focus | Sempre no row | Coloca participante em foco |
| Pin | Sempre no row | Fixa/desfixa participante |
| Allow speak | Participante com mao levantada e usuario pode moderar | Permite falar |
| Moderate audio | Usuario pode moderar participante | Muta/libera microfone remoto |
| Moderate video | Usuario pode moderar camera do participante | Desliga/libera camera remota |
| Moderate screen | Usuario pode moderar screen share | Para/libera compartilhamento |
| Kick/ban | Usuario pode remover participante | Remove da conferencia e bane do canal |
| Quality badge | Quando ha qualidade calculada | Mostra nivel de qualidade |

### Barras de erro e aviso

```text
+------------------------ Connection needs attention ------------+
| [warning] Connection needs attention                            |
|           <mensagem de erro>                         [Retry] [Leave] |
+----------------------------------------------------------------+

+------------------------ Media warning -------------------------+
| [warning] Media warning                                [Leave] |
|           <mensagem de aviso>                                  |
+----------------------------------------------------------------+
```

| Barra | Quando | Acoes |
|---|---|---|
| Error | `@call.error` presente | `Retry` se disponivel, `Leave` sempre |
| Warning | `@call.warning` presente e sem erro | `Leave` |

## Comparativo dos controles de video

| Area | P2P Call | Group Call |
|---|---|---|
| Start audio/video dentro da janela | Sim, quando idle | Nao; midia inicial vem do pre-join e depois toggles |
| Toggle mic | Mute/unmute local | Toggle microphone local |
| Toggle camera | Camera on/off local | Toggle camera local |
| Enable audio/video depois de receive-only | Sim | Sim por toggles da conferencia |
| Screen share | Sim, no rodape P2P | Sim, no rodape da conferencia |
| PiP | Botao dedicado quando peer tem video | Self-view cycle inclui PiP |
| Layouts | Auto, focus, split, speaker, compact | Auto, grid, focus, speaker |
| Self-view | Tile/PiP/hidden | Tile/PiP/hidden |
| Reacoes | Heart, thumbs up, clap, laugh, sparkle | Heart, thumbs up, clap, laugh, wow |
| Quality | Badge no tile remoto e resumo da call | Badge por participante e stats por observador |
| Active speaker | Nao e centro da UI 1:1 | Badge/ring em tile/lista |
| Participantes | Peer unico, sem lista | Lista lateral com acoes |
| Moderacao | Nao existe na janela | Existe conforme permissao/role |
| Retry de midia | Nao aparece como barra dedicada no painel P2P | Barra de erro com Retry manual |
| End interno | `End call`: termina midia | `Leave`: sai da conferencia |

## Fluxos de clique

### P2P Call

```text
Sessao P2P conectada
  -> p2p_open_call
  -> abre janela p2p-call
  -> se call idle:
       Start audio/video
       -> LobbyMediaHook pede getUserMedia
       -> call vira ativa
  -> se call ativa:
       toggles locais atualizam local + avisam peer
       screen share usa getDisplayMedia
       reactions trafegam pela sessao
       End call encerra midia
  -> X da janela:
       p2p_window_close
       -> P2PConfirmDialog
       -> confirmar encerra sessao P2P inteira
```

### Group Call

```text
Usuario entrou na conferencia
  -> open_call_windows
  -> abre group-call
  -> GroupCallWebRTCHook monta video surface
  -> toggles locais atualizam estado da sala
  -> layout/sidebar/self-view alteram leitura visual
  -> moderacao altera permissoes/estado de outros participantes
  -> erro de midia mostra barra Retry/Leave
  -> Leave ou X:
       GroupCallConfirmDialog
       -> confirmar sai da conferencia
```

## O que olhar quando comparar visualmente

| Pergunta | Onde olhar no P2P | Onde olhar na conferencia |
|---|---|---|
| Quem e o contexto da chamada? | Header: `Direct call with <peer>` | Header: `#canal` |
| Quantas pessoas existem? | Header fixa `1:1` | Header e sidebar contam participantes |
| Onde esta meu video? | Local tile, PiP ou hidden | Local tile, PiP ou hidden na grid |
| Onde esta o video remoto? | Remote tile unico | Remote tiles dinamicos |
| Como mudo layout? | Left rail da call | Left rail da conferencia |
| Como abro stats? | `Dock statistics` no left rail | `Dock conference statistics` no header |
| Como vejo devices? | `Devices` e bloco expansivel de selects dentro da call | Devices sao escolhidos no pre-join, nao no corpo principal |
| Como saio sem matar tudo? | Minimizar; `End call` mata so midia | Minimizar mantem; `Leave` sai da conferencia |
| O que o X faz? | Confirma fim da sessao P2P | Confirma saida da conferencia |

## Fontes do codigo lidas

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/group_call_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_media_island.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/group_call_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/call_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/video_surface.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/layout_controls.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/screen_share_control.ex`
