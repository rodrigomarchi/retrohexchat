# Retro Games com AI

Plano para disponibilizar os jogos nativos do chat em modo single player,
começando pelo Hex Pong contra uma AI local e evoluindo jogo por jogo.

Este documento descreve trabalho em aberto. Quando a feature shippar, apagar este
plano e mover apenas decisões duráveis para os guias adequados.

## Objetivo

Adicionar uma nova superfície de jogos chamada **Retro Games**, separada do Arcade
WASM e separada do console P2P. Ela lista os jogos leves integrados ao chat que
hoje existem apenas no fluxo peer-to-peer e permite iniciar uma sessão solo contra
AI.

O primeiro jogo suportado foi Hex Pong. O segundo incremento aplicou o mesmo
playbook ao Light Trails. O terceiro incremento aplica o batch por família ao
Hex Outlaw e suas variantes. O quarto incremento aplica o mesmo playbook à
família Star Duel: Star Duel, Gravity Well e Debris Field.

## Decisões de produto

- **Retro Games é um item próprio no menu de jogos.** Ele deve aparecer ao lado do
  Arcade/WASM, não dentro dele.
- **Arcade/WASM continua sendo o fluxo de jogos externos/emulados.** Doom, Quake,
  Wolfenstein e similares permanecem no fluxo atual.
- **P2P continua significando jogar contra outra pessoa.** O console P2P não deve
  carregar o fluxo single player.
- **Retro Games significa jogos nativos do chat.** O usuário escolhe um jogo, vê o
  canvas carregado dentro de uma janela/ilha LiveView e pode iniciar uma partida
  contra AI.
- **A entrega evolui jogo por jogo.** Cada jogo só entra no catálogo solo quando
  tiver controller de AI local, contrato de engine testado e ajuda atualizada.

## Fluxo do usuário

Entrada principal:

- Menu `Games` abre um novo item `Retro Games`.
- O item abre uma janela do desktop chamada `retro-games`.

Fluxo inicial:

- A janela mostra o catálogo de jogos nativos.
- Hex Pong, Light Trails, a família Star Duel e a família Hex Outlaw aparecem
  como jogos disponíveis.
- Jogos futuros podem ficar ocultos até terem AI pronta. Se forem exibidos, devem
  aparecer como indisponíveis de forma explícita, sem prometer jogabilidade.

Seleção:

- Ao clicar em um jogo suportado, o painel troca para a tela do jogo.
- O canvas carrega dentro da janela.
- O jogo fica em estado pronto, sem iniciar automaticamente.
- O usuário escolhe dificuldade e clica em `Jogar contra AI`.

Partida:

- O jogo faz countdown e começa.
- A tela mostra placar, dificuldade e ações de controle.
- O usuário pode pausar, reiniciar, mutar ou sair.

Resultado:

- Ao fim da partida, a tela mostra placar final, dificuldade e duração.
- Ações esperadas: revanche, trocar dificuldade, voltar para a lista.
- O resultado não deve ser publicado no canal automaticamente. Compartilhar no chat
  pode ser uma ação futura explícita.

## Telas e estados

### Lista de Retro Games

Responsabilidade:

- apresentar o catálogo;
- destacar jogos disponíveis contra AI;
- preservar a diferença entre jogos nativos e Arcade/WASM.

Conteúdo inicial:

- título `Retro Games`;
- card ou lista compacta com os jogos suportados;
- descrição curta;
- ação primária para abrir o jogo.

### Setup do jogo

Responsabilidade:

- exibir o canvas carregado em modo pronto;
- mostrar controles e regras essenciais;
- permitir escolher dificuldade;
- iniciar a partida.

Controles:

- dificuldade: `Easy`, `Normal`, `Hard`;
- som ligado/desligado;
- botão `Jogar contra AI`;
- botão para voltar.

Decisões do MVP:

- jogador humano fica no lado/personagem local do jogo;
- AI fica no lado/personagem remoto;
- placar e regras seguem o jogo P2P atual;
- escolha de lado e tamanho da partida ficam fora do MVP.

### Jogo em andamento

Responsabilidade:

- manter o canvas em primeiro plano;
- mostrar status sem competir com o jogo;
- garantir controles previsíveis.

