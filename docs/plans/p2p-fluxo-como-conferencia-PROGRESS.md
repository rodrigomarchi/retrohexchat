# P2P fluxo como conferencia - progresso

Data inicial: 2026-07-24

Objetivo: concluir `docs/plans/p2p-fluxo-como-conferencia.md` com ciclos TDD,
registrando progresso e aprendizados a cada iteracao.

## Como registrar cada iteracao

Cada iteracao deve responder:

- Escopo: qual parte do plano esta sendo atacada.
- Teste primeiro: qual teste foi criado ou ajustado antes da implementacao.
- Falha esperada: qual comportamento atual falhou e por que.
- Implementacao: quais arquivos mudaram.
- Validacao: comandos executados e resultado.
- Aprendizado: o que foi descoberto sobre UX, fluxo ou arquitetura.

## Iteracao 0 - inventario inicial

Escopo:

- Ler instrucoes locais.
- Confirmar plano de produto.
- Mapear os pontos de divergencia no codigo atual.

Teste primeiro:

- Ainda nao houve edicao de teste nesta iteracao. Ela serviu para escolher os
  primeiros contratos TDD.

Falha esperada para a proxima iteracao:

- Criador nao ve console P2P no estado `invite_sent`.
- Header do PM nao mostra entrada `P2P` quando esta idle.
- Pedido recebido ainda depende de card actionable no transcript.
- `p2p_console_select` ignora `invite_sent`.
- Labels visiveis ainda usam `P2P Lobby` em menus.

Implementacao:

- Criado este arquivo de progresso.

Validacao:

- `rtk cat /Users/rodrigo/.codex/RTK.md`
- `rtk git status --short`
- Leitura de plano, LiveView, componentes P2P, helpers de PM, PubSub e testes.

Aprendizado:

- O console P2P ja e uma superficie unica boa; o bloqueio principal esta em
  `chat_live.html.heex`, que so renderiza `p2p-call` quando
  `@p2p_session.state != :invite_sent`.
- O WebRTC anchor tambem usa esse gate; isso e correto e deve continuar assim
  para nao iniciar signaling antes do aceite.
- `SessionBadge` ja renderiza o label `P2P`, mas so aparece quando existe uma
  `@p2p_session` do PM ativo. O novo fluxo precisa de uma entrada idle e de
  pending recebido derivado do banco.
- PM activity ja abre a tab sem roubar foco e marca unread. O convite P2P pode
  aproveitar esse comportamento porque a PM `p2p_invite` emite `pm_activity`.
- `SessionCard.enrich/1` transforma PM `p2p_invite` em card actionable. Para o
  fluxo moderno isso deve virar historico/compatibilidade, com acoes migradas
  para header/entry do PM.

## Iteracao 1 - contrato LiveView do novo fluxo P2P

Escopo:

- Parear o fluxo P2P com conferencia no PM: entrada fixa no header, console
  aberto apos envio, aceite/decline no controle do PM e transcript sem card
  acionavel.

Teste primeiro:

- Ajustados/criados testes em:
  `p2p_session_flow_test.exs`, `session_badge_test.exs`,
  `message_row_test.exs`, `setup_dialog_test.exs`, `session_card_test.exs` e
  `p2p_media_island_test.exs`.
- Os contratos novos cobrem idle no PM, convite recebido pelo header, console
  imediato em `invite_sent`, ausencia do WebRTC hook antes do aceite e
  transcript de convite como linha informativa.

Falha esperada:

- A primeira rodada falhou porque o entry P2P so existia quando havia sessao
  ativa, o card ainda tinha accept/decline, o dialog ainda falava
  `Prepare P2P Invite` e o console nao era renderizado em `invite_sent`.
- A segunda rodada expôs que o empty state da call ainda comunicava
  `P2P media is offline`, que conflita com o estado real de aguardar aceite.

Implementacao:

- `P2PSessionEvents` agora abre o console apos enviar o convite, aceita selecao
  de secao durante `invite_sent` e mantem um read model por PM em
  `p2p_pm_sessions`.
- `ChatLive`, `ChatTabs` e `Conversations` recebem/propagam esse read model e
  geram uma entrada idle quando o PM ativo nao tem sessao.
- `SessionBadge` suporta estados `idle` e `pending_received`, com Start/Join/
  Decline no controle do PM.
- `MessageRow` renderiza `:p2p_invite` como linha simples de request; o
  `SessionCard` fica apenas como resumo historico sem acoes.
