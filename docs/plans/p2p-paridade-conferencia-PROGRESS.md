# P2P x conferencia - progresso e aprendizados

> Diario de execucao do plano `p2p-paridade-conferencia.md`.
> Atualizar ao iniciar e concluir cada bloco. Sem commit ate autorizacao
> explicita do Rodrigo.

## Status geral

| Frente | Escopo | Status |
|---|---|---|
| Baseline | Auditoria P2P x conferencia e plano de paridade | CONCLUIDA (2026-07-12) |
| V | Valor imediato: componentes, setup, call redesign, layouts, screen share, stats, indicadores | CONCLUIDA |
| S | Seguranca/moderacao contextual: confirms, ignore/block, privacy | CONCLUIDA |
| U | UX refinada: mini/dock, reactions, atalhos, iconografia, help | CONCLUIDA |

## Proximo bloco ativo

Auditoria final + gate amplo:

1. rodar `git diff --check`;
2. rodar `make ci` antes de qualquer commit;
3. se o CI apontar regressao, corrigir e registrar aqui;
4. manter sem commit ate autorizacao explicita.

## Registro de execucao

### 2026-07-12 - rodada 1 concluida: fundacao visual e confirmacoes

- Criado `RetroHexChatWeb.Components.UI.P2P.CallPanel` em
  `components/ui/p2p/**`.
- `P2PMediaIsland` voltou a ser wrapper stateful fino e agora compoe o painel
  P2P dedicado.
- Contratos criticos do hook foram preservados:
  - `id="lobby-media"` com `phx-hook="LobbyMediaHook"`;
  - `lobby-remote-video`, `lobby-local-video`, `lobby-remote-audio`;
  - `data-lobby-media-action` para audio, video, mute, camera, PiP, devices e
    end-call.
- O painel P2P agora tem header rico com status, contador 1:1, tracks,
  duracao, qualidade, nameplate, estados de peer muted/camera-off, controles de
  layout/qualidade e seletores de dispositivos.
- `P2PConfirmDialog` foi alinhado ao padrao visual da conferencia com badge,
  icone contextual e lista de impactos por modo (`end`, `close`, `switch`).
- Testes adicionados:
  - `components/ui/p2p/call_panel_test.exs`;
  - `components/ui/dialogs/p2p_confirm_dialog_test.exs`.
- Gate focado executado:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/dialogs/p2p_confirm_dialog_test.exs`
  - resultado: 11 testes, 0 falhas.

### 2026-07-12 - rodada 1.2: layouts 1:1 e status bar rico

- `P2PMediaIsland` ganhou estado `self_view` e evento
  `cycle_call_self_view`.
- `P2PSessionEvents` agora encaminha `cycle_call_self_view` para a ilha de
  midia.
- A Call P2P ganhou layouts `auto`, `focus`, `split`, `speaker` e `compact`,
  mantendo compatibilidade com os nomes antigos `side_by_side` e `maximized`.
- Self-view agora cicla entre `tile`, `pip` e `hidden`.
- O tile remoto permite alternar foco por clique mantendo o mesmo id do video
  remoto para o hook.
- O status bar P2P agora mostra facetas ativas (`call`, `file`, `game`),
  qualidade da chamada e badge de relay/privacy quando TURN-only esta ativo,
  preservando a string base `P2P: <peer>` usada pelos testes E2E atuais.
- Testes adicionados/ajustados:
  - `call_panel_test.exs` cobre layouts novos e self-view;
  - `chat_shell_test.exs` cobre status bar P2P rico.
- Gates focados executados:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/dialogs/p2p_confirm_dialog_test.exs`
    - resultado: 12 testes, 0 falhas.
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
    - resultado efetivo: 6 testes unitarios, 0 falhas; os testes
      `:liveview_feature` permaneceram excluidos pelo filtro padrao.

### 2026-07-12 - inicio da implementacao master P2P parity

- Rodrigo pediu execucao em loop ate concluir o plano, sem commit.
- Documentacao lida:
  - `CLAUDE.md`;
  - `docs/AGENT-GUIDE.md`;
  - `docs/README.md`;
  - `docs/plans/p2p-paridade-conferencia.md`;
  - documentos historicos de P2P e conferencia lidos durante a auditoria.
