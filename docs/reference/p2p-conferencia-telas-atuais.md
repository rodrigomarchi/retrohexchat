# P2P x conferencia - telas atuais

> Fotografia do comportamento atual em 2026-07-14. Este documento descreve as
> telas como estao hoje no chat desktop, sem propor redesign.

## Resumo rapido

| Tema | P2P | Conferencia |
|---|---|---|
| Escopo | Sessao 1:1 ancorada em PM | Sala de midia ancorada em canal |
| Entrada principal | `/p2p <nick>`, contexto de usuario, convite no PM | Botao `Call` na topic bar do canal |
| Setup antes de entrar | `P2P Setup` | `Join Channel Conference` |
| Janelas principais | `P2P Call`, `P2P Files`, `P2P Games`, `P2P Statistics` | `Group Call`, `Conference Statistics` |
| Conversa | O PM e a conversa da sessao | O canal continua sendo a conversa |
| Indicador fora da janela | PM/tabs/sidebar/status bar/taskbar | Canal/tabs/sidebar/topic bar/status bar/taskbar |
| Media | Browser a browser, com TURN opcional | Browser envia para servidor da sala, servidor roteia |
| Fechar com X | Pede confirmacao para encerrar a sessao P2P | Pede confirmacao para sair da conferencia |
| Minimizar | Mantem a sessao rodando | Mantem a conferencia rodando |

## Mapa geral lado a lado

```text
+======================= P2P: PM / 1:1 =======================+   +================== Conferencia: canal / N:N ==================+
| Desktop do chat                                             |   | Desktop do chat                                             |
|                                                             |   |                                                             |
| +-- RetroHexChat (janela principal, pinned) --------------+ |   | +-- RetroHexChat (janela principal, pinned) --------------+ |
| | Sidebar/tabs: PM @peer com glyph/badge P2P              | |   | | Sidebar/tabs: #canal com glyph/badge Call                | |
| | Topic bar: [Chat] [Space] [P2P + info popover]          | |   | | Topic bar: [Chat] [Space] [Call + info popover]          | |
| | Mensagens PM + convite + avisos de feature              | |   | | Mensagens do canal continuam no buffer do canal           | |
| +---------------------------------------------------------+ |   | +---------------------------------------------------------+ |
|                                                             |   |                                                             |
| +-- P2P Call --------+  +-- P2P Stats -------------------+  |   | +-- Group Call ------------------------------------------+ |
| | video/audio 1:1   |  | Network Audio Video Game File  |  |   | | video grid + participantes + controles de sala          | |
| +-------------------+  +---------------------------------+  |   | +--------------------------------------------------------+ |
| +-- P2P Files ------+  +-- P2P Games -------------------+  |   | +-- Conference Stats ------------------------------------+ |
| | drop/progresso    |  | catalogo/canvas/resultado     |  |   | | Server, runtime, browser, audio, video                  | |
| +-------------------+  +---------------------------------+  |   | +--------------------------------------------------------+ |
|                                                             |   |                                                             |
| Status bar: P2P peer, facetas, qualidade, stop              |   | Status bar: Call #canal, participantes, stop              |
+=============================================================+   +=============================================================+
```

## Entrada e setup

### Antes de abrir a sessao

```text
+------------------------- P2P Setup -------------------------+   +------------------ Join Channel Conference ------------------+
| Dialog: Prepare P2P Invite ou Start P2P Session             |   | Dialog: Join Channel Conference                            |
|                                                            |   |                                                            |
| +-- Preview ---------------------------------------------+ |   | +-- Preview ---------------------------------------------+ |
| | video local, estado de devices, aviso, Retry           | |   | | video local, estado de devices, aviso de permissao      | |
| +--------------------------------------------------------+ |   | +--------------------------------------------------------+ |
|                                                            |   |                                                            |
| +-- Connect with <peer> ---------------------------------+ |   | +-- Conference topology ---------------------------------+ |
| | explica se e convite enviado ou entrada na sessao      | |   | | browser -> room server -> outros participantes          | |
| +--------------------------------------------------------+ |   | +--------------------------------------------------------+ |
| +-- Direct P2P topology ---------------------------------+ |   | +-- Join settings ---------------------------------------+ |
| | browser-to-browser ou relay TURN                       | |   | | [ ] Join with microphone                                | |
| +--------------------------------------------------------+ |   | | [ ] Join with camera                                    | |
| +-- Initial media ---------------------------------------+ |   | | [ ] Show participants panel                             | |
| | [ ] Start with microphone                              | |   | +--------------------------------------------------------+ |
| | [ ] Start with camera                                  | |   | +-- Devices ---------------------------------------------+ |
| | receive-only quando ambos desligados                   | |   | | Microphone / Camera / Speaker selects                   | |
| +--------------------------------------------------------+ |   | +--------------------------------------------------------+ |
| +-- Devices ---------------------------------------------+ |   | +-- Layout ----------------------------------------------+ |
| | Microphone / Camera / Speaker selects                  | |   | | Layout: Auto/Grid/Focus                                 | |
| +--------------------------------------------------------+ |   | | Self view: Tile/PiP/Hidden                              | |
| +-- Privacy relay ---------------------------------------+ |   | +--------------------------------------------------------+ |
| | [ ] Force WebRTC through relay                         | |   |                                                            |
| +--------------------------------------------------------+ |   | Footer: [Join call] [Cancel]                             |
| Footer: [Send invite ou Join session] [Cancel]             |   +------------------------------------------------------------+
+-------------------------------------------------------------+
```