- `SetupDialog`, menus e comando `/p2p` passam a usar a linguagem
  `P2P Session`.
- `CallPanel` mostra `Waiting for peer` antes da conexao, deixando claro que o
  console ja existe, mas os controles dependem do aceite.

Validacao:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/session_badge_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/setup_dialog_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/session_card_test.exs`
  - 31 tests, 0 failures.
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs --include liveview_feature`
  - 33 tests, 0 failures.

Aprendizado:

- O estado `invite_sent` deve montar o shell do console, mas nao o anchor
  `p2p-webrtc`; isso preserva a paridade visual sem iniciar signaling antes do
  aceite.
- O convite recebido funciona melhor como read model de PM: a tab abre em
  background, o unread/badge vem do fluxo existente e a acao natural fica no
  header do PM.
- Remover o card acionavel reduz bifurcacao de UX: o transcript vira historico,
  enquanto Start/Join/Decline vivem no mesmo lugar onde a conferencia expoe sua
  acao principal.

## Iteracao 2 - Playwright e validacao visual

Escopo:

- Ajustar o E2E P2P para o novo fluxo pelo header do PM e usar screenshots para
  validar a superficie visual do console.

Teste primeiro:

- `chat-p2p.spec.ts` passou a aceitar convite por `p2p-peer-join`, recusar por
  `p2p-peer-decline` e afirmar negativamente que `session-card-accept`/
  `session-card-decline` nao existem mais no transcript.
- O helper de envio agora exige console visivel imediatamente, empty state
  `Waiting for peer` e ausencia de `p2p-webrtc` antes do aceite.
- O fluxo principal captura screenshots do console em estado pendente,
  conectado desktop e conectado mobile, checando imagem nao vazia por tamanho
  de buffer.

Falha esperada:

- Antes da alteracao, o E2E clicava nos botoes antigos do card e nao validava a
  visibilidade real do console do criador em `invite_sent`.

Implementacao:

- Atualizado `e2e/tests/chat-p2p.spec.ts`.
- Dois testes WebRTC pesados receberam timeout explicito de 75s, seguindo o
  padrao ja existente no caso audio-only. Eles passaram isolados, mas estouravam
  o timeout global de 30s na suíte completa.

Validacao:

- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "accepting from the PM header"`
  - PASS (1) FAIL (0).
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "declining the invite"`
  - PASS (1) FAIL (0).
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts`
  - Primeira execucao: PASS (7) FAIL (2), ambos timeouts em casos WebRTC longos.
  - Reproducao isolada dos dois casos: PASS (1) FAIL (0) para cada.
  - Apos timeout explicito: PASS (9) FAIL (0).

Aprendizado:

- O teste de navegador confirmou a diferenca importante entre "renderizado no
  HTML" e "visivel para o usuario"; o console fica visivel logo apos enviar.
- A PM recebida abre em background com unread antes do clique no header,
  preservando o foco do usuario.
- A validacao visual sem snapshot dourado e suficiente aqui: captura a janela
  real, impede console em branco e combina com as checagens de layout/overflow
  ja presentes no spec.

## Iteracao 3 - remover card legado e fechar suites

Escopo:

- Remover o card P2P como estrutura de runtime, alinhar help/docs e fechar
  validacao ampla.

Teste primeiro:

- A suíte padrao (`rtk mix test`) revelou dois contratos antigos fora dos testes
  focais: `CallPanelTest` ainda esperava `Connect to start` e `ChatTabsTest`
  exercitava o glyph via `p2p_peer`/`p2p_state`.
- Os testes de mensagem/E2E continuaram afirmando negativamente que
  `session-card-accept` e `session-card-decline` nao aparecem no fluxo novo.

Falha esperada:

- A UI ja nao renderizava o card, mas `SessionCard.enrich/1` ainda anexava
  `session_card` a `:p2p_invite` durante a montagem de streams. Isso mantinha
  codigo morto e risco de reintroducao.

Implementacao:

- Removidos `P2PInviteCard`, `Components.UI.SessionCard`,
  `ChatLive.Helpers.SessionCard` e seus testes especificos.
- Removidos pipes `SessionCard.enrich()` de channel/PM/core/pubsub builders.
- `ChatTabs` preserva compatibilidade para callers baixos que passam apenas
  `p2p_peer` + `p2p_state`.
- Help e docs foram atualizados para `P2P Session`, `P2P request`, Join/Decline
  no header do PM e transcript como historico inerte.
- `docs/reference/media-session-p2p-conference-current.md` passou a registrar o
  contrato final.
- Screenshots deliberados foram salvos em
  `e2e/test-results/p2p-flow-conference-parity/` e validados visualmente:
  pending, connected desktop e connected mobile.

Validacao:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_tabs_test.exs`
  - 14 tests, 0 failures.
