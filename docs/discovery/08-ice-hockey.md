# Game Discovery: Ice Hockey

## Identity

| Field | Value |
|-------|-------|
| **Name** | Ice Hockey |
| **Original** | Activision, 1981 |
| **Genre** | Sports |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_hockey` |

## Why This Game

Ice Hockey da Activision é considerado um dos melhores jogos esportivos do Atari 2600.
Com apenas 2 jogadores por time (1 jogador + 1 goleiro), o jogo captura a essência do hockey
de forma brilhante: passes rápidos, gols improváveis, goleiro desesperado. A comunidade retro
é unânime — é "incrivelmente divertido depois de todos esses anos" e o "fun factor nunca diminui".
Para o RetroHexChat, é o jogo esportivo perfeito: rápido, competitivo, e com momentos de
pura euforia (GOL!!!).

## Original Mechanics

### Core Loop
1. Cada jogador controla um time de 2: um jogador de campo e um goleiro
2. O puck começa com um face-off no centro
3. Jogadores patinam, passam, roubam o puck e chutam pro gol
4. Gol = 1 ponto
5. Partida tem timer (3 períodos simulados)
6. Quem tiver mais gols ao fim vence

### Controle de Jogadores
- Jogador controla o jogador de campo diretamente (8 direções)
- Goleiro se move AUTOMATICAMENTE acompanhando o puck verticalmente
- Quando o jogador de campo está na zona defensiva, controle alterna pro goleiro
- Troca de controle entre campo e goleiro é automática baseada na posição do puck

### Puck
- Puck desliza no gelo com momentum (continua na direção após ser solto)
- Puck quica nas bordas superior e inferior do rink
- Puck é capturado automaticamente quando jogador de campo toca nele
- Com o puck, jogador pode chutar (shoot) na direção que está encarando

### Chute (Shot)
- Apertar botão chuta o puck na direção atual do jogador
- Velocidade do chute é maior que a velocidade de patinação
- Puck viaja em linha reta após chute
- Goleiro pode bloquear o chute (puck ricocheteeia)

### Roubo (Steal)
- Encostar no oponente que tem o puck pode roubar a posse
- Não é garantido — depende de ângulo e timing
- Cria disputas corpo-a-corpo pela posse

## Our Adaptation (2-Player WebRTC)

### Screen Layout (vista top-down do rink)

```
┌──────────────────────────────────────────────┐
│  P1: 2       ICE HOCKEY     P2: 1   Per: 2   │
│┌────────────────────────────────────────────┐│
││╔════╗                              ╔════╗  ││
││║    ║                              ║    ║  ││
││║ G1 ╟──────────────────────────────╢ G2 ║  ││
││║    ║       ☻         ☻            ║    ║  ││
││║    ╟──────────●───────────────────╢    ║  ││
││║    ║                              ║    ║  ││
││║ G1 ╟──────────────────────────────╢ G2 ║  ││
││║    ║                              ║    ║  ││
││╚════╝                              ╚════╝  ││
│└────────────────────────────────────────────┘│
│  Period 2 — 1:15 remaining                    │
└──────────────────────────────────────────────┘
```

Legenda:
- G1/G2 = goleiros (movem-se automaticamente na vertical)
- ☻ = jogadores de campo (controlados pelos jogadores)
- ● = puck
- ╔════╗ = gols (aberturas nas laterais)

### Rink (Pista de Gelo)
- Vista top-down (horizontal — gol esquerdo vs gol direito)
- Bordas superior e inferior: paredes onde o puck quica
- Bordas esquerda e direita: têm aberturas pro gol
- Gol: abertura vertical no centro de cada lateral (~30% da altura)
- Linha central: marcação visual (face-off point)
- Cantos arredondados (visual, não afetam gameplay)

### Jogador de Campo (sprite top-down)

```
Sem puck:          Com puck:          Chutando:
   ╭─╮               ╭─╮               ╭─╮
   │☻│               │☻│──●            │☻│──── ●→
   ╰─╯               ╰─╯               ╰─╯
```

- Sprite pequeno (~8x8 px) com taco de hockey visível
- Player 1: verde
- Player 2: ciano
- Quando tem o puck: puck fica "grudado" no taco
- Animação de chute: taco balança + puck é lançado

### Goleiro (sprite)

```
   ╔══╗
   ║GK║    ← mais largo que o jogador de campo
   ╚══╝
