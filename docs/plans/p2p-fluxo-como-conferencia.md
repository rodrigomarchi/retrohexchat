# P2P com fluxo de entrada equivalente a conferencia

Data: 2026-07-24

Status: decisoes de produto confirmadas; pronto para detalhamento de
implementacao.

## Objetivo

Fazer a experiencia de entrar em uma sessao P2P parecer parte do mesmo sistema
de midia da conferencia de canal.

O objetivo nao e mudar o protocolo. Conferencia continua usando SFU/room de
canal, e P2P continua usando uma conexao WebRTC 1:1 com consentimento bilateral.
O objetivo e alinhar:

- fluxo de entrada;
- linguagem de produto;
- hierarquia visual;
- lugares onde o usuario descobre, entra, acompanha e sai da sessao;
- testes E2E e validacao visual com Playwright.

Hoje a plataforma ja tem uma base importante de paridade: P2P e conferencia
usam uma superficie principal por sessao, com secoes internas, setup/pre-join
com preview e device selectors, status bar, confirmacoes e controles de midia.
A divergencia que ainda pesa na UX esta antes da chamada ficar ativa: a
conferencia e sala-first; o P2P ainda e convite/lobby-first.

## Decisoes confirmadas

| Tema | Decisao |
|---|---|
| Quando abrir o console P2P | Abrir logo apos enviar a solicitacao P2P, ainda no estado `invite_sent`, com estado visual `Waiting for peer`. |
| Entrada no PM | O controle principal no PM deve se chamar `P2P`. Tooltips/popover podem explicar `Start P2P Session` ou `Join P2P Session`. |
| Convite recebido | Abrir a tab de PM sem roubar foco, mostrar badge/notification e, se o usuario ja estiver no PM, mostrar acao no header. |
| Card vs header | Remover completamente o card de convite do fluxo moderno. A entrada principal passa a ser o header/entry do PM, pareado com o modelo da conferencia no canal. |
| Console antes de conectar | Mostrar as secoes do console antes de conectar; Call/Files/Games/Stats ficam visiveis com estados empty/disabled ate a conexao estar pronta. |

## Fontes auditadas

Este plano foi criado a partir de leitura do codigo atual e dos documentos de
referencia abaixo. Documentos historicos foram usados como contexto, nao como
contrato atual quando entram em conflito com `media-session-p2p-conference-current.md`.

- `docs/reference/media-session-p2p-conference-current.md`
- `docs/plans/media-session-p2p-conference-fresh-audit.md`
- `docs/plans/p2p-paridade-conferencia.md`
- `docs/plans/p2p-paridade-conferencia-PROGRESS.md`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/group_call_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/setup_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/pre_join_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_session_console.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/session_badge.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/channel_badge.ex`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs`
- `e2e/tests/chat-p2p.spec.ts`
- `e2e/tests/chat-group-call.spec.ts`

## Tese de produto

P2P deve continuar sendo uma sessao privada 1:1 ancorada ao PM, mas o PM deve
funcionar como a "sala" do P2P.

Na conferencia, o usuario nao pensa em token, lobby ou link. Ele esta no canal,
clica `Call`, escolhe dispositivos no pre-join e entra na superficie da
conferencia.

No P2P, queremos a mesma sensacao:

1. O usuario esta em um PM ou escolhe um usuario.
2. Ele aciona uma entrada de midia P2P visivel e consistente.
3. Faz setup local com preview, mic, camera, devices e privacidade.
4. A outra pessoa recebe uma solicitacao clara.
5. Ao aceitar, ambos veem a mesma superficie P2P com estados de espera,
   conexao e midia.

O token e o objeto `lobby` continuam existindo no dominio, mas devem deixar de
ser a linguagem principal da UX.

## O que nao vamos fazer