- Regras reafirmadas para esta implementacao:
  - telas novas por composicao em `components/ui/**`;
  - wrappers em `chat_live/components/**` devem ser finos e sem markup Tailwind pesado;
  - hooks JS empurram eventos para o LiveView raiz; host adapta para ilhas;
  - SVG via `RetroHexChatWeb.Icons`, sem emoji/inline SVG em UI nova;
  - E2E deve validar comportamento real de midia, nao apenas presenca de botoes;
  - `make ci` e o gate final; antes de commit/push na main precisa fetch/status/pull.
- Estado inicial do worktree:
  - existe o novo plano `docs/plans/p2p-paridade-conferencia.md` sem commit;
  - este diario foi criado como segundo arquivo sem commit.

### 2026-07-12 - rodada 2: setup/prejoin P2P real

- Criado `RetroHexChatWeb.Components.UI.P2P.SetupDialog`.
- Aceitar convite agora abre setup antes de juntar na sessao.
- Setup ganhou preview local com `P2PSetupHook`, reutilizando a logica
  configuravel de `GroupCallPreJoinHook`:
  - `getUserMedia` para preview;
  - `enumerateDevices`;
  - retry e mensagens de permissao/device;
  - preferencias em `localStorage` escopadas por usuario/browser.
- O setup permite iniciar com mic, camera, ambos ou receive-only.
- Selecao de microphone/camera/speaker e aplicada ao auto-start da chamada via
  `device_preferences` no `@p2p_session`.
- Privacy relay aparece no setup; quando TURN nao esta configurado, fica
  desabilitado e sem estado ambiguo.
- Testes adicionados/ajustados:
  - `components/ui/p2p/setup_dialog_test.exs`;
  - fluxo LiveView cobre cancelar setup, receive-only e device preferences;
  - Vitest do prejoin cobre o mesmo hook configurado para P2P.

### 2026-07-12 - rodada 3: UX master da call P2P

- Call P2P ganhou screen share por `getDisplayMedia`, badge visual e foco
  automatico de layout quando ha tela compartilhada.
- Adicionadas reacoes efemeras 1:1 (`heart`, `thumbs_up`, `clap`, `laugh`,
  `sparkle`) com SVG catalogado e sem criar mensagens no PM.
- Atalhos da janela P2P:
  - `Ctrl+Shift+ArrowUp` mic;
  - `Ctrl+Shift+ArrowLeft` camera;
  - `Ctrl+Shift+ArrowRight` layout;
  - `Ctrl+Shift+ArrowDown` self-view;
  - `Ctrl+Shift+.` screen share;
  - `Ctrl+Shift+Q` encerra media da call.
- Window manager ganhou `set_geometry` para comandos server-side de geometria.
- P2P Call ganhou mini mode com controles essenciais e dock de Stats ao lado da
  Call via `dock_pair`.
- Help atualizado para setup, preview, devices, privacy relay, screen share,
  reacoes, mini/dock e atalhos.

### 2026-07-12 - gates focados executados

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/setup_dialog_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs`
  - resultado: 16 testes, 0 falhas.
- `rtk mix test --include liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
  - resultado: 21 testes, 0 falhas.
- `rtk npm test -- test/hooks/group_call/group_call_prejoin_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/lib/p2p/media.test.js test/hooks/ui/window_manager_hook.test.js`
  - resultado: 132 testes, 0 falhas.
- `rtk mix compile --warnings-as-errors`
  - resultado: passou.
- `rtk mix assets.build`
  - resultado: passou.
- `rtk npm test -- tests/chat-p2p.spec.ts` em `e2e/`
  - resultado: 4 testes Playwright, 0 falhas.

### 2026-07-12 - rodada 4: fechamento dos gaps parciais

- `P2P-V2` fechado:
  - `/p2p` e menu/context menu agora abrem setup do criador antes de enviar o
    convite;
  - a sessao/PM do convite so e criada apos confirmar setup;
  - cancelar setup do criador nao deixa sessao pendente fantasma;
  - setup do criador aplica `media_mode`, `device_preferences` e `turn_only` ao
    estado `:invite_sent`.