```

- Mais largo horizontalmente (~12x8 px) — cobre mais do gol
- Move-se apenas verticalmente
- Automático: segue a posição Y do puck com leve delay
- Bloqueia o puck por contato (puck ricocheteeia)
- Player 1 goleiro: verde escuro
- Player 2 goleiro: ciano escuro

### Controls
- **Arrow keys** — mover jogador de campo (8 direções)
- **Space** — chutar puck / tackle (sem puck)
- **WASD + Shift** — alternativo

### Mecânica de Posse

#### Captura
- Jogador de campo toca no puck = captura automática
- Puck fica grudado no taco do jogador
- Apenas um jogador pode ter o puck por vez

#### Chute (Shoot)
- Space com posse = chute na direção do movimento
- Velocidade do chute: ~2x velocidade de patinação
- Puck viaja em linha reta
- Se não atingir nada, puck desliza até bater na parede e quicar

#### Roubo (Tackle)
- Space SEM posse perto do oponente = tentativa de roubo
- Se o oponente tem o puck e está ao alcance: 60% chance de roubar
- Se falhar: breve stun no tackleador (~300ms)
- Cria risk/reward: tackle agressivo pode te deixar vulnerável

### Puck Physics
- Puck tem velocidade e direção (vetor 2D)
- Puck desliza com leve fricção no gelo (desacelera lentamente)
- Quica nas paredes superior/inferior (reflexão Y)
- Puck para ao ser capturado por um jogador
- Após chute, puck viaja rápido e vai desacelerando
- Se puck fica "preso" ou parado por 5s: novo face-off no centro

### Goleiro AI (automático)
- Segue a posição Y do puck com smoothing (não é instantâneo)
- Velocidade do goleiro: ~70% da velocidade do jogador de campo
- Só se move na vertical, posição X é fixa (dentro do gol)
- Quando o puck está longe: goleiro centraliza lentamente
- Quando o puck está perto: goleiro reage mais rápido
- Goleiro NÃO é perfeito — gaps são exploráveis com ângulos

### Gol
- Puck entra na abertura do gol = GOOOL!
- Animação: flash no gol, puck desaparece, placar atualiza
- Breve celebração (~2s): gol pisca, som de sirene
- Após gol: face-off no centro (puck para quem levou o gol)

### Períodos e Scoring
- 3 períodos de 2 minutos cada (6 min total)
- Entre períodos: tela de placar (3s)
- Times trocam de lado a cada período
- Se empate ao final: sudden death (próximo gol vence)
- Não há penalidades ou infrações — vale tudo!

### Face-off
- Início de cada período e após cada gol
- Ambos jogadores posicionados no centro, um de cada lado
- Puck no centro
- Contagem 3-2-1-GO
- Ambos tentam capturar o puck primeiro

### Game State (synced via DataChannel)
- Player 1 field: position (x, y), facing direction, has_puck flag
- Player 2 field: position (x, y), facing direction, has_puck flag
- Goalie 1: position (y)
- Goalie 2: position (y)
- Puck: position (x, y), velocity (vx, vy), possessed_by (nil/p1/p2)
- Scores + period + timer
- Game phase: `waiting` → `face_off` → `playing` → `goal` → `face_off` → ... → `finished`

### Authority Model
- **Host** é autoritativo para: puck physics, gol detection, tackle resolution, goleiro AI
- Cada jogador envia: posição do field player, eventos de chute/tackle
- Host simula: puck trajectory, goleiro movement, colisões
- Host broadcast: full state cada frame
- Guest renderiza com interpolação do puck (smooth movement)

### Visual Style (Retro CRT)

- Background: branco-azulado (gelo)
- Bordas do rink: linhas brancas grossas
- Linha central: azul tracejada
- Círculo de face-off: azul no centro
- Gols: aberturas vermelhas nas laterais
- Jogador 1: verde (corpo + taco)
- Jogador 2: ciano (corpo + taco)
- Goleiros: versão escura da cor do time
- Puck: preto com brilho branco
- Trail do puck: leve rastro quando em velocidade alta
- Gol: flash amarelo na abertura + partículas
- Gelo: textura sutil de riscos de patins (decorativo)
- CRT scanlines + glow consistentes

### Sound Effects
- Patinação: som de lâmina no gelo (loop suave enquanto move)
- Captura do puck: click seco
- Chute: slap forte (taco no puck)
- Puck na parede: thud
- Puck no goleiro: block (som mais grave)
- GOL: sirene de hockey (HONK!) + crowd cheer
- Face-off whistle: apito curto
- Tackle: body check sound (impacto)
- Tackle falhou: stumble sound
- Período end: buzina longa
- Sudden death: heartbeat background
- Vitória: fanfarra esportiva

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Medium | Puck com momentum + fricção + reflexão, colisões |
| Networking | Medium | Puck physics + 4 entities (2 jogadores + 2 goleiros) |
| Rendering | Medium | Rink top-down, sprites animados, puck trail |
| Input | Low | 8-dir movement + 1 action button |
| Game logic | Medium-High | Posse, tackle probability, goleiro AI, períodos, sudden death |
| **Overall** | **Medium** | O mais complexo dos 5, mas o mais replayable |

## Fun Factor

- GOOOOL! — poucas coisas em games são tão satisfatórias quanto marcar um gol
- Goleiro automático cria drama: "ele vai pegar? NÃO PEGOU!"
- Tackle risk/reward: roubar o puck na hora certa é elétrico
- Sudden death é pure adrenaline
- Partidas de 6 minutos: longas o suficiente pra criar narrativa, curtas pra replay
- Troca de lados entre períodos mantém justo
- Momentos de "quase gol" geram gritos (mesmo digitando no chat)
- Hockey é naturalmente caótico — cada partida é diferente
- O puck deslizando no gelo com physics é hipnoticamente satisfatório