- Nao vamos trocar P2P por SFU.
- Nao vamos remover consentimento bilateral.
- Nao vamos permitir entrada silenciosa em camera/microfone.
- Nao vamos copiar moderacao de canal para P2P.
- Nao vamos remover Files/Games/Stats do P2P.
- Nao vamos reintroduzir janelas top-level antigas `p2p-files`, `p2p-games` ou
  `p2p-stats`.
- Nao vamos depender de `/lobby/:token` como caminho moderno de produto. Ele
  pode continuar como compatibilidade legada redirecionando para o chat.
- Nao vamos manter card de convite P2P como superficie moderna. Solicitacao,
  entrada, aceite e declinio passam pelo chrome do PM.

## Comparacao do fluxo atual

| Etapa | P2P hoje | Conferencia hoje | Divergencia UX |
|---|---|---|---|
| Lugar natural | PM, mas a acao ainda fala "P2P Lobby" e depende de comando/menu/card. | Canal, com botao `Call` no topic bar. | Conferencia tem uma entrada fixa no lugar certo; P2P ainda parece recurso externo acionado por convite. |
| Acao inicial | `/p2p <nick>`, menu de contexto na nicklist ou mensagem. | Botao `Call` no canal ativo. | P2P exige conhecer comando/menu; conferencia e descoberta visual direta. |
| Setup local do criador | Abre `Prepare P2P Invite`; cancelar nao cria sessao. | Abre `Join Channel Conference`; cancelar nao cria/junta sala. | A estrutura e parecida, mas a linguagem do P2P enfatiza convite/lobby, nao sessao de midia. |
| Criacao no servidor | Depois do setup: `Lobby.create_session`, status `pending`, token persistido. | Depois do pre-join: cria/reusa room de canal, assina join token. | Diferenca tecnica correta, mas token/lobby vazam para o mental model. |
| Notificacao remota | PM `p2p_invite` com card Accept/Decline e `/lobby/<token>` embutido para enriquecer. | Indicador de conferencia ativa no canal/tab/topic; cada usuario entra por conta propria. | P2P usa o card como porta principal; conferencia usa indicador persistente de sala. Este plano remove o card do fluxo moderno. |
| Aceite do convidado | Card Accept abre setup P2P; submit `Join session`. | Botao/indicador de canal abre pre-join; submit `Join call`. | P2P tem um passo visual a mais antes do setup. O alvo e aceitar pelo header/entry do PM. |
| Abertura da superficie | `p2p-call` abre quando a sessao entra em `connected`. | `group-call` abre logo apos pre-join, ainda em `:joining`. | Conferencia da feedback espacial imediato; P2P pode ficar em espera no chat. |
| Estado de conexao | `pending -> lobby -> connecting -> connected`; WebRTC so inicia quando ambos os hooks estao prontos. | `joining -> negotiating/connecting -> connected`; SFU coordena via channel. | Estados tecnicos diferentes, mas a UX poderia usar a mesma linguagem de progresso. |
| Operacao ativa | Console unico `p2p-call`: Call, Files, Games, Stats. | Janela unica `group-call`: Call, People, Stats, Settings. | Boa paridade ja entregue. |
| Indicadores | Status bar, PM glyph, `p2p_peer_entry` quando existe sessao ativa. | Status bar, tab glyph, channel badge/popover mesmo antes do usuario entrar. | Indicador de conferencia e mais rico e mais ligado ao lugar natural. |
| Troca | Uma sessao P2P por usuario; aceitar/iniciar outra pede confirmacao. | Uma conferencia ativa por usuario; trocar canal pede confirmacao. | Paridade boa, mas P2P precisa explicar que call/files/games acabam juntos. |
| Fechar/sair | X confirma encerrar sessao P2P; minimizar mantem. | X/Leave confirma sair da conferencia; minimizar mantem. | Paridade boa. |

## Diagnostico

A chamada P2P nao esta "sem paridade" no painel de midia. A maior lacuna e a
admissao.

O P2P ainda carrega tres sinais de fluxo antigo:

1. **Linguagem de lobby**: comandos, contexto, card e alguns labels ainda dizem
   `P2P Lobby`, `lobby invite` ou mostram `/lobby/<token>`.
2. **Card como porta principal**: o convidado opera principalmente pelo card no
   transcript do PM, enquanto a conferencia usa uma entrada persistente no
   chrome do canal. Este plano remove o card do fluxo moderno.
3. **Superficie tardia**: o console P2P aparece quando a conexao ja esta
   `connected`; a conferencia abre a janela durante `joining`, o que da ao
   usuario uma sensacao mais clara de progresso.

Para resolver, precisamos transformar o PM no equivalente de "sala 1:1" e
fazer o P2P se apresentar como uma sessao de midia, nao como um link.

## Fluxo alvo

### Saida: usuario inicia P2P a partir de um PM

1. Usuario abre PM com `Fulano`.
2. Header/topic do PM mostra uma entrada de sessao P2P, semelhante ao botao
   `Call` do canal.
3. Usuario clica na entrada.
4. Abre setup local com preview, mic, camera, devices e privacidade.
5. Ao confirmar, o sistema cria a sessao `Lobby` e envia solicitacao ao peer.
6. O console P2P abre imediatamente em estado `Waiting for Fulano`, com
   Call/Files/Games/Stats visiveis mas travados/explicados conforme o estado.
7. Quando o peer aceita, o console progride para `Connecting`.
8. Quando o WebRTC conecta, o console progride para `Connected` e inicia midia
   conforme defaults.

### Saida: usuario inicia P2P por nicklist/context menu/comando

1. `/p2p Fulano` e menus continuam existindo.
2. Todos roteiam para o mesmo setup.
3. Se nao houver PM aberto, o PM e aberto como contexto da sessao.
4. A linguagem exibida deve ser `P2P Session`/`Call with Fulano`, nao
   `P2P Lobby`.

### Entrada: usuario recebe solicitacao P2P

1. PM do criador abre como tab sem roubar foco.
2. Badge/notification sinaliza que existe solicitacao P2P pendente.
3. Se o usuario ja estiver nesse PM, o header mostra a acao imediatamente.
4. O header do PM mostra uma entrada persistente `P2P`.
5. Clicar `Join` nessa entrada abre o setup P2P.
6. Cancelar setup nao aceita a sessao; a solicitacao permanece pendente.
7. Declinar encerra a sessao pendente e atualiza o indicador para estado
   terminal.

### Sessao ativa

1. O console P2P e a superficie primaria.
2. Secoes continuam: Call, Files, Games, Stats.
3. Header do PM e status bar focam a sessao.
4. Minimize mantem a sessao viva.
5. X/End Session confirmam teardown de toda a sessao.
6. `End call` encerra so midia, mantendo Files/Games/Stats disponiveis.

## Modelo visual alvo

| Area | Conferencia | P2P alvo |
|---|---|---|
| Entrada no lugar natural | Topic bar do canal: `Call` + badge live. | Header/topic do PM: `P2P` + badge pending/connecting/live. |
| Dialog de preparacao | `Join Channel Conference`. | `Start P2P Session` ou `Join P2P Session`. |
| Preview | `GroupCallPreJoinHook`. | `P2PSetupHook` usando o mesmo padrao. |
| Estados antes de conectar | Janela `group-call` em `joining`. | Console `p2p-call` abre ja em `invite_sent` e evolui por `joining`/`connecting`. |
| Indicador persistente | Channel badge/popover. | PM session badge/popover. |
| Superficie ativa | `group-call`: Call, People, Stats, Settings. | `p2p-call`: Call, Files, Games, Stats. |
| Confirmacao destrutiva | Lista impactos de sair/trocar/encerrar. | Lista impactos de encerrar call/files/games e trocar peer. |

## Arquitetura proposta

### 1. Linguagem e nomes de produto

Padronizar copy visivel:

- `P2P Lobby` -> `P2P Session`, exceto docs historicos e nomes internos.
- `Lobby invite` -> `P2P request` ou `P2P session request`.
- A entrada primaria usa `Join`; o fluxo moderno nao renderiza card de convite.
- `/lobby/<token>` deve permanecer apenas como dado embutido/compatibilidade,
  nao como link mental de produto.

Arquivos provaveis:

- `components/ui/chat/nicklist_context_menu.ex`
- `components/ui/chat/chat_context_menu.ex`
- `components/ui/chat/session_card.ex`
- `live/chat_live/helpers/lobby_invite.ex`
- catalogs `p2p`, `lobby`, `chat`, `commands` depois da decisao de copy.

### 2. Entrada P2P no chrome do PM

Criar uma entrada P2P permanente para PMs, equivalente ao
`GroupCall.ChannelBadge` no canal.

Comportamentos:

- Sem sessao: mostra acao para iniciar P2P com o peer do PM.
- Pendente recebido: mostra `Join`/`Decline` ou abre popover com acoes.
- Pendente enviado: mostra `Waiting`.
- Conectando: mostra `Connecting`.
- Ativo: mostra facetas, qualidade e acoes `Call`, `Stats`, `End`.

O componente atual `P2P.SessionBadge` ja cobre parte disso quando existe
sessao. A lacuna e o estado idle/pending recebido como entrada de PM, sem
depender de card no transcript.

Arquivos provaveis:

- `components/ui/p2p/session_badge.ex`
- `components/ui/chat/channel_view_switcher.ex` ou novo `PMViewSwitcher`
- `live/app/chat_live.html.heex`
- `live/chat_live/components/chat_tabs.ex`
- `live/chat_live/components/conversations.ex`

### 3. Evento unico para iniciar P2P do PM

Adicionar um evento semantico, por exemplo `p2p_open_for_peer` ou
`p2p_start_for_peer`, que receba o nick do PM ativo e use o mesmo caminho de
validacao do `/p2p`.

Regras:

- Deve exigir usuario identificado.
- Deve rejeitar self-call.
- Deve validar alvo registrado e online, como `Commands.Handlers.Lobby`.
- Deve respeitar ignore/block existente.
- Deve abrir setup antes de criar a sessao.
- Deve abrir/criar PM se a entrada veio de nicklist/comando.

Arquivos provaveis:

- `commands/handlers/lobby.ex`
- `live/chat_live/context_menu_events.ex`
- `live/chat_live/command_dispatch.ex`
- `live/chat_live/helpers/lobby_invite.ex`
- `live/chat_live/p2p_session_events.ex`

### 4. Console P2P antes de `connected`

Implementar abertura antecipada do console P2P para estados antes do WebRTC
conectado.

Estado atual:

- `p2p-call` so renderiza quando `@p2p_session && state != :invite_sent`.
- O criador em `:invite_sent` nao ve console; ve status/card.
- `enter_connected/2` abre `p2p-call`.

Fluxo alvo:

- Criador ve console em `invite_sent`, com estado `Waiting for peer`.
- Convidado pode ver console apos submit do setup em `joining/connecting`.
- O console deve bloquear ou explicar Files/Games/Stats ate a conexao estar
  pronta, sem esconder a superficie.

Pontos de cuidado:

- O anchor WebRTC deve continuar keyado por token.
- Nao iniciar signaling antes dos dois hooks prontos.
- Nao quebrar a regra de que pending invite ainda nao autoriza WebRTC nem
  auto-start de midia para quem ainda nao aceitou.
- Nao auto-startar midia antes do consentimento do convidado.

Arquivos provaveis:

- `live/app/chat_live.html.heex`
- `live/chat_live/p2p_session_events.ex`
- `live/chat_live/components/p2p_session_console.ex`
- `live/chat_live/components/p2p_media_island.ex`
- `components/ui/p2p/call_panel.ex`
- `assets/js/hooks/lobby/lobby_webrtc_hook.js`
- `assets/js/hooks/lobby/lobby_media_hook.js`