### Diferenca de semantica

| Area | P2P | Conferencia |
|---|---|---|
| O que o setup cria | Uma sessao 1:1 com call, file, game e stats disponiveis | Uma entrada em sala de conferencia do canal |
| Texto de topologia | "Direct P2P topology" | "Conference topology" |
| Privacidade | Pode forcar relay TURN quando configurado | Nao tem toggle de relay por usuario |
| Layout inicial | Nao escolhe layout no setup; escolhe postura de midia | Escolhe layout e self-view antes de entrar |
| Participants panel | Nao existe, porque e 1:1 | Pode abrir/fechar antes de entrar |

## Janelas P2P

### P2P Call

```text
+------------------------------ P2P Call: <peer> ------------------------------+
| Header                                                                       |
| [P2P] Direct call with <peer>                                                 |
|       status | 1:1 | tracks                                                  |
|                                                   duration | peer media flags |
|                                                                              |
| +-- Remote tile ------------------------------------------------------------+ |
| | quality badge                                                             | |
| | remote video ou "peer camera is off"                                      | |
| | nameplate: <peer>, mic muted, camera off, screen share                    | |
| | reaction stack do peer                                                    | |
| +--------------------------------------------------------------------------+ |
|       +-- Local tile ------------------------------------------------+        |
|       | self-view: tile, PiP ou hidden                               |        |
|       | label: You ou Your screen                                    |        |
|       | reaction stack local                                         |        |
|       +--------------------------------------------------------------+        |
|                                                                              |
| Media toolbar                                                                |
| [mic on] [mute/unmute] [camera on] [camera off] [PiP] [screen share]         |
| [heart] [thumbs up] [clap] [laugh] [sparkle] [devices]                      |
| [dock stats] [mini/expand] [end call]                                        |
|                                                                              |
| Layout toolbar, quando ha video                                              |
| [auto] [focus] [split] [speaker] [compact] [self-view cycle]                 |
|                                                                              |
| Devices, quando carregados                                                   |
| [microphone select] [camera select] [speaker select]                         |
+------------------------------------------------------------------------------+
```

Estados importantes:

| Estado | Tela |
|---|---|
| Sessao nao conectada | Empty state: "P2P media is offline" |
| Sessao conectada sem media | Empty state: "Ready for private media" com `Start audio` e `Start video` |
| Peer liga media primeiro | A janela pode abrir e a UI mostra o tile remoto |
| Chamada ativa | Mostra tiles, toolbar de envio, layouts e dispositivos |
| Mini mode | Janela menor com controles essenciais |
| End call | Encerra a midia da chamada, nao necessariamente a sessao P2P inteira |
| X da janela | Abre confirmacao para encerrar a sessao P2P inteira |

### P2P Files

```text
+-------------------------- P2P Files --------------------------+
| Se desconectado                                                |
|   [file] Connect to send a file.                               |
|                                                                |
| Se conectado e pronto                                          |
| +------------------------------------------------------------+ |
| | Drop a file here, or browse. Transfers run alongside       | |
| | your call and game.                                        | |
| | Max: <N> MB                                                | |
| | [Browse files]                                             | |
| +------------------------------------------------------------+ |
|                                                                |
| Se existe transferencia                                        |
| +------------------------------------------------------------+ |
| | [file] filename.ext                         [Sending/Recv] | |
| | progress bar                                               | |
| | 42% | speed | size                         [Accept] [Cancel]| |
| +------------------------------------------------------------+ |
+----------------------------------------------------------------+
```

Acoes:

| Acao | Quando aparece | Efeito |
|---|---|---|
| Browse files | Conectado, estado ready ou validation error | Abre file input |
| Drop file | Conectado, estado ready | Oferece arquivo ao peer |
| Accept | Recebedor com oferta recebida | Aceita transferencia |
| Cancel | Oferta, ready, transferring, paused ou resuming | Cancela transferencia |
| X da janela | Janela P2P | Passa pelo fluxo de confirmacao da sessao P2P |