- `P2P-V5/V6` fechados:
  - `getDisplayMedia` esta coberto por Vitest e Playwright;
  - `LobbyMediaHook` informa `lobby_media_source_changed`;
  - `LobbyWebRTCHook` anexa `video.source` ao `lobby_stats`;
  - `P2PStats` normaliza `camera`/`screen`;
  - Stats exibem `Source: Camera/Screen`.
- `P2P-U1` fechado:
  - E2E valida mini mode, expand, dock de Stats ao lado da Call,
    maximize/restore e video remoto vivo com identidade de elemento preservada.
- `P2P-U4` fechado:
  - criados `icon_browser` e `icon_operating_system`;
  - whois/browser/OS do diagrama P2P usam `RetroHexChatWeb.Icons`;
  - `docs/reference/svg-catalog.md` atualizado.
- `P2P-U5` fechado:
  - Help atualizado para `/p2p`, P2P in Chat, Universal Lobby, Media Devices,
    Network Stats e Privacy Settings, cobrindo setup bilateral, screen share,
    mini/dock, stats, close vs minimize, privacy e sessao unica.

### 2026-07-12 - gates focados finais executados

- `rtk mix compile --warnings-as-errors`
  - resultado: passou.
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/setup_dialog_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/p2p_connection_diagram_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/p2p_stats_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs`
  - resultado: 22 testes, 0 falhas.
- `rtk mix test --include liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
  - resultado: 23 testes, 0 falhas.
- `rtk npm test -- test/hooks/lobby/lobby_webrtc_hook.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_prejoin_hook.test.js test/lib/p2p/media.test.js test/hooks/ui/window_manager_hook.test.js`
  - resultado: 137 testes, 0 falhas.
- `rtk npm test -- tests/chat-p2p.spec.ts` em `e2e/`
  - resultado: 6 testes Playwright, 0 falhas.

### Gaps conscientes

- Nenhum gap do plano `p2p-paridade-conferencia.md` permanece aberto nesta
  rodada.
- Gate amplo final executado:
  - `rtk git diff --check`
    - resultado: passou.
  - `rtk make ci`
    - resultado: 9/9 checks, 0 falhas.

### 2026-07-12 - auditoria de prontidao para producao

- Auditoria de residuos no diff:
  - sem `TODO/FIXME/HACK/XXX`;
  - sem `IO.inspect`, `dbg`, `console.log`;
  - sem `test.only`, `describe.only`, `it.only` ou `.skip`;
  - sem SVG inline remanescente nas superficies P2P auditadas.
- Correcao aplicada pela auditoria:
  - o SVG da rota compacta do diagrama P2P saiu de
    `Components.UI.P2PConnectionDiagram` e virou `Icons.icon_p2p_route`;
  - `docs/reference/svg-catalog.md` foi atualizado com o novo icone;
  - `.p2p-diagram-strip__packet--one` foi definido no CSS para manter o lint de
    consistencia de classes verde apos mover o SVG para o modulo de icones.
- Comentarios internos corrigidos:
  - `LobbyInvite` e `P2PSessionEvents` nao descrevem mais o fluxo antigo em que
    `/p2p` criava sessao pendente antes do setup;
  - comentario obsoleto de fase `F3` foi removido do lifecycle P2P.