Elementos:

- placar;
- dificuldade;
- botão de pausa;
- botão de reinício;
- botão de mute;
- botão de sair.

Regras de foco:

- o jogo só deve capturar teclado quando a janela/canvas estiver ativo;
- `Esc` deve pausar ou liberar foco;
- minimizar ou esconder a janela deve pausar a partida;
- fechar a janela durante uma partida deve pedir confirmação para encerrar.

### Pausa

Responsabilidade:

- congelar simulação e AI;
- oferecer ações claras.

Ações:

- continuar;
- reiniciar;
- trocar dificuldade;
- sair.

### Resultado

Responsabilidade:

- mostrar fechamento local da partida;
- conduzir para revanche ou volta ao catálogo.

Conteúdo:

- vitória/derrota;
- placar final;
- dificuldade;
- duração;
- ações: revanche, trocar dificuldade, voltar.

### Erro

Responsabilidade:

- tratar falha de carregamento do bundle/engine;
- não deixar o usuário preso em loading.

Ações:

- tentar novamente;
- voltar para a lista.

## Arquitetura proposta

### Web/LiveView

Criar uma ilha LiveView para a janela `retro-games`.

Responsabilidades da ilha:

- controlar catálogo, seleção e estado da sessão;
- abrir/fechar a janela;
- renderizar setup, partida, pausa, resultado e erro;
- emitir eventos JS para carregar e controlar o canvas;
- receber eventos finais do hook, como fim de partida ou erro de engine.

A ilha não deve simular física, AI ou frames do jogo.

### Domain

Criar um contexto específico para jogos nativos solo, por exemplo
`RetroHexChat.SoloGames` ou `RetroHexChat.Games.Solo`.

Responsabilidades:

- validar se o jogo suporta modo solo;
- validar dificuldade;
- representar ciclo de vida da sessão;
- registrar resultado local quando necessário;
- publicar eventos de sessão quando a UI precisar reagir.

O contexto `Arcade` não deve ser reaproveitado diretamente, porque ele representa
jogos WASM em popup. O desenho pode reaproveitar o formato de sessão do Arcade,
mas o conceito de produto deve continuar separado.

### JavaScript

Adicionar um runtime solo para jogos nativos.

Peças sugeridas:

- `SoloGameCanvasHook`: monta o canvas e instancia o motor em modo solo;
- `SoloPongEngine`: usa a física e o renderer do Pong atual, mas não depende de
  WebRTC/DataChannel;
- `PongAI`: módulo puro que recebe estado do jogo e dificuldade, e devolve inputs
  para a raquete da AI.

Evitar criar um DataChannel falso ou um peer WebRTC local. Em solo, o browser do
usuário é sempre o simulador autoritativo.

## Camada JS da engine

O objetivo da mudança na engine JS é permitir dois modos de execução sem duplicar
física, renderer, áudio ou protocolo:

- `p2p`: host simula, guest envia input e desenha snapshots;
- `solo`: browser local simula, jogador controla o player 1 e a AI controla o
  player 2.

O modo solo não deve passar pelo WebRTC. A engine deve depender de contratos
explícitos, não de um `RTCDataChannel` improvisado.

### Separar transporte de simulação

Hoje `GameEngine` assume que sempre existe um `RTCDataChannel`: adiciona listener
de `message`, lê `bufferedAmount`, consulta `readyState` e chama `send`. Para
suportar solo com qualidade, essa dependência deve virar um transporte explícito.

Contrato sugerido:

- `addEventListener(type, callback)`;
- `removeEventListener(type, callback)`;
- `send(buffer)`;
- `readyState`;
- `bufferedAmount`;
- `kind`, por exemplo `p2p` ou `local`.

No P2P, esse transporte envolve o DataChannel real. No solo, o transporte local
não envia nada e não recebe mensagens, mas isso fica modelado como runtime local,
não como WebRTC falso.

### Separar origem de input do oponente

O Pong atual já tem a divisão correta de inputs:

- `localInputs`: inputs do jogador local;
- `remoteInputs`: inputs do adversário.

No P2P host, `remoteInputs` vem da rede.