### 5. Pending request como read model de PM

Hoje o pedido P2P e enriquecido a partir do conteudo PM com token. Para o PM
header mostrar o pedido sem depender do scroll do transcript, precisamos de um
read model simples:

- pendente enviado para este peer;
- pendente recebido deste peer;
- ativo/conectando com este peer;
- terminal recente, se quisermos mostrar feedback curto.

Esse read model pode ser derivado de `@p2p_session` para a sessao local atual e
de queries de convites pendentes para o PM aberto. Manter escopo pequeno: nao
criar multi-sessao P2P.

Arquivos provaveis:

- `RetroHexChat.Lobby.Queries`
- `ChatLive.Helpers.PM`
- `ChatLive.PubsubHandlers.Messages`
- `ChatLive.P2PSessionEvents.rehydrate/1`
- `components/ui/p2p/session_badge.ex`

### 6. Remocao do card de convite moderno

O card de convite deixa de existir no fluxo moderno. O PM deve se comportar como
o canal na conferencia: existe um indicador/entry persistente no chrome da
conversa, e esse entry concentra as acoes de entrada.

O que muda:

- nova solicitacao P2P nao renderiza card Accept/Decline no transcript;
- aceite e declinio vivem no header/entry do PM;
- o transcript pode receber mensagens de sistema curtas para eventos relevantes;
- mensagens antigas com `/lobby/<token>` devem ser tratadas como legado
  inerte ou compatibilidade, sem virar porta principal do fluxo.

Essa decisao aproxima P2P da conferencia: o usuario entra pelo lugar da sessao,
nao por um cartao solto no historico de mensagens.

### 7. Consistencia de confirmacoes

Revisar confirmacoes P2P para refletir o novo mental model:

- Cancelar pedido pendente.
- Declinar pedido recebido.
- Encerrar sessao ativa.
- Trocar de peer.
- Fechar janela enquanto sessao esta ativa.

Copy deve mencionar impacto real:

- chamada para;
- transferencias em andamento param;
- jogo em andamento encerra;
- PM permanece como conversa normal;
- minimizar nao encerra.

## Tarefas propostas

### Fase 0 - alinhamento e inventario

- [x] Validar este documento com Rodrigo.
- [x] Definir copy final: `P2P Session`, `P2P Call`, `P2P request`, `Join`.
- [x] Decidir quando abrir o console: abrir no `invite_sent` do criador.
- [x] Decidir label da entrada no PM: `P2P`.
- [x] Decidir comportamento de pending recebido: abrir PM tab sem roubar foco,
      com badge/notification; se ja estiver no PM, mostrar acao no header.
- [x] Decidir card vs header: remover card do fluxo moderno.
- [x] Fazer snapshot de testes E2E atuais antes de mudar comportamento.

### Fase 1 - linguagem e entrada visual no PM

- [x] Trocar labels visiveis de `P2P Lobby` para `P2P Session` nos menus,
      headers e mensagens modernas.
- [x] Criar/estender componente de entrada P2P no PM header.
- [x] Mostrar acao idle `Start P2P` quando o PM ativo tem peer valido.
- [x] Mostrar estado `Pending` quando ha pedido recebido/enviado.
- [x] Mostrar acoes `Join`/`Decline` no pending recebido.
- [x] Garantir que a entrada do PM nao aparece em canais/status tab.
- [x] Ajustar tabs/sidebar para glyphs coerentes com pending/connecting/live.
- [x] Remover o card de convite P2P do transcript no fluxo novo.

### Fase 2 - evento unico e read model

- [x] Criar evento semantico para iniciar P2P a partir do PM.
- [x] Reusar validacoes de `/p2p` ou extrair uma funcao compartilhada para
      evitar divergencia entre comando, menu e PM header.