- Gates executados nesta auditoria:
  - `rtk mix compile --warnings-as-errors`
    - resultado: passou.
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/setup_dialog_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/p2p_connection_diagram_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/p2p_stats_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
    - resultado: 22 testes, 0 falhas, 23 excluidos por tag.
  - `rtk mix test --include liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
    - resultado: 23 testes, 0 falhas.
  - `rtk mix compile --warnings-as-errors`
    - resultado: passou.
  - `rtk git diff --check`
    - resultado: passou.
  - `rtk make ci`
    - resultado: 9/9 checks, 0 falhas, 3m28s.
  - `rtk make lint.css`
    - resultado: passou apos corrigir `.p2p-diagram-strip__packet--one`.
  - `rtk git diff --check`
    - resultado: passou.
  - `rtk make ci`
    - resultado: 9/9 checks, 0 falhas, 3m19s.

### 2026-07-12 - refinamento premium: indicador P2P na aba de PM

- Gap visual corrigido:
  - a aba de PM do peer agora recebe indicador P2P durante todo o ciclo da
    sessao, nao apenas quando o WebRTC ja esta conectado;
  - estados visuais normalizados:
    - `pending` para convite pendente;
    - `connecting` para join/signaling em andamento;
    - `connected` para sessao ativa.
- Implementacao:
  - `ChatLive` passa `p2p_peer` e `p2p_state` para `ChatTabs` enquanto existir
    `@p2p_session`;
  - `ChatTabs` decide qual PM pertence a sessao e traduz o estado da maquina
    para o estado visual da aba;
  - `IrcTabs` renderiza o glyph P2P com tooltip, `data-p2p-state`, cor e dot de
    estado usando `RetroHexChatWeb.Icons`.
- Gates executados:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_tabs_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
    - resultado: 5 testes, 0 falhas, 23 excluidos por tag.
  - `rtk mix test --include liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
    - resultado: 23 testes, 0 falhas.
  - `rtk mix compile --warnings-as-errors`
    - resultado: passou.
  - `rtk git diff --check`
    - resultado: passou.
  - `rtk make ci`
    - resultado: 9/9 checks, 0 falhas, 3m39s apos stash/pull/reaplicar.

## Aprendizados

- A paridade correta nao e copiar a conferencia: o P2P precisa compartilhar a
  linguagem de midia, mas preservar PM, arquivo, jogos, privacy mode e conexao
  unica.
- A camada atual de P2P ja tem WebRTC real forte; o primeiro ganho esta em
  alinhar experiencia visual/operacional da Call, dialogs e indicadores.
- O `LobbyMediaHook` e o `LobbyWebRTCHook` sao o contrato real da feature P2P:
  qualquer redesign precisa manter ids/acoes DOM antes de mexer em layout.
- A paridade com conferencia fica mais segura quando a UI P2P nova nasce em
  `components/ui/p2p/**` e o LiveComponent continua apenas adaptando eventos.
- O status bar nao deve trocar a copy base ja usada pelo E2E; badges compactos
  sao a forma mais segura de enriquecer sem quebrar o reconhecimento atual.
- O setup P2P fica mais confiavel reaproveitando o hook de prejoin da
  conferencia com configuracao por data attributes, em vez de duplicar captura
  de camera/microfone.
- Device selector sem aplicar `deviceId` no `getUserMedia` e UX falsa; agora o
  device escolhido no setup percorre LiveView -> ilha -> hook -> constraints.
- Teste E2E deve esperar o botao/form visivel do dialog, nao o wrapper
  `data-testid` quando ele esta em um `span` sem caixa propria.
- Para testar preservacao de identidade de elemento sob LiveView, usar uma
  propriedade JS expando no node; `dataset` pode ser removido por patch mesmo
  quando o elemento foi preservado.
- O setup do criador nao deve criar sessao pendente antes do consentimento
  local; criar a sessao apenas no submit evita convites fantasma ao cancelar.
- `video.source` pertence ao hook WebRTC/stats, mas quem conhece a troca
  camera/screen e o hook de midia; um evento DOM local entre hooks manteve a
  separacao de responsabilidades.
- Mover SVG de `components/ui` para `components/icons` muda o escopo do lint de
  consistencia CSS; todo modificador de classe usado pelo icone precisa ter
  definicao explicita, mesmo quando o comportamento visual ja vinha do seletor
  base.
- Comentario obsoleto em fluxo de sessao e um gap de producao: ele nao quebra o
  teste, mas induz manutencao errada em caminhos destrutivos como setup,
  switch e cancelamento.
- Indicadores de sessao precisam cobrir o ciclo inteiro, nao so o estado feliz
  conectado; convite pendente e conexao em andamento tambem sao estados em que o
  usuario precisa entender onde a sessao vive.