No solo, `remoteInputs` deve vir de um controller de AI:

```text
PongEngine
  localInputs  <- teclado humano
  remoteInputs <- NetworkOpponentController no P2P
  remoteInputs <- PongAIController no solo
```

Esse controller deve ser plugável. A engine do Pong continua aplicando
`updatePaddle(state, 1, localInputs)` e `updatePaddle(state, 2, remoteInputs)`;
apenas a origem do segundo input muda.

### APIs públicas para controle da partida

O fluxo atual do P2P inicia quando o host recebe `GAME_READY`. No solo, a engine
precisa carregar em estado pronto e só começar quando a UI mandar.

Adicionar métodos públicos pequenos evita a LiveView/hook chamar métodos internos:

- `beginMatch(options)`;
- `pause()`;
- `resume()`;
- `restart(options)`;
- `setMuted(enabled)`;
- `stop()`.

No P2P, `beginMatch` continua sendo disparado pelo handshake. No solo, o hook chama
`beginMatch` quando o usuário clica em `Jogar contra AI`.

### Modos do Hex Pong

O Hex Pong deve continuar sendo uma engine única, com comportamento parametrizado
por modo.

Modo `p2p_host`:

- simula física;
- espera `GAME_READY`;
- recebe input remoto da rede;
- transmite snapshots;
- transmite resultado.

Modo `p2p_guest`:

- envia input local;
- recebe snapshots;
- renderiza estado interpolado;
- não simula física.

Modo `solo`:

- simula física localmente;
- não espera `GAME_READY`;
- não transmite snapshots;
- calcula input do player 2 via AI;
- reporta resultado para a ilha LiveView.

### Loader compartilhado

`LobbyGameCanvasHook` hoje contém o mapa de `game_id` para classe de engine. O modo
solo vai precisar carregar as mesmas famílias de engine, mas com capacidades
diferentes.

Extrair esse mapa para um loader compartilhado evita duplicação:

- `loadP2PEngineClass(gameId)`;
- `loadSoloEngineClass(gameId)`;
- `supportsSolo(gameId)`;
- `createGameEngine({ canvas, gameId, mode, transport, opponent, onGameEnd })`.

`supportsSolo/1` só deve ser verdadeiro para jogos que já têm runtime solo
validado: Hex Pong, Light Trails, família Star Duel e família Hex Outlaw neste
momento.

### Foco e teclado

`GameEngine` escuta `keydown` e `keyup` no `document`. Isso funciona no P2P, mas
fica perigoso para uma janela solo dentro do chat: o usuário pode estar digitando
ou operando outra janela.

O runtime solo precisa de captura explícita:

- canvas/janela ativa captura input;
- campos de texto nunca capturam input;
- `Esc` pausa ou libera foco;
- blur/minimize limpa inputs pressionados;
- partida pausada não aceita movimento.

Essa regra pode beneficiar também o P2P, mas a implementação inicial deve preservar
o comportamento atual do P2P.

### Telemetria

A telemetria atual observa `bufferedAmount` e `readyState`, que são conceitos de
rede. No modo solo, esses valores devem ser reportados como runtime local, por
exemplo:

- `transport_kind: "local"`;
- `buffered_amount: 0`;
- `ready_state: "local"`.

Isso evita exceções e mantém observabilidade sem fingir que houve rede.

### Playbook por jogo

Cada novo jogo solo deve seguir este checklist antes de entrar em
`Catalog.list_solo_games/0`:

- identificar como a engine P2P representa input local e input remoto;
- criar um controller puro em `assets/js/lib/games/<jogo>/ai.js`;
- fazer o controller emitir o mesmo shape de input remoto usado no P2P;
- adicionar `mode: "solo"` e `beginMatch(options)` sem duplicar física/renderer;
- garantir captura de teclado apenas durante a partida;
- cobrir controller, engine, loader, catálogo e LiveView com testes;
- atualizar help e rodar o pipeline Gettext;
- validar com `make ci`.

### Hex Pong

O motor atual já tem uma vantagem importante: no P2P, o host simula a partida e
recebe input remoto. No modo solo, a AI pode preencher o input remoto.

Fluxo técnico esperado:

- engine inicia como host local;
- não há handshake `GAME_READY` de outro peer;
- estado vai direto para countdown quando o usuário inicia;
- a cada tick, a AI calcula input para a raquete direita;
- física, colisão, placar, renderer e áudio continuam compartilhados com o Pong
  existente sempre que possível.

### Light Trails

O Light Trails usa input discreto por direção, não input pressionado contínuo. No
P2P, o host simula os dois jogadores e o peer envia comandos de direção via
`_sendInputEdge()`. No solo, a AI deve preencher `p2PendingDir` com o mesmo tipo de
direção que chegaria da rede.

Comportamento esperado:

- engine inicia como host local;
- jogador humano controla o player 1;
- AI controla o player 2;
- AI escolhe uma direção legal, nunca uma reversão de 180 graus;
- AI avalia colisão imediata com parede/trilha e prefere caminhos com mais espaço
  livre;
- dificuldade altera frequência de decisão, profundidade de avaliação e chance de
  erro controlado;
- regras de round, partículas, áudio e placar continuam compartilhadas com o P2P.

### Hex Outlaw

O Hex Outlaw usa input pressionado contínuo para movimento e tiro com borda
detectada pela engine. A família inteira compartilha a mesma engine:

- `hex_outlaw`;
- `hex_outlaw_ricochet`;
- `hex_outlaw_stagecoach`;
- `hex_outlaw_nml`.

Fluxo técnico esperado:

- engine inicia como host local;
- jogador humano controla o player 1;
- AI controla o player 2 preenchendo `remoteInputs`;
- AI devolve o mesmo shape de input do peer P2P: `up`, `down`, `left`, `right`,
  `fire`;
- AI desvia de tiros visíveis quando a trajetória cruza o hitbox do player 2;
- AI alinha verticalmente para tiros retos e respeita obstáculos centrais;
- no Ricochet, AI usa movimento vertical para preparar mira diagonal;
- no No Man's Land, AI também usa movimento horizontal dentro da zona permitida;
- dificuldade altera janela de esquiva, precisão, cooldown e chance de disparo;
- placar, round, hit pause, partículas, áudio e regras de match continuam
  compartilhados com o P2P.

### Star Duel

A família Star Duel usa input pressionado contínuo para rotação, propulsão, tiro
e warp. As três variantes compartilham a mesma engine:

- `star_duel`;
- `gravity_well`;
- `debris_field`.

Fluxo técnico esperado:

- engine inicia como host local;
- `mode` representa o runtime (`p2p_host`, `p2p_guest`, `solo`);
- `gameMode` representa a variante (`Open Space`, `Gravity Well`,
  `Debris Field`);
- jogador humano controla o player 1;
- AI controla o player 2 preenchendo `remoteInputs`;
- AI devolve o mesmo shape de input do peer P2P: `rotateLeft`, `rotateRight`,
  `thrust`, `fire`, `warp`;
- AI mira no oponente com lead simples, respeita cooldown e limite de mísseis;
- AI desvia de mísseis recebidos quando a trajetória cruza o player 2;
- em `Gravity Well`, AI prioriza fuga da estrela central quando entra em zona de
  risco;
- em `Debris Field`, AI evita asteroides próximos e não dispara por uma linha de
  tiro bloqueada por asteroide;
- dificuldade altera tolerância de mira, reação defensiva, distância preferida,
  cooldown e chance de disparo;
- placar, spawn, física orbital, colisões, partículas, áudio e regras de match
  continuam compartilhados com o P2P.

## Modelo da AI

A AI do Pong deve ser determinística, barata e baseada em heurística.

Entrada:

- posição e velocidade da bola;
- posição da raquete da AI;
- tamanho da arena;
- dificuldade;
- estado do placar quando útil.

Saída:

- `up`;
- `down`;
- sem input.

Comportamento:

- quando a bola vem em direção à AI, prever onde ela cruza o eixo da raquete;
- considerar rebotes nas paredes superior e inferior;
- mover a raquete com a mesma limitação de velocidade do jogador;
- quando a bola se afasta, voltar gradualmente para uma posição neutra;
- adicionar atraso de reação, erro de mira e pequenas decisões imperfeitas.

