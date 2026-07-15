# Janelas de video - plano de layout e icones 32/64

> Criado em 2026-07-15. Objetivo: melhorar as janelas `P2P Call` e
> `Group Call` sem mudar a semantica das features. O plano ataca primeiro a
> distribuicao dos controles, depois o tamanho dos icones atuais, e so entao uma
> nova familia SVG para os icones que merecem mais detalhe.

## Objetivo

As janelas de video de P2P e conferencia funcionam, mas a UI esta densa demais:

- muitos botoes competem na mesma barra;
- quase todos os icones aparecem com `h-3`, `h-3.5` ou `h-4`;
- a conferencia mistura status, layout, moderacao, midia, reacoes e leave no
  header;
- o P2P coloca midia, layout, devices, stats, mini e end em blocos muito
  proximos do video;
- os SVGs atuais podem ser bons em alguns contextos do produto, mas alguns
  foram desenhados para uso pequeno e nao parecem premium quando viram controle
  principal de chamada.

Resultado esperado:

- a janela de video respira;
- os controles principais ficam obvios;
- nenhum icone acionavel nessas duas janelas fica menor que 32px;
- empty states e estados grandes usam icones 64px;
- a primeira entrega reaproveita a arte SVG atual;
- a entrega final cria uma nova familia de icones para video, sem quebrar os
  icones existentes usados em outras partes do app.

## Status em 2026-07-15

Implementado:

- P2P Call:
  - video agora fica em um `p2p-call-stage`;
  - layout, self-view, PiP, devices, stats e mini foram para
    `p2p-call-view-rail` fora do mini mode;
  - mic, camera, screen, reactions e end ficaram no rodape;
  - reacoes foram agrupadas em um flyout `React`;
  - device selects foram colocados em bloco expansivel;
  - ids e hooks WebRTC foram preservados.
- Group Call:
  - header ficou para identidade, stats, mini e moderacao de sala;
  - layout/sidebar/self-view/clear-focus foram para `group-call-view-rail`;
  - mic, camera, screen, raise hand, reactions e leave foram para rodape;
  - `group-call-layout-controls` continua com role/aria/testid existentes;
  - painel de participantes continua no lado direito;
  - cada participante agora mostra um unico botao `More`, que expande foco,
    pin, moderacao, indicadores de midia e qualidade.
- Tamanho:
  - controles principais usam icones renderizados em 32px;
  - empty states de video usam 64px;
  - badges de video da conferencia foram aumentadas para celulas 32px.
- Icones:
  - criada a nova familia `RetroHexChatWeb.Icons.CallControls`;
  - os icones antigos foram mantidos intactos;
  - P2P Call, Group Call, layout controls, screen share e video surface foram
    migrados para os novos icones onde eram controles principais.

Validado:

- `mix compile --warnings-as-errors`
- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs`
- `mix test --include liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs`
- `rg "h-3|h-3.5|h-4|w-3|w-3.5|w-4|h-5|w-5|h-6|w-6|h-7|w-7"` nos componentes alvo retornou vazio

Pendencias possiveis para um ciclo visual posterior:

- rodar screenshot/E2E visual desktop/mobile e ajustar eventuais overflows finos.

## Escopo

Incluido:

- `P2P Call` (`p2p-call`);
- `Group Call` (`group-call`);
- tiles locais/remotos dessas janelas;
- barra principal de chamada;
- controles secundarios de view/layout/devices/stats/mini;
- painel de participantes da conferencia quando ele aparece dentro da janela de
  video;
- estados de erro/warning dentro da janela de conferencia;
- empty states dentro da janela de video.

Fora do escopo deste plano:

- pre-join/setup dialogs;
- `P2P Statistics` e `Conference Statistics`;
- `P2P Files` e `P2P Games`;
- topic bar, status bar e taskbar, exceto quando um botao da janela abre/foca
  algo nelas;
- trocar a arquitetura WebRTC;
- mudar regras de sessao, permissao ou moderacao.

## Regras de tamanho

Padrao para estas duas janelas:

| Uso | Tamanho do SVG renderizado | Container |
|---|---:|---:|
| Acao primaria de chamada | 32x32 | botao 52x52 ou 56x56 |
| Acao secundaria | 32x32 | botao 44x44 ou 48x48 |
| Indicador clicavel em participante | 32x32 | celula/botao 40x40 ou menu |
| Indicador nao clicavel em participante | 32x32 ou texto/status dot | celula 32/40 |
| Header de identidade | 32x32 | bloco de header |
| Empty state / waiting / offline | 64x64 | painel central |
| Erro/warning grande | 64x64 quando houver painel; 32x32 em strip compacta | strip/painel |

Regra operacional:

- nao usar `h-3`, `h-3.5`, `h-4`, `w-3`, `w-3.5`, `w-4` dentro das duas
  janelas de video apos a fase 2;
- badges muito pequenos devem virar celulas 32, texto, dot de estado, ou menu;
- se 32px nao couber, o problema e layout, nao o icone.

## Principio de distribuicao

A UI deve ter zonas claras:

```text
+----------------------------------------------------------------+
| Topo: identidade/status/tempo/qualidade/stats/mini              |
+--------+---------------------------------------------+---------+
| Left   |                                             | Right   |
| rail   |                 AREA DE VIDEO               | panel   |
| view   |             tiles e overlays                | users   |
| layout |                                             | conf.   |
| device |                                             | only    |
+--------+---------------------------------------------+---------+
| Baixo: acoes principais de chamada                              |
|        [Mic] [Camera] [Screen] [React] [End/Leave]              |
+----------------------------------------------------------------+
```

O objetivo da fase 1 e sair de "uma toolbar gigante" para "zonas de acao".

## Layout alvo - P2P Call

```text
+----------------------------- P2P Call -----------------------------+
| [P2P 32] Direct call with <peer>        00:12  Good  [Stats] [Mini] |
+-------+-------------------------------------------------------------+
| View  |                                                             |
| [32]  |                    remote video tile                        |
|       |                                                             |
| Dev   |                                       +-- self-view ----+    |
| [32]  |                                       | local / screen |    |
|       |                                       +----------------+    |
| More  |                                                             |
| [32]  |                                                             |
+-------+-------------------------------------------------------------+
|          [Mic 32] [Camera 32] [Screen 32] [React 32]     [End 32]  |
+---------------------------------------------------------------------+
```

P2P muda assim:

- header fica para contexto: peer, estado, duracao, qualidade, stats e mini;
- lateral esquerda fica para configuracao/view: layout, self-view, devices,
  possivelmente mais opcoes;
- rodape fica para acoes de chamada;
- reacoes deixam de ocupar 5 botoes permanentes no rodape e viram um popover
  ou flyout aberto por `React`;
- device selects deixam de aparecer como grid permanente embaixo do video e
  viram painel lateral/flyout acionado por `Devices`;
- `End call` continua dentro da janela, mas visualmente separado como acao
  destrutiva.

## Layout alvo - Group Call

```text
+---------------------------- Group Call ----------------------------+
| [Conf 32] #canal     Connected  5 users  7 tracks  [Stats] [Mini] |
+-------+----------------------------------------------+-------------+
| View  |                                              | Participants|
| [32]  |                                              |             |
| Grid  |                video grid                    | Ana   [..]  |
| [32]  |          local + remote tiles                | Bob   [..]  |
| Focus |                                              | Cy    [..]  |
| [32]  |                                              |             |
| More  |                                              | [Moderation]|
| [32]  |                                              |             |
+-------+----------------------------------------------+-------------+
|      [Mic 32] [Camera 32] [Screen 32] [Raise 32] [React 32] [Leave 32] |
+---------------------------------------------------------------------+
```

Conferencia muda assim:

- header fica para contexto e controles de janela: canal, status, participantes,
  tracks, stats, mini;
- left rail fica para layout/view: auto, grid, focus, speaker, sidebar,
  self-view e clear focus;
- right panel continua sendo participantes, mas acoes por participante nao
  podem ficar todas expostas como icones pequenos;
- rodape fica para midia e participacao: mic, camera, screen, raise hand,
  react, leave;
- moderacao de sala (`end room`, `lock`, `mute all`, `camera off all`) vai para
  uma zona `Moderation`, preferencialmente no painel direito ou menu/flyout;
- moderacao por participante fica no row, mas com poucas acoes visiveis e o
  restante em `More`.

## Fases

### Fase 1 - Reposicionar controles sem trocar tamanho

Status: `CONCLUIDO`

Objetivo: redistribuir os botoes, mantendo a arte e tamanho atuais o maximo
possivel para reduzir risco.

Entregar:

- criar estrutura visual compartilhavel para janela de video:
  - `CallWindowHeader`;
  - `CallLeftRail`;
  - `CallBottomControls`;
  - opcionalmente `CallIconButton`;
- P2P:
  - mover layout/self-view/devices para left rail ou flyout;
  - mover stats/mini para left rail quando fora do mini mode;
  - reduzir rodape a mic, camera, screen, react, end;
  - agrupar reacoes em `React`;
  - agrupar devices em `Devices`;
- Conferencia:
  - mover layout/sidebar/self-view/clear-focus para left rail;
  - mover stats/mini para header;
  - mover mic/camera/screen/raise/reaction/leave para bottom controls;
  - manter controles de sala no header como zona de moderacao;
  - transformar acoes excedentes de participante em menu `More` em ciclo
    posterior;
- manter eventos e testids existentes quando possivel;
- preservar hooks e ids de video:
  - `lobby-media`;
  - `lobby-remote-video`;
  - `lobby-local-video`;
  - `lobby-remote-audio`;
  - `group-call-webrtc-*`;
  - `data-group-call-video-grid`;
  - templates de remote tile.

Validacao:

- LiveView/component tests ajustados para nova estrutura;
- Playwright visual/foco para confirmar que os controles continuam acionaveis;
- checagem de overflow desktop/mobile.

### Fase 2 - Padronizar 32/64 com os SVGs atuais

Status: `CONCLUIDO`

Objetivo: aumentar a presenca visual sem redesenhar SVG ainda.

Entregar:

- criar tokens/classes locais para janelas de video:
  - `call-control-button-primary`;
  - `call-control-button-secondary`;
  - `call-control-icon-32`;
  - `call-state-icon-64`;
  - `call-rail-button`;
  - `call-participant-action`;
- trocar classes `h-3`, `h-3.5`, `h-4`, `h-5`, `h-6`, `h-7` por 32/64
  conforme a zona;
- P2P:
  - empty/offline/ready icons para 64;
  - header protocol/status icons para 32;
  - bottom controls para 32;
  - left rail para 32;
  - tile badges que forem essenciais para 32 ou texto;
- Conferencia:
  - waiting placeholder e local empty para 64;
  - header protocol/status para 32;
  - left rail e bottom controls para 32;
  - participante: acoes clicaveis para 32; indicadores nao clicaveis em celula
    32 ou agrupados;
  - quality badges para 32;
  - error/warning strip para 32, ou 64 se virar painel alto.

Nao fazer nesta fase:

- nao redesenhar SVG;
- nao renomear icon functions;
- nao mexer em icones fora dessas duas janelas.

Validacao:

- screenshots desktop e mobile;
- asserts de ausencia de overflow horizontal;
- asserts de que todos os botoes principais tem area minima de toque;
- conferir que nenhum `h-3`, `h-3.5`, `h-4` permanece nos componentes alvo.

### Fase 3 - Nova familia de icones de video

Status: `CONCLUIDO`

Objetivo: criar icones melhores, com mais detalhe, sem quebrar outros usos dos
icones atuais.

Decisao importante:

- nao substituir diretamente `icon_microphone`, `icon_camera`, etc. no comeco;
- esses icones podem estar sendo usados em outras telas com expectativas de
  tamanho/estilo;
- criar novos nomes para a familia de video e migrar apenas P2P Call e Group
  Call;
- depois, se fizer sentido, migrar outras telas em plano separado.

Padrao novo:

- SVG source: `viewBox="0 0 64 64"`;
- renderizacao de controle: 32px (`h-8 w-8`);
- renderizacao hero/empty: 64px (`h-16 w-16`);
- visual retro com detalhe suficiente para 32px;
- evitar detalhe fino que desaparece em 32px;
- stroke/fill alinhado ao pixel grid;
- cada icone deve funcionar em claro/escuro da UI atual;
- estados on/off precisam ser distinguiveis por forma, cor e estado do botao.

Nomes considerados no plano original:

```text
icon_call_mic_on_32
icon_call_mic_off_32
icon_call_camera_on_32
icon_call_camera_off_32
icon_call_screen_share_32
icon_call_screen_stop_32
icon_call_phone_end_32
icon_call_react_32
icon_call_devices_32
icon_call_stats_32
icon_call_layout_auto_32
icon_call_layout_grid_32
icon_call_layout_focus_32
icon_call_layout_speaker_32
icon_call_self_view_32
icon_call_participants_32
icon_call_mini_32
icon_call_expand_32
icon_call_raise_hand_32
icon_call_more_32
icon_call_quality_good_32
icon_call_quality_medium_32
icon_call_quality_poor_32