### P2P Games

```text
+-------------------------- P2P Games --------------------------+
| Se desconectado                                                |
|   [joystick] Connect to play a game.                           |
|                                                                |
| Se idle                                                        |
| +----------------+ +----------------+ +----------------+       |
| | icon game      | | icon game      | | icon game      |       |
| | name           | | name           | | name           |       |
| | tagline        | | tagline        | | tagline        |       |
| +----------------+ +----------------+ +----------------+       |
|                                                                |
| Proposta recebida                                              |
|   <peer> wants to play <game>  [Accept] [Decline]              |
|                                                                |
| Proposta enviada                                               |
|   Waiting for <peer> to accept...                              |
|                                                                |
| Jogando                                                        |
|   Game in progress                               [End game]    |
|   +---------------- 640x480 canvas ------------------------+   |
|   | LobbyGameCanvasHook                                    |   |
|   +--------------------------------------------------------+   |
|                                                                |
| Resultado                                                      |
|   Final Score, jogo, placar, You win/lose/draw, [Back to games]|
+----------------------------------------------------------------+
```

### P2P Statistics

```text
+------------------------- P2P Statistics ----------------------+
| Header: peer, online/offline, session status, connection       |
|                                                                |
| Tabs                                                           |
| [Network] [Audio] [Video] [Game] [File]       [privacy] [?]    |
|                                                                |
| Network tab                                                    |
| +-- P2P connection diagram ----------------------------------+ |
| | local browser <-> signaling/TURN/direct path <-> peer       | |
| | call/file/game activity badges                              | |
| +------------------------------------------------------------+ |
| Connection: health, MOS, latency, jitter, packet loss, kbps    |
|                                                                |
| Audio tab: active, download, upload, loss, jitter              |
| Video tab: active, resolution, fps, source camera/screen, etc. |
| Game tab: data channel state, throughput, messages             |
| File tab: data channel state, throughput, messages             |
+----------------------------------------------------------------+
```

Observacao: a janela de stats P2P e por feature. Audio, video, game e file tem
metricas separadas porque todos compartilham a mesma sessao WebRTC, mas usam
midia/data channels diferentes.

## Janelas da conferencia

### Group Call

```text
+----------------------------- Group Call: #canal -----------------------------+
| Header                                                                       |
| [conference] #canal                                                          |
|              status | participant count | track count                        |
|                                                                              |
| Toolbar                                                                      |
| Layout: [auto] [grid] [focus] [speaker] [participants panel] [self-view]     |
|         [clear focus, se houver foco]                                        |
| Window: [dock stats] [mini]                                                  |
| Moderacao, se permitido: [end room] [lock] [mute all] [camera off all]       |
| Media: [mic] [camera] [raise hand] [screen share]                            |
| Reactions: [heart] [thumbs up] [clap] [laugh] [wow]                          |
| Leave: [phone end]                                                           |
|                                                                              |
| +-- Video surface --------------------------------------+ +-- Participants -+ |
| | Waiting for participants placeholder                  | | Header count    | |
| | Local tile: video ou camera-off/receive-only state    | | Raised hands    | |
| | Remote tile template: nameplate, mic, camera, screen  | | Rows:           | |
| | active speaker, quality, reactions                    | | - nickname      | |
| |                                                       | | - role/status   | |
| |                                                       | | - focus/pin     | |
| |                                                       | | - moderation    | |
| |                                                       | | - quality badge | |
| +-------------------------------------------------------+ +-----------------+ |
|                                                                              |
| Error/warning strip, quando necessario                                       |
|   Connection needs attention: [Retry] [Leave]                                |
|   Media warning: [Leave]                                                     |
+------------------------------------------------------------------------------+
```

Estados importantes:

| Estado | Tela |
|---|---|
| Joining | Header mostra "Joining call" |
| Connecting/negotiating | Header mostra estado de midia |
| Connected | Video surface e participantes ativos |
| Reconnecting | Sinalizacao visual de reconexao |
| Error | Barra de erro com `Retry` e `Leave` |
| Warning | Barra de aviso com `Leave` |
| Mini mode | Header compacto com mic, camera, expand e leave |
| X da janela | Abre confirmacao "Close Group Call?" com acao `Leave call` |

### Conference Statistics