- `rtk mix test`
  - `retro_hex_chat`: 15 properties, 2732 tests, 0 failures.
  - `retro_hex_chat_web`: 794 tests, 0 failures, 263 excluded.
- `rtk mix format --check-formatted`
  - Falhou antes do formatter por quebras de linha em links `.heex` alterados
    para `P2P Session`.
- `rtk mix format`
  - Aplicou apenas formatacao.
- `rtk mix format --check-formatted`
  - PASS.
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/session_badge_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs`
  - 49 tests, 0 failures.
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - 27 tests, 0 failures.
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "accepting from the PM header"`
  - PASS (1) FAIL (0), gerando screenshots.
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts`
  - PASS, FAIL (0) em execucoes finais; uma execucao reportou contagem agregada
    menor pelo wrapper, entao os fluxos impactados tambem foram rodados
    individualmente.

Aprendizado:

- Esconder o card no render nao era suficiente; remover o enriquecimento fecha
  melhor a divergencia de UX e simplifica o fluxo mental.
- O termo `Lobby` ainda aparece em modulos/tabelas internas. Isso e contexto de
  arquitetura, nao copy de usuario.
- A validacao visual confirmou que o console pendente nao fica em branco e que
  desktop/mobile mantem a mesma estrutura de abas/secoes.

## Iteracao 4 - main atualizada e validacao visual final

Escopo:

- Remover workarounds experimentais criados durante a investigacao E2E.
- Atualizar a branch local com a `main`, que contem o fix do pipeline de assets
  dev/producao.
- Revalidar P2P e conferencia por Playwright com screenshots persistidos.

Implementacao:

- Removidos os contornos temporarios em `ConnectPage.registerWithPassword/1` e
  `ChatPage.switchToTab/1` que escondiam dropdowns antes de clicar.
- `rtk git pull --rebase --autostash origin main` aplicou `c509e639`
  (`fix(assets): dev build now matches the production asset pipeline`) sem
  conflito.
- `rtk mix assets.build` reconstruiu JS/CSS com o pipeline atualizado.
- O spec visual de conferencia passou a salvar screenshots em
  `e2e/test-results/group-call-visual-polish/`.

Validacao:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - 27 tests, 0 failures.
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts`
  - Primeira execucao apos o pull: PASS (7) FAIL (1), falha em WebRTC screen
    share aguardando video remoto live.
  - Reproducao isolada do caso `screen share marks`: PASS (1) FAIL (0).
  - Segunda execucao completa: PASS (7) FAIL (0).
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-group-call.spec.ts -g "conference visual polish"`
  - PASS (1) FAIL (0), antes e depois de persistir os screenshots.
- O screenshot P2P conectado passou a aguardar pixels reais do video remoto
  sintetico antes da captura, evitando PNG conectado com painel preto.
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - PASS (28) FAIL (0).
  - Gerou, na mesma execucao, os screenshots finais de P2P e conferencia.
- `rtk mix test`
  - `retro_hex_chat`: 15 properties, 2732 tests, 0 failures.
  - `retro_hex_chat_web`: 794 tests, 0 failures, 263 excluded.

Screenshots validados visualmente:

- P2P:
  - `e2e/test-results/p2p-flow-conference-parity/p2p-pending-console.png`
  - `e2e/test-results/p2p-flow-conference-parity/p2p-connected-desktop.png`
  - `e2e/test-results/p2p-flow-conference-parity/p2p-connected-mobile.png`
- Conferencia:
  - `e2e/test-results/group-call-visual-polish/conference-desktop.png`
  - `e2e/test-results/group-call-visual-polish/conference-mobile.png`

Aprendizado:

- A falha anterior de ambiente era consistente com assets antigos/desalinhados;
  apos o fix da `main`, o spec visual de conferencia passou sem workarounds.
- O caso de screen share P2P ainda tem sensibilidade temporal quando roda dentro
  da suite completa, mas passou isolado e depois passou na suite completa. Nao
  houve evidencia de regressao no fluxo novo de PM/header.
- A paridade visual/UX entre P2P e conferencia agora esta coberta por screenshots
  persistidos: ambos usam janela, tabs/secoes, empty state explicito e controles
  no painel de media, com adaptacao mobile checada.
- A validacao por screenshot deve esperar render real, nao apenas estado de
  conexao; track `live` ainda pode produzir um frame visualmente preto no PNG.

## Iteracao 5 - hardening de resiliencia WebRTC P2P

Escopo:

- Endurecer o fluxo P2P apos uma nova rodada completa expor flake real de
  WebRTC: sessao conectada, UI saudavel, mas video remoto preso sem RTP/frame.

Teste primeiro:

- `lobby_media_hook.test.js` ganhou contratos para:
  - enfileirar auto-start de midia ate a `RTCPeerConnection` estar pronta;
  - escalar video remoto travado de renegociacao simples para restart
    coordenado;
  - mutar o elemento `<video>` remoto e chamar `play()` ao anexar stream;
  - republicar tracks locais e descartar stream remoto antigo quando a
    `RTCPeerConnection` e substituida durante reconnect.

Falha observada:

- Uma execucao completa fresca de `chat-p2p.spec.ts` falhou no caso
  `screen share marks the peer tile and the P2P stats video source`.
- O timeout ocorreu antes do screen share, aguardando `remoteVideoLive(bob)`.
  Screenshots mostravam estado conectado, qualidade excelente e 4 tracks, mas
  o video remoto estava preto/stallado.
- Depois do primeiro hardening, a primeira suite P2P passou, mas a segunda
  repeticao voltou a falhar no mesmo ponto. Isso confirmou que nao era apenas
  autoplay ou start cedo; o restart de recovery tambem precisava restaurar o
  estado de midia local/remota.

Implementacao:

- `RtcMediaHookFactory` agora:
  - guarda comandos de `start_call` recebidos antes da PeerConnection e drena
    quando o WebRTC hook emite `lobby_media_pc_ready`;
  - usa `autoplay`, `playsInline`, `muted` apropriado e `play()` defensivo ao
    anexar streams;
  - monitora video remoto travado e escala de renegociacao para
    `lobby_media_restart`;
  - ao receber uma PeerConnection nova, limpa streams remotos stale, zera
    contadores de stall e republica as tracks locais na conexao nova.
- O ultimo ponto fecha a lacuna principal: o WebRTC hook ja reconstruia a
  conexao e propagava restart aos dois peers, mas o media hook ainda podia ficar
  segurando senders/remote tracks da conexao antiga.

Validacao:

- `rtk npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/lobby/lobby_media_hook.test.js`
  - 14 tests, 0 failures.
- `rtk npm run format:check --prefix apps/retro_hex_chat_web/assets`
  - PASS.
- `rtk mix assets.build`
  - PASS, com novo chunk `app-lobby_media_hook-...js`.
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "screen share marks"`
  - PASS (1) FAIL (0).
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts`
  - Primeira execucao apos republish: PASS (7) FAIL (0).
  - Segunda execucao completa consecutiva: PASS (8) FAIL (0).
- `rtk npm test --prefix apps/retro_hex_chat_web/assets`
  - 141 files, 3928 tests, 0 failures.
- `rtk npx playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - PASS (27) FAIL (0).
- Screenshots visualmente reinspecionados:
  - P2P pending, conectado desktop e conectado mobile;
  - conferencia desktop e mobile.
- `rtk mix format --check-formatted`
  - PASS.
- `rtk npm run format:check --prefix apps/retro_hex_chat_web/assets`
  - PASS.
- `rtk git diff --check`
  - PASS.
- `rtk mix test`
  - `retro_hex_chat`: 15 properties, 2732 tests, 0 failures.
  - `retro_hex_chat_web`: 794 tests, 0 failures, 263 excluded.

Aprendizado:

- Recovery de WebRTC nao termina na recriacao da PeerConnection. O media layer
  precisa republicar tracks locais e abandonar tracks remotas antigas; senao a
  UI pode parecer conectada enquanto a superficie de video continua lendo um
  track stale.
- A verificacao repetida da suite completa foi essencial. O teste isolado de
  screen share passou mesmo quando a suite completa ainda flakava.
- A evidencia atual e mais forte que a da iteracao anterior: P2P passou duas
  vezes em suite completa apos a correcao, e a suite combinada P2P +
  conferencia tambem passou.