icon_p2p_call_32
icon_conference_call_32
icon_p2p_call_hero_64
icon_conference_call_hero_64
icon_waiting_participants_64
icon_p2p_media_offline_64
```

Moderacao nova:

```text
icon_call_room_lock_32
icon_call_room_unlock_32
icon_call_mute_all_32
icon_call_camera_off_all_32
icon_call_allow_speak_32
icon_call_kick_ban_32
icon_call_pin_32
icon_call_focus_person_32
```

Reacoes novas:

```text
icon_call_reaction_heart_32
icon_call_reaction_thumbs_up_32
icon_call_reaction_clap_32
icon_call_reaction_laugh_32
icon_call_reaction_sparkle_32
```

Entregar:

- adicionar novos icones ao modulo de icones apropriado ou novo submodulo,
  por exemplo `components/icons/call_controls.ex`;
- exportar via `RetroHexChatWeb.Icons` conforme o padrao atual;
- atualizar `docs/reference/svg-catalog.md`;
- migrar P2P Call e Group Call para os novos nomes;
- manter os icones antigos intactos.

Entregue:

- `components/icons/call_controls.ex`;
- delegates em `RetroHexChatWeb.Icons`;
- migracao dos controles principais de P2P e conferencia;
- migracao dos templates de reacao da video surface;
- catalogo SVG atualizado.

Validacao:

- component tests renderizam os novos icon names;
- screenshot visual antes/depois;
- catalogo SVG atualizado;
- `mix compile --warnings-as-errors`;
- `mix test` focado;
- `npm test` dos hooks se markup/data attributes forem tocados;
- Playwright para desktop e mobile nas duas janelas.

## Inventario de icones envolvidos

### P2P Call

| Icone atual | Uso atual | Fase 1 | Fase 2 | Fase 3 |
|---|---|---|---|---|
| `icon_protocol_p2p_compact` | identidade P2P, header, empty, peer labels | header/empty | 32 header, 64 empty | `icon_p2p_call_32`, `icon_p2p_call_hero_64` |
| `icon_status_signal` | qualidade/status/dock stats | header/top | 32 | `icon_call_stats_32` ou quality icon |
| `icon_status_user` | label 1:1 | header text | 32 ou texto | possivelmente remover por texto `1:1` |
| `icon_webrtc` | tracks, ready state, call type | header/empty | 32 header, 64 ready | `icon_p2p_call_hero_64` ou `icon_call_connection_32` |
| `icon_clock` | duracao | header | 32 | `icon_call_duration_32` se necessario |
| `icon_microphone` | start audio, enable audio, unmuted, layout speaker, device | bottom/rail | 32 | `icon_call_mic_on_32`, `icon_call_layout_speaker_32` |
| `icon_mute` | mute local, peer muted, muted strip | bottom/tile | 32 | `icon_call_mic_off_32` |
| `icon_camera` | start video, enable video, camera on, window icon, device | bottom/header/rail | 32 | `icon_call_camera_on_32` |
| `icon_camera_off` | camera off, empty, camera toggle | bottom/tile/empty | 32, 64 empty | `icon_call_camera_off_32`, `icon_p2p_media_offline_64` |
| `icon_screen_share` | screen share, peer screen, local screen | bottom/tile | 32 | `icon_call_screen_share_32`, `icon_call_screen_stop_32` |
| `icon_laptop` | local tile default | tile | 32 | `icon_call_self_view_32` |
| `icon_pip` | PiP, self-view cycle | left rail | 32 | `icon_call_self_view_32` |
| `icon_devices` | device settings and selectors | left rail/flyout | 32 | `icon_call_devices_32` |
| `icon_phone_end` | end call | bottom right | 32 | `icon_call_phone_end_32` |
| `icon_win_minimize` | mini mode, compact layout | header/rail | 32 | `icon_call_mini_32`, `icon_call_layout_compact_32` |
| `icon_win_restore` | expand mini | header | 32 | `icon_call_expand_32` |
| `icon_layout_maximize` | auto layout | left rail | 32 | `icon_call_layout_auto_32` |
| `icon_layout_focus` | focus layout | left rail | 32 | `icon_call_layout_focus_32` |
| `icon_layout_side_by_side` | split layout | left rail | 32 | `icon_call_layout_grid_32` ou split |
| `icon_heart` | reaction | popover | 32 | `icon_call_reaction_heart_32` |
| `icon_thumbs_up` | reaction | popover | 32 | `icon_call_reaction_thumbs_up_32` |
| `icon_clap` | reaction | popover | 32 | `icon_call_reaction_clap_32` |
| `icon_laugh` | reaction | popover | 32 | `icon_call_reaction_laugh_32` |
| `icon_sparkle` | reaction | popover | 32 | `icon_call_reaction_sparkle_32` |

### Group Call - header, video e bottom controls

| Icone atual | Uso atual | Fase 1 | Fase 2 | Fase 3 |
|---|---|---|---|---|
| `icon_protocol_conference_compact` | identidade conferencia, waiting | header/empty | 32 header, 64 empty | `icon_conference_call_32`, `icon_conference_call_hero_64` |
| `icon_status_signal` | status da conferencia | header | 32 | `icon_call_quality_good_32` ou connection |
| `icon_status_user` | contador usuario, remote template | header/tile | 32 ou texto | `icon_call_participants_32` |
| `icon_webrtc` | tracks/stats dock | header/top | 32 | `icon_call_stats_32` ou connection |
| `icon_win_minimize` | mini mode | header | 32 | `icon_call_mini_32` |
| `icon_win_restore` | expand mini | header | 32 | `icon_call_expand_32` |
| `icon_microphone` | mic toggle, speaker layout, active speaker badge | bottom/left/tile | 32 | `icon_call_mic_on_32`, `icon_call_layout_speaker_32` |
| `icon_mute` | muted state, mute all | bottom/moderation | 32 | `icon_call_mic_off_32`, `icon_call_mute_all_32` |
| `icon_camera` | camera toggle, tile badge | bottom/tile | 32 | `icon_call_camera_on_32` |
| `icon_camera_off` | camera off state, camera off all, local empty | bottom/moderation/empty | 32, 64 empty | `icon_call_camera_off_32`, `icon_call_camera_off_all_32` |
| `icon_screen_share` | screen share local/remote/moderation | bottom/tile/moderation | 32 | `icon_call_screen_share_32`, `icon_call_screen_stop_32` |
| `icon_raise_hand` | raise hand, queue, participant hand | bottom/panel | 32 | `icon_call_raise_hand_32` |
| `icon_phone_end` | leave/end room/error leave | bottom/header/error | 32 | `icon_call_phone_end_32` |
| `icon_heart` | reaction | popover/flyout | 32 | `icon_call_reaction_heart_32` |
| `icon_thumbs_up` | reaction | popover/flyout | 32 | `icon_call_reaction_thumbs_up_32` |
| `icon_clap` | reaction | popover/flyout | 32 | `icon_call_reaction_clap_32` |
| `icon_laugh` | reaction | popover/flyout | 32 | `icon_call_reaction_laugh_32` |
| `icon_sparkle` | wow/reaction | popover/flyout | 32 | `icon_call_reaction_sparkle_32` |
| `icon_star` | fallback reaction | remove/fallback | 32 se mantido | `icon_call_react_32` |
| `icon_warning` | error/warning/unknown quality | strip | 32 ou 64 panel | `icon_call_warning_32/64` se criado |
| `icon_btn_refresh` | retry | strip action | 32 | `icon_call_retry_32` |
| `icon_btn_timers` | joining/reconnecting/quality unknown | header/status | 32 | `icon_call_connecting_32` |

### Group Call - layout/view

| Icone atual | Uso atual | Fase 1 | Fase 2 | Fase 3 |
|---|---|---|---|---|
| `icon_layout_maximize` | auto layout | left rail | 32 | `icon_call_layout_auto_32` |
| `icon_layout_side_by_side` | grid layout | left rail | 32 | `icon_call_layout_grid_32` |
| `icon_layout_focus` | focus layout, participant focus | left rail/participant | 32 | `icon_call_layout_focus_32`, `icon_call_focus_person_32` |
| `icon_microphone` | speaker layout | left rail | 32 | `icon_call_layout_speaker_32` |
| `icon_tab_nicklist` | participants panel toggle | left rail/header | 32 | `icon_call_participants_32` |
| `icon_pip` | self-view cycle | left rail | 32 | `icon_call_self_view_32` |
| `icon_close` | clear focus | left rail | 32 | `icon_call_clear_focus_32` |

### Group Call - participantes e moderacao

| Icone atual | Uso atual | Fase 1 | Fase 2 | Fase 3 |
|---|---|---|---|---|
| `icon_community` | participants header | right panel | 32 | `icon_call_participants_32` |
| `icon_status_user` | count and remote person | right panel/tile | 32 ou texto | `icon_call_participants_32` |
| `icon_pin` | pin participant | row/menu | 32 | `icon_call_pin_32` |
| `icon_check_thin` | allow speak paired with mic | row/menu | 32, maybe combined | `icon_call_allow_speak_32` |
| `icon_shield` | lock/unlock room | moderation | 32 | `icon_call_room_lock_32` |
| `icon_ban` | kick/ban participant | row/menu | 32 | `icon_call_kick_ban_32` |
| `icon_quality_high` | participant quality high | row/tile | 32 | `icon_call_quality_good_32` |
| `icon_quality_medium` | participant quality medium | row/tile | 32 | `icon_call_quality_medium_32` |
| `icon_quality_low` | participant quality low | row/tile | 32 | `icon_call_quality_poor_32` |
| `icon_role_owner` | participant role | row | 32 or text badge | keep or create call role badge later |
| `icon_role_operator` | participant role | row | 32 or text badge | keep or create call role badge later |
| `icon_role_halfop` | participant role | row | 32 or text badge | keep or create call role badge later |
| `icon_role_voiced` | participant role | row | 32 or text badge | keep or create call role badge later |
| `icon_role_regular` | participant role | row | 32 or text badge | keep or create call role badge later |
| `icon_btn_disconnect` | participant disconnected status | row status | 32 or text | `icon_call_disconnected_32` if needed |

## Arquivos provaveis

Markup/render:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/call_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/video_surface.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/layout_controls.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/screen_share_control.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_media_island.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/group_call_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`