- [x] Implementar read model de pending P2P para o PM ativo.
- [x] Atualizar `rehydrate/1` para manter estado correto depois de reload.
- [x] Garantir que ignore/block remove ou bloqueia pending request de forma
      coerente.
- [x] Atualizar mensagens de erro para offline, nao registrado, self-call e ja
      em sessao.

### Fase 3 - superficie antecipada e estados de progresso

- [x] Permitir renderizar `P2PSessionConsole` em estados pre-connected
      selecionados.
- [x] Criar empty states do console: `Invite sent`, `Waiting for peer`,
      `Peer accepted`, `Connecting media`, `Connection failed`.
- [x] Garantir que Files/Games/Stats ficam visiveis mas nao prometem acao antes
      de `connected`.
- [x] Abrir/focar console imediatamente apos envio da solicitacao P2P.
- [x] Ao aceitar setup, abrir/focar console como a conferencia faz ao entrar em
      `:joining`.
- [x] Ao conectar, preservar a mesma janela e apenas mudar o estado para live.
- [x] Ao falhar, manter console aberto com retry acionavel.

### Fase 4 - ajustes de dialogs e confirmacoes

- [x] Renomear `Prepare P2P Invite` se a decisao de copy pedir.
- [x] Alinhar estrutura do setup P2P com o pre-join da conferencia onde fizer
      sentido.
- [x] Revisar copy de privacy/route para nao competir com a acao primaria.
- [x] Revisar `P2PConfirmDialog` para impactos de call/files/games.
- [x] Cobrir cancelar setup, declinar pelo header, aceitar pelo header e trocar
      peer nos testes.

### Fase 5 - Playwright E2E e screenshots

- [x] Atualizar seletores e expectativas de `e2e/tests/chat-p2p.spec.ts`.
- [x] Adicionar ou ajustar spec de captura visual para o novo fluxo P2P:
      desktop e mobile.
- [x] Capturar screenshots de:
      - PM idle com entrada P2P;
      - setup de criador;
      - pending enviado;
      - pending recebido no PM header com Join/Decline;
      - setup do convidado;
      - console `waiting/connecting`;
      - console conectado Call;
      - Files/Games/Stats no console;
      - erro/retry;
      - confirmacao de encerramento.
- [x] Capturar o fluxo equivalente de conferencia para comparar lado a lado:
      canal idle, pre-join, joining, connected Call, People, Stats, Settings.
- [x] Salvar screenshots em pasta deliberada:
      `e2e/test-results/p2p-flow-conference-parity/`.
- [x] Validar visualmente com screenshots desktop e mobile antes de considerar
      pronto.
- [x] Remover specs temporarias se forem criadas so para captura, ou promover
      para uma politica permanente de screenshot se essa for a decisao.

### Fase 6 - docs, help e i18n

- [x] Atualizar help de `/p2p`.
- [x] Atualizar help de P2P in Chat / Universal Lobby conforme nova linguagem.
- [x] Atualizar strings nos catalogs relevantes.
- [x] Registrar decisao final em `docs/reference/media-session-p2p-conference-current.md`.
- [x] Marcar docs historicos como superseded quando a nova UX estiver entregue.

## Testes obrigatorios

### Elixir / LiveView

- `p2p_session_flow_test.exs`
  - criador abre setup antes de criar sessao;
  - PM header inicia P2P;
  - pending recebido aparece no PM header;
  - accept pelo header abre setup;
  - novo convite P2P nao renderiza card actionable no transcript;
  - legado `/lobby/<token>` nao vira porta principal do fluxo;
  - cancelar setup nao aceita;
  - console abre em estado esperado;
  - trocar peer pede confirmacao;
  - encerrar sessao fecha console e atualiza PM/header.

- `group_call_flow_test.exs`
  - garantir que mudancas compartilhadas nao quebram pre-join e janela
    `group-call`.

