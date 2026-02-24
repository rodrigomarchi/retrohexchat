# Game Discovery: Slot Racers

## Identity

| Field | Value |
|-------|-------|
| **Name** | Slot Racers |
| **Original** | Atari, 1978 (programado por Warren Robinett) |
| **Genre** | Maze / Shooter |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_slots` |

## Why This Game

Slot Racers é Combat dentro de um labirinto com uma mecânica revolucionária: seus mísseis
FAZEM CURVAS seguindo os corredores. Programado por Warren Robinett (o gênio que depois criou
Adventure e escondeu o primeiro easter egg da história dos games), o jogo coloca dois carros
num labirinto onde nenhum pode dar ré e os mísseis contornam paredes. Isso cria um jogo de
xadrez em velocidade: você programa o míssil pra girar horário ou anti-horário e tenta
prever onde o oponente vai estar quando o míssil chegar lá. Totalmente cerebral,
completamente diferente de qualquer outro jogo no catálogo.

## Original Mechanics

### Core Loop
1. Dois carros num labirinto com corredores interconectados
2. Carros NÃO podem dar ré — só seguir em frente e fazer curvas
3. Cada jogador dispara mísseis que seguem os corredores do labirinto
4. Mísseis fazem curvas automaticamente baseado na programação (horário/anti-horário)
5. Míssil atinge oponente = 1 ponto
6. Primeiro a 25 pontos vence

### Movimento dos Carros
- Carro se move automaticamente pra frente
- Jogador controla DIREÇÃO com steering relativo:
  - Esquerda = virar anti-horário
  - Direita = virar horário
- Cima = acelerar
- Baixo = frear (desacelerar, NÃO parar completamente)
- Carro NÃO pode dar ré (sem marcha atrás)
- Carro segue os corredores do labirinto (não pode atravessar paredes)
- Ao chegar numa curva: vira automaticamente se só há um caminho, ou jogador escolhe

### Mísseis
- Cada jogador dispara um míssil por vez
- Míssil viaja pelo corredor na direção do disparo
- **Mecânica genial**: ao chegar numa interseção, o míssil faz curva baseado na programação:
  - Se programado HORÁRIO: sempre vira à direita
  - Se programado ANTI-HORÁRIO: sempre vira à esquerda
- Programação do míssil: definida pelo jogador ao disparar
  - Apertar esquerda + fire = míssil anti-horário
  - Apertar direita + fire = míssil horário
- Míssil viaja indefinidamente pelos corredores até atingir algo ou sair da tela
- Um míssil na tela por jogador

### Labirintos
- 4 layouts diferentes no original
- Corredores ortogonais (horizontal/vertical)
- Interseções em T e cruzamentos de 4 vias
- Simétricos (justo pra ambos)
- Paredes bloquam carros E mísseis (mísseis fazem curva, não atravessam)

### Variações do Original (9 modos)
Combinam: layout do labirinto + velocidade dos carros + velocidade/comportamento dos mísseis

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 12     SLOT RACERS     P2: 9            │
│┌────────────────────────────────────────────┐│
││████████████████████████████████████████████ ││
││█           █           █           █      █││
││█  ◉→       █           █       ←◎  █      █││
││█     ██████████    ████████████    █      █││
││█           █                  █    █      █││
││█     █     █    ████████████  █    █      █││
││█     █     █    █          █       █      █││
││█     █          █    ██    █  ●→→  █      █││
││█     ██████████ █    ██    ████████████   █││
││█                █          █              █││
││█  ████████████  ██████     █    ████████  █││
││█           █         █              █     █││
││█           █         █              █     █││
││████████████████████████████████████████████ ││
│└────────────────────────────────────────────┘│
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘
```

Legenda:
- █ = paredes do labirinto
- ◉ = carro P1 (com direção →)
- ◎ = carro P2 (com direção ←)
- ● = míssil em movimento (→→ indica direção)
- Espaços vazios = corredores navegáveis

### Labirintos

#### Layout 1: "Crossroads" (padrão)
```
████████████████████████████████
█       █       █       █      █
█  ◉    █       █    ◎  █      █
█    ████    ████████    █     █
█       █            █   █     █
█  █    █    ██████  █   █     █
█  █    █    █    █      █     █
█  █         █    █  ██████████
█  ████████  █    █            █
█            █         ████████
█  ████████  █████     █       █
█       █         █         █  █
████████████████████████████████
```