```text
+---------------------- Conference Statistics -------------------+
| Header: #canal, Browser <state>, Server <room>, participants    |
|                                                                |
| Server                                                         |
|   Room, participants, audio/video/screen tracks, pending, total |
|                                                                |
| Server runtime                                                  |
|   Peer connections, server tracks, fanout, inbound/outbound RTP |
|   ICE pairs, ICE traffic, RTCP feedback                         |
|                                                                |
| Server peers, quando houver                                     |
|   Cards por peer servidor: state, tracks, subs, RTP, ICE        |
|                                                                |
| Browser connection                                              |
|   health, MOS, latency, jitter, packet loss, capacity           |
|                                                                |
| Audio                                                           |
|   status, download, upload, packet loss                         |
|                                                                |
| Video                                                           |
|   status, resolution, frame rate, download, upload, loss        |
|   freezes, limited by                                           |
|                                                                |
| Browser summary                                                 |
|   participants, remote streams, tracks, ICE                     |
+----------------------------------------------------------------+
```

## Indicadores fora das janelas

### Topic bar

```text
Canal:
  [Chat] [Space] [Call 2/10 00:12] [info]

PM com sessao P2P:
  [P2P Live 1:1 00:12 quality icons] [info]
```

O `Call` pertence ao canal ativo. O `P2P` pertence ao PM com o peer da sessao.

### Status bar

```text
P2P:
  [P2P <peer> <duration> <facets/quality/privacy>] [disconnect]

Conferencia:
  [Conference #canal <count/status>] [phone end]
```

Clicar na area principal:

| Feature | Efeito |
|---|---|
| P2P | Foca janelas P2P abertas; se nenhuma estiver aberta, abre stats |
| Conferencia | Abre/foca `group-call` |

Clicar no botao final:

| Feature | Efeito |
|---|---|
| P2P | Cancela convite pendente ou abre confirmacao para encerrar sessao |
| Conferencia | Abre confirmacao para sair da conferencia |

### Taskbar

```text
P2P:
  [P2P Statistics] [P2P Call] [P2P Files] [P2P Games]

Conferencia:
  [Conference Statistics] [Group Call #canal]
```

No desktop, o P2P "explode" em varias janelas quando a sessao conecta:
`P2P Call` abre na frente, enquanto `P2P Statistics`, `P2P Files` e `P2P Games`
abrem minimizadas. A conferencia abre `Group Call`; em desktop tambem abre
`Conference Statistics` minimizada.

## Matriz de acoes principais

| Acao | P2P | Conferencia |
|---|---|---|
| Iniciar | `/p2p <nick>` ou contexto de usuario abre setup/convite | Botao `Call` no canal abre pre-join |
| Aceitar convite | PM card abre setup e depois entra | Nao ha convite 1:1; entra no canal/sala |
| Audio | Start audio, enable audio, mute/unmute | Toggle microphone |
| Video | Start video, enable video, camera on/off | Toggle camera |
| Screen share | Botao na toolbar da call P2P | Botao na toolbar da conferencia |
| Reacoes | Heart, thumbs up, clap, laugh, sparkle | Heart, thumbs up, clap, laugh, wow |
| Layout | Auto, focus, split, speaker, compact | Auto, grid, focus, speaker |
| Self-view | Tile, PiP, hidden | Tile, PiP, hidden |
| Participantes | Sempre 1:1; sem lista lateral | Lista lateral com participantes, estados e acoes |
| Moderacao | Nao tem mute-all, lock, kick ou request-to-speak | End room, lock, mute all, camera off all, permitir fala, moderar audio/video/screen, kick/ban |
| Arquivos | Janela propria `P2P Files` | Nao pertence a conferencia |
| Jogos | Janela propria `P2P Games` | Nao pertence a conferencia |
| Stats | Por feature: network/audio/video/game/file | Por sala: server/browser/audio/video/summary |
| Mini | Call P2P tem mini mode | Group Call tem mini mode |
| Dock stats | Dock de stats ao lado da call | Dock de stats ao lado da conferencia |
| Encerrar midia | `End call` na call P2P | Leave conference |
| Encerrar sessao/sala | Status bar stop ou X de janela P2P confirma fim da sessao | Leave/close confirma saida; operador pode end room |

## Modelo mental

```text
P2P
  PM e a casa da sessao.
  A sessao e 1:1.
  Call, Files, Games e Statistics sao facetas da mesma conexao.
  A chamada pode acabar sem necessariamente destruir o PM.
  Encerrar a sessao derruba tudo que esta multiplexado nela.

Conferencia
  Canal e a casa da sala.
  A sala e N:N.
  A janela principal e a conferencia de midia.
  Participants panel e moderacao fazem parte da feature.
  Stats misturam browser local e estado do servidor/SFU.
```

## Fontes do codigo lidas

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/group_call_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_media_island.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_file_island.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_game_island.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/group_call_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/setup_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/call_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/session_badge.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/file_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/game_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/lobby_network_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/pre_join_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/video_surface.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/layout_controls.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/channel_badge.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/stats_panel.ex`