- Component tests
  - `P2P.SessionBadge` idle/pending/connecting/live;
  - setup P2P sem overflow e com labels finais;
  - session card sem CTA indevida para criador ou viewers historicos.

### JavaScript / Vitest

- `group_call_prejoin_hook.test.js`
  - garantir que alteracoes compartilhadas no hook nao quebram conferencia.

- `lobby_webrtc_hook.test.js`
  - garantir que abrir console cedo nao inicia signaling cedo demais.

- `lobby_media_hook.test.js`
  - auto-start apenas depois de consentimento e hook ready.

### Playwright E2E

Usar E2E para comportamento real e tambem para capturas visuais.

Specs provaveis:

- `e2e/tests/chat-p2p.spec.ts`
- `e2e/tests/chat-group-call.spec.ts`
- nova spec temporaria ou permanente:
  `e2e/tests/p2p-flow-conference-parity.spec.ts`

Requisitos de validacao:

- desktop e mobile;
- fake media habilitado;
- aceitar/declinar pelo novo PM header;
- verificar ausencia do card actionable no fluxo novo;
- console abre sem depender de scroll do transcript;
- sem overflow horizontal;
- texto nao cortado em botoes principais;
- controles de mic/camera visiveis;
- estados de waiting/connecting/connected claros;
- screenshots lado a lado para P2P e conferencia.

## Criterios de aceite

- Usuario consegue iniciar P2P a partir do PM com o mesmo nivel de descoberta
  que inicia conferencia a partir do canal.
- Usuario convidado consegue entrar pelo PM header sem procurar o card antigo
  no transcript.
- O fluxo novo nao renderiza card de convite actionable no transcript.
- Mensagens legadas de convite nao viram a entrada principal da sessao.
- Console P2P e visivel durante o progresso de entrada decidido para o produto.
- Depois de conectado, P2P preserva Call, Files, Games e Stats no console unico.
- Conferencia nao sofre regressao visual ou funcional.
- Mobile e desktop usam o mesmo fluxo conceitual.
- Screenshots Playwright mostram consistencia visual e ausencia de overflow.
- Nomes visiveis nao empurram o usuario para `lobby`/`link` como conceito
  principal.
- Testes LiveView, Vitest e Playwright focados passam.

## Riscos e cuidados

| Risco | Cuidado |
|---|---|
| Abrir console P2P cedo pode parecer que a sessao ja foi aceita. | Estados e copy devem separar `request sent`, `waiting`, `connecting` e `connected`. |
| Header do PM pode ficar carregado. | Usar padrao compacto do channel badge e popover para detalhes. |
| Reusar validacao do comando pode criar acoplamento ruim. | Extrair helper semantico pequeno se o comando ficar pesado. |
| Pending requests antigos podem nao ter read model facil. | Tratar legado como mensagem inerte/compatibilidade; o header cobre pendings resolviveis. |
| Alterar copy quebra E2E por texto. | Preferir `data-testid` estaveis e atualizar expectativas deliberadamente. |
| Console antes de connected pode montar hooks cedo demais. | Manter gating do `SessionServer`: signaling so com ambos `webrtc_ready`; midia so apos consentimento e hook ready. |
| P2P tem Files/Games; conferencia nao. | Paridade e de fluxo e linguagem, nao de features. Nao esconder diferencas legitimas. |

## Ordem recomendada de implementacao

1. Copy e componente de entrada no PM.
2. Evento unico para iniciar P2P pelo PM, reusando setup existente.
3. Pending recebido/enviado no PM header.
4. Console P2P em estado pre-connected escolhido.
5. Ajustes de confirmacao e solicitacao.
6. E2E Playwright com screenshots desktop/mobile.
7. Help/i18n/docs finais.

Essa ordem reduz risco porque primeiro melhora descoberta e linguagem sem mexer
no protocolo. A parte mais delicada e abrir o console antes de `connected`, pois
ela toca no lifecycle visual e precisa respeitar o gating atual de WebRTC.