Dificuldades:

- `Easy`: reação lenta, erro alto, decisão menos frequente;
- `Normal`: previsão simples com erro moderado;
- `Hard`: previsão com rebotes, erro baixo e reação rápida.

Mesmo no Hard, a AI deve obedecer às regras do jogo. Ela não pode teleportar a
raquete nem acessar ações impossíveis para um jogador humano.

## Escopo do MVP

Inclui:

- item `Retro Games` no menu;
- janela `retro-games`;
- catálogo com Hex Pong;
- tela de setup;
- canvas inline;
- modo `Jogar contra AI`;
- dificuldades `Easy`, `Normal`, `Hard`;
- pausa, restart, mute e sair;
- resultado local;
- help topic atualizado para a nova feature;
- testes de domínio, LiveView e JS no nível adequado.

Fora do MVP:

- histórico persistente de partidas;
- rankings;
- escolha de lado;
- customização de placar máximo;
- compartilhar resultado automaticamente;
- convidar humano a partir da tela solo;
- AI para outros jogos;
- integração com `Bots.Capabilities.Game`.

## Plano de implementação

### Preparação

- Mapear os pontos atuais do menu de jogos, janelas do desktop e registro de
  janelas.
- Mapear o fluxo atual do Arcade para reaproveitar formato de estado sem herdar a
  semântica de jogos WASM.
- Mapear o Hex Pong atual para identificar o mínimo de adaptação necessário no
  motor.

### Produto e LiveView

- Adicionar a janela `retro-games` no registry do desktop.
- Adicionar item de menu `Retro Games`.
- Criar ilha LiveView da janela.
- Implementar estados de lista, setup, loading, playing, paused, finished e error.
- Garantir comportamento correto ao minimizar, fechar ou trocar de janela.

### Domínio

- Criar contexto de jogos solo nativos.
- Criar catálogo de jogos solo com suporte inicial a Hex Pong.
- Validar jogo e dificuldade no domínio.
- Modelar ciclo de vida de sessão.
- Emitir eventos de início, pausa, fim e encerramento quando necessário.

### Engine e AI

- Criar hook de canvas para modo solo.
- Criar adapter solo do Hex Pong.
- Criar módulo `PongAI`.
- Integrar dificuldade ao cálculo de input.
- Garantir que pausa congele física e AI.
- Garantir que final da partida retorne resultado para a ilha.

### Documentação e ajuda

- Atualizar `RetroHexChat.Chat.HelpTopics` com Retro Games e modo contra AI.
- Documentar no texto de ajuda a diferença entre Arcade/WASM, P2P e Retro Games.
- Atualizar qualquer menu/help existente que liste jogos disponíveis.

### Testes

- Testes de catálogo e validação de dificuldade.
- Testes do ciclo de vida de sessão solo.
- Testes LiveView para abrir a janela, selecionar Hex Pong, iniciar, pausar e
  finalizar.
- Testes JS para AI do Pong: direção de input, limites de movimento, dificuldade e
  comportamento sem bola ativa.
- Smoke visual/interativo para o canvas quando a janela estiver disponível no
  browser.

## Questões em aberto

- Nome final do item de menu: `Retro Games`, `Jogos Retro` ou nome bilingue
  compatível com a UI atual.
- Exigir usuário registrado/identificado como o Arcade atual ou permitir modo
  local para guest.
- Persistir resultado desde o MVP ou tratar resultado como estado efêmero da
  sessão.
- Exibir jogos futuros desabilitados ou esconder até que estejam jogáveis contra
  AI.
- Pausar automaticamente quando a janela perde foco ou apenas quando minimiza.

## Critério de conclusão

- O usuário consegue abrir `Retro Games` pelo menu.
- O usuário consegue escolher Hex Pong.
- O canvas carrega dentro da janela.
- O usuário consegue iniciar partida contra AI.
- A dificuldade muda o comportamento da AI de forma perceptível.
- Pausa, restart, mute, sair e resultado funcionam.
- O fluxo P2P existente continua inalterado.
- O Arcade/WASM existente continua inalterado.
- A ajuda do produto descreve a nova feature.
- `make ci` passa na revisão final da implementação.