Icones:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/media.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/communication.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/symbols.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/people.ex`
- possivel novo arquivo:
  `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/call_controls.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons.ex`
- `docs/reference/svg-catalog.md`

CSS/testes:

- CSS onde vivem classes de `group-call-*`, `lobby-media-*` e window manager;
- testes de componentes em `apps/retro_hex_chat_web/test/.../components/ui/p2p/`;
- testes de componentes em `apps/retro_hex_chat_web/test/.../components/ui/group_call/`;
- Vitest dos hooks se data attributes mudarem;
- Playwright `e2e/tests/chat-p2p.spec.ts` e `e2e/tests/chat-group-call.spec.ts`.

## Riscos e mitigacoes

| Risco | Mitigacao |
|---|---|
| Quebrar hooks WebRTC por mexer no DOM | Preservar ids e data attributes dos elementos de video e hook |
| Botoes maiores causarem overflow | Reposicionar antes de aumentar; usar rails, popovers e menus |
| Criar icones novos e afetar telas antigas | Usar novos nomes; nao trocar icones globais na fase 3 |
| Testes antigos procuram testids em toolbars | Manter testids nos botoes ou adaptar testes junto com a mudanca |
| Sidebar de participantes ficar gigante | Mover acoes raras para `More`; deixar no row so foco/pin/estado principal |
| Mobile ficar apertado | Em mobile, priorizar bottom bar e menus; esconder left rail em drawer/flyout |
| Reacoes perderem descoberta | Botao `React` com popover visivel e tooltip claro |
| Moderacao ficar escondida demais | `Moderation` visivel para moderadores, com badge/estado quando algo esta ativo |

## Criterios de aceite

- P2P Call e Group Call nao renderizam controles acionaveis menores que 32px.
- Empty states principais usam 64px.
- A linha principal de chamada tem no maximo 5 ou 6 acoes visiveis.
- Conferencia nao mistura moderacao de sala com mic/camera/reacoes na mesma
  linha.
- P2P nao mostra grid permanente de device selects abaixo do video.
- Reacoes ficam agrupadas em popover/flyout.
- Layout/view fica em left rail ou menu equivalente.
- Participante da conferencia nao tem uma fileira de muitos icones pequenos.
- `git diff --check` passa.
- Testes focados de componentes passam.
- Pelo menos um E2E de P2P Call e um E2E de Group Call passam apos cada fase.

## Sequencia sugerida de implementacao

1. Congelar screenshots atuais das duas janelas.
2. Implementar estrutura de zonas no P2P Call.
3. Implementar estrutura de zonas no Group Call.
4. Validar overflow/foco/interacao.
5. Aplicar 32/64 com SVG atual no P2P.
6. Aplicar 32/64 com SVG atual na conferencia.
7. Validar screenshots novamente.
8. Criar familia nova de icones `call_*`.
9. Migrar P2P para icones novos.
10. Migrar conferencia para icones novos.
11. Atualizar catalogo SVG e docs.
12. Rodar gates focados e E2E.