#### Layout 2: "Spiral"
```
████████████████████████████████
█                              █
█  ◉  ████████████████████  █  █
█     █                  █  █  █
█  ████  ████████████    █  █  █
█        █          █    █  █  █
█  ████  █  ██████  █    █  █  █
█     █  █  █    █  █    █     █
█     █  █  █ ◎  █  █  █████  █
█     █     █    █     █       █
█     ████  ██████  ████  █████
█                              █
████████████████████████████████
```

#### Layout 3: "Arena"
```
████████████████████████████████
█  ◉     █              █      █
█     █  █  ████████    █   ◎  █
█     █     █      █    █      █
████  ████  █  ██  █  ████  ████
█              ██         █    █
█  ████  ████      ████  ████  █
█     █     ████████     █     █
████  ████         ████  ████  █
█         █  ████  █           █
█  ████   █  █  █  █  ████████
█         █     █  █           █
████████████████████████████████
```

- 3 layouts fixos, selecionáveis no lobby
- Todos simétricos (spawn points equidistantes)
- Corredores largos o suficiente para 1 carro + 1 míssil

### Carros (sprites top-down)

```
Carro indo pra direita:    Carro indo pra cima:
    ┌───╮                     ╱╲
    │ → ╞═                   ╱  ╲
    └───╯                   │ ↑  │
                            └────┘

Com aceleração:            Freando:
    ┌───╮                    ┌───╮
    │ → ╞═ 💨               ▒│ → ╞═
    └───╯                    └───╯
```

- Sprite ~8x6 px (retangular, direção visível)
- Player 1: verde
- Player 2: ciano
- Seta interna indica direção atual
- Acelerando: rastro de velocidade atrás
- Freando: marcas de freio (visual)
- Hit: flash + carro pisca brevemente

### Mísseis (sprites)

```
Míssil reto:    Míssil fazendo curva:
    ──●          │
                 ╰──●     ← curva horária
```

- Ponto brilhante (~4px) com trail curto
- P1: míssil verde brilhante com trail verde
- P2: míssil ciano brilhante com trail ciano
- Trail mostra o caminho percorrido (desvanece)
- Ao fazer curva: trail marca a curva visualmente
- Hit: explosão de partículas na posição do oponente

### Controls
- **Left / Right arrows** — steering (anti-horário / horário)
- **Up arrow** — acelerar
- **Down arrow** — frear
- **Space** — disparar míssil
- **Space + Left** — míssil programado anti-horário
- **Space + Right** — míssil programado horário
- **WASD + Shift** — alternativo

### Mecânica de Míssil Detalhada

#### Disparo
- Apertar Space: míssil sai da frente do carro na direção atual
- Se apertar Space + Left: míssil é programado pra curvar ANTI-HORÁRIO
- Se apertar Space + Right: míssil é programado pra curvar HORÁRIO
- Se apertar Space sozinho: míssil vai reto (sem curva)

#### Navegação do Míssil
- Míssil viaja em linha reta pelo corredor
- Ao chegar numa interseção:
  - Se programado horário: SEMPRE tenta virar à direita
  - Se programado anti-horário: SEMPRE tenta virar à esquerda
  - Se não pode virar (parede): continua reto
  - Se beco sem saída: míssil desaparece
- Míssil nunca para — velocidade constante (1.5x velocidade do carro)
- Míssil viaja até: atingir oponente, atingir beco sem saída, ou ultrapassar tempo limite (~5s)

#### Estratégia de Míssil
- Programar míssil horário pra atingir oponente que está à sua direita
- Programar míssil anti-horário pra atingir quem está à esquerda
- O míssil segue os corredores: você precisa PREVER o caminho
- Conhecer o mapa é crucial — saber quais curvas o míssil vai fazer
- Míssil pode dar a volta no mapa inteiro e te atingir de volta!

### Mecânica de Carro Detalhada

#### Steering Relativo
- Esquerda/Direita NÃO movem o carro lateralmente
- Esquerda = próxima curva disponível, virar à esquerda
- Direita = próxima curva disponível, virar à direita
- Se não há curva: carro segue reto
- Numa interseção: carro vira na direção pressionada
- Sem input numa interseção: carro segue reto

#### Velocidade
- Velocidade base: constante (moderada)
- Acelerar (cima): 1.5x velocidade (~2s de duração, depois volta ao normal)
- Frear (baixo): 0.5x velocidade (enquanto segurar)
- NÃO há parada total — carro sempre se move (mínimo 0.3x)
- NÃO há ré — nunca

#### Colisão com Paredes
- Carro não pode atravessar paredes
- Se vai em direção a uma parede (beco sem saída): carro PARA (velocidade 0)
- Precisa virar (esquerda ou direita) pra sair do beco
- Isso é punição por navegação ruim — te deixa vulnerável

### Hit e Respawn
- Míssil atinge oponente: +1 ponto pro atirador
- Carro atingido: flash + invincibilidade (1.5s)
- Não há teleporte — carro fica onde está, apenas invencível brevemente
- Míssil desaparece após hit
- Novo míssil pode ser disparado imediatamente

### Scoring
- Hit com míssil: 1 ponto
- Primeiro a 25 pontos vence
- Sem timer (jogo acaba por pontuação)
- Best of 3 matches

### Game Modes (selectable in lobby)

1. **Classic**
   - Layout Crossroads
   - Velocidade normal de carros e mísseis
   - Mísseis programáveis (horário/anti-horário/reto)

2. **Speed Chase**
   - Layout Arena (mais aberto)
   - Carros e mísseis 1.5x mais rápidos
   - Reflexos rápidos necessários

3. **Labyrinth**
   - Layout Spiral (mais complexo)
   - Mísseis mais lentos (mais tempo pra planejar)
   - Cerebral: planejar o caminho do míssil é essencial

### Game State (synced via DataChannel)
- Car 1: position (x, y), direction, speed state (normal/accel/brake)
- Car 2: position (x, y), direction, speed state
- Missile 1: position (x, y), direction, programming (CW/CCW/straight), active flag, trail
- Missile 2: position (x, y), direction, programming, active flag, trail
- Maze layout (static, selected at game start)
- Scores + game phase

### Authority Model
- **Host** é autoritativo para: missile-car collision, missile pathfinding em interseções
- Maze é estático e compartilhado (ambos clientes têm o layout)
- Cada jogador envia: steering input, speed input, fire events + programming
- Host simula: carro positions, missile paths, colisões
- Host broadcast: positions, missile states, scores
- Guest renderiza com interpolação + missile trail

### Visual Style (Retro CRT)

- Background: preto
- Paredes: azul escuro/roxo com borda iluminada (neon maze vibe)
- Corredores: preto/cinza muito escuro
- Carro P1: verde brilhante com seta de direção
- Carro P2: ciano brilhante com seta de direção
- Míssil P1: ponto verde + trail verde desvanecendo
- Míssil P2: ponto ciano + trail ciano desvanecendo
- Trail do míssil: mostra o caminho completo (curvas visíveis!)
- Hit: explosão branca/amarela + screen shake sutil
- Beco sem saída (carro parado): carro pisca vermelho (warning)
- Interseções: sutis indicadores de quais direções são possíveis
- CRT scanlines + glow (neon maze intensifica o efeito)

### Sound Effects
- Motor: hum constante (pitch varia com velocidade)
- Aceleração: roar crescente
- Frenagem: screech suave
- Carro virando: click mecânico
- Carro preso em beco: buzz grave de warning
- Míssil disparado: zap direcional (pitch indica programação)
- Míssil viajando: whistle agudo constante
- Míssil fazendo curva: whoosh direcional
- Míssil atingiu oponente: boom + shatter
- Míssil em beco sem saída: fizzle (desvanece)
- Score update: blip
- Vitória: fanfarra de corrida

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Medium | Carro em trilhos de labirinto, steering relativo |
| Networking | Medium | 2 carros + 2 mísseis com pathfinding em maze |
| Rendering | Medium | Labirinto neon, missile trails, carros com rotação |
| Input | Medium | Steering relativo + velocidade + fire com programação |
| Game logic | Medium-High | Missile pathfinding em interseções (CW/CCW), maze collision |
| **Overall** | **Medium** | Pathfinding do míssil é o desafio principal |

## Fun Factor

- Mísseis que fazem curvas são FASCINANTES de assistir (trail mostra o caminho)
- Prever o caminho do míssil e acertar = momento "xeque-mate" satisfatório
- Carro que não dá ré cria momentos de "ESTOU PRESO!" hilários
- Conhecer o mapa dá vantagem absurda — replayability por domínio
- Cada tiro é um puzzle: "se eu programar horário, o míssil vai..."
- O medo de ser atingido pelo PRÓPRIO míssil (sim, é possível!) adiciona paranoia
- Perseguições pelo labirinto são cinematográficas
- Diferente de TUDO no catálogo — é Combat intelectualizado
- Warren Robinett (Adventure, easter egg) criou algo genuinamente único
- O "aha moment" de entender o pathfinding do míssil é viciante
