# Game Discovery: Tennis

## Identity

| Field | Value |
|-------|-------|
| **Name** | Tennis |
| **Original** | Activision, 1981 (programado por Alan Miller) |
| **Genre** | Sports |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_tennis` |

## Why This Game

Tennis da Activision é unanimidade nos fóruns retro: "fast paced, well thought out, and just
plain simple FUN." É o melhor jogo de tênis do Atari 2600 e captura a essência do esporte
com uma mecânica elegante: o ângulo da rebatida depende de ONDE a bola toca na raquete.
Sem botões extras pra lob, drop shot ou smash — tudo emerge do posicionamento e timing.
Saque, rally, voleio, tudo com o joystick e o posicionamento do sprite. Scoring real de
tênis (15-30-40-deuce-ad) adiciona drama. É o complemento esportivo perfeito pro Ice Hockey
no catálogo — hockey é caótico e rápido, tênis é preciso e estratégico.

## Original Mechanics

### Core Loop
1. Jogador saca a bola
2. Oponente se posiciona e rebate automaticamente ao contato
3. Rally continua até alguém errar (bola sai ou não alcança)
4. Pontuação segue regras reais de tênis
5. Primeiro a vencer o set ganha

### Quadra (Vista Lateral)
- Vista lateral da quadra com perspectiva 3/4 (semi-top-down)
- Rede no centro dividindo os dois lados
- Jogador 1 no lado esquerdo
- Jogador 2 no lado direito
- Linhas de fundo e laterais visíveis

### Movimento do Tenista
- Move em 4 direções: frente (pra rede), trás (pra linha de fundo), cima, baixo
- Velocidade constante
- Posição relativa à bola determina o ângulo da rebatida
- Rebatida é AUTOMÁTICA — bola toca no jogador = rebate
- Não precisa apertar botão pra rebater (apenas pra sacar)

### Rebatida e Ângulos
- Bola bate no CENTRO do sprite: rebatida reta (paralela)
- Bola bate na parte SUPERIOR do sprite: rebatida diagonal pra cima (cross-court)
- Bola bate na parte INFERIOR do sprite: rebatida diagonal pra baixo (cross-court)
- Bola bate na parte da FRENTE: rebatida com menos força (drop shot effect)
- Bola bate na parte de TRÁS: rebatida com mais força (drive)
- Toda a variedade de shots emerge do POSICIONAMENTO, não de botões

### Saque
- Sacador posiciona-se na linha de fundo
- Botão de ação = saca a bola
- Pode se mover lateralmente antes de sacar
- Saque vai automaticamente pro lado correto (alternando esquerda/direita)
- Não há falta de saque (simplificado)

### Rede
- Bola que toca a rede = ponto pro oponente
- Jogadores NÃO podem atravessar a rede
- Voleios (perto da rede) são possíveis e efetivos

## Our Adaptation (2-Player WebRTC)

### Screen Layout (vista 3/4 — perspectiva angular)

```
┌──────────────────────────────────────────────┐
│  P1: 30       TENNIS       P2: 15            │
│  Game: 3-2          Set: P1 leads            │
│┌────────────────────────────────────────────┐│
││╲                                          ╱││
││ ╲          ┌─REDE─┐                     ╱  ││
││  ╲         │░░░░░░│                    ╱   ││
││   ╲        │░░░░░░│                   ╱    ││
││    ╲   ☻   │░░░░░░│   ☻            ╱      ││
││     ╲      │░░░░░░│    ●          ╱       ││
││      ╲     │░░░░░░│             ╱         ││
││       ╲    └──────┘           ╱            ││
││        ╲─ ─ ─ ─ ─ ─ ─ ─ ─ ╱              ││
││         ╲                 ╱                ││
│└────────────────────────────────────────────┘│
│  15-30-[40]-deuce-ad                         │
└──────────────────────────────────────────────┘
```

Legenda:
- ☻ = tenistas (um de cada lado da rede)
- ● = bola
- ░░ = rede
- ╲╱ = linhas da quadra (perspectiva)
- Área entre as linhas = quadra jogável

### Quadra Detalhada

```
Vista top-down simplificada (para referência de gameplay):

    ╔══════════════╤══════════════╗
    ║              │              ║
    ║   ┌──────┐   │   ┌──────┐   ║
    ║   │ saque│   │   │saque │   ║
    ║   │  box │   │   │ box  │   ║
    ║   └──────┘   │   └──────┘   ║
    ║     ☻        │        ☻     ║
    ║              │              ║
    ║  P1 SIDE     │     P2 SIDE  ║
    ╚══════════════╧══════════════╝
         baseline  NET  baseline
```

- Quadra retangular com perspectiva 3/4 (leve inclinação)
- Rede vertical no centro
- Cada lado tem: linha de fundo, caixa de saque, área de voleio
- Superfície: verde (quadra de grama) ou clay (laranja)
- Linhas: brancas, bem visíveis

### Tenistas (sprites)

```
Tenista parado:         Rebatendo:          Correndo:
    ╭─╮                   ╭─╮                ╭─╮
    │☻│                   │☻│╮              │☻│
   ╭┴─┴╮                ╭┴─┴╯│            ╭┴─┴╮
   │   │                │   │╯             │   │
   ╰┬─┬╯                ╰┬─┬╯             ╰┬─┬╯
    │ │                   │ │               ╱ ╲
```

- Sprite ~10x16 px
- Player 1: verde (camiseta verde, raquete visível)
- Player 2: ciano (camiseta azul, raquete visível)
- Animações: idle, running (pernas alternando), swing (raquete balança), serve (braço pra cima)
- Sombra no chão (indicador visual de posição na perspectiva 3/4)

### Bola

```
Bola no ar:    Bola rápida:    Bola com sombra:
    ●              ●──          ●
                                ·  ← sombra no chão
```

- Sprite pequeno (~4px), amarelo brilhante
- Trail quando em velocidade alta
- Sombra no chão que indica posição real (crucial na perspectiva 3/4)
- Bola cresce/diminui sutilmente pra simular profundidade

### Controls
- **Arrow keys** — mover tenista (4 direções)
- **Space** — sacar (apenas quando é sua vez de sacar)
- **WASD** — movimento alternativo
- **Shift** — saque alternativo

Nota: Rebatida é AUTOMÁTICA. Não há botão de rebater.
Toda a habilidade está no POSICIONAMENTO.

### Mecânica de Rebatida Detalhada

#### Zona de Rebatida
- Cada tenista tem uma "zona de rebatida" ao redor do sprite (~16px raio)
- Bola entra na zona = rebatida automática
- Se a bola passa por fora da zona = ponto pro oponente

#### Ângulo da Rebatida (mecânica central)
O ângulo depende de onde a bola toca na zona do sprite:

```
Zona de rebatida:

    ╭────────────╮
    │ cross-court│  ← bola bate em cima = diagonal pra cima
    │   ┌────┐   │
    │   │    │   │  ← bola bate no centro = reta
    │   │SPRITE  │
    │   └────┘   │
    │ cross-court│  ← bola bate embaixo = diagonal pra baixo
    ╰────────────╯

    TRÁS ←→ FRENTE
    (mais força ← → menos força)
```

- **Centro**: rebatida reta (paralela à lateral)
- **Cima/Baixo**: rebatida angular (cross-court)
- **Frente** (perto da rede): rebatida suave (drop shot)
- **Trás** (longe da rede): rebatida forte (drive)
- Combinações criam toda a variedade: cross-court forte, drop shot angular, etc.

#### Velocidade da Bola
- Bola desacelera com a distância (simula gravidade/arrasto)
- Bola próxima da rede = rápida (voleio)
- Bola da baseline = mais lenta ao chegar
- Saque é o shot mais rápido

### Saque Detalhado
- Quando é sua vez de sacar: posicione-se atrás da baseline
- Pode se mover lateralmente pra escolher posição
- Apertar Space = saque na direção do service box adversário
- Saque alterna: primeiro ponto do game = lado direito, segundo = lado esquerdo
- Saque que acerta a rede = ponto pro receptor (sem segunda chance — simplificado)
- Saque é rápido (velocidade máxima da bola)

### Bola e Física

#### Trajetória
- Bola viaja em linha reta (simplificado — sem curva)
- Velocidade diminui com a distância
- Bola que sai das linhas = OUT (ponto pro oponente)
- Bola que toca a rede = NET (ponto pro oponente)
- Bola tem "sombra" no chão que mostra posição real

#### Profundidade (perspectiva 3/4)
- A quadra tem perspectiva, então a bola parece "ir pra longe" ou "vir pra perto"
- Sombra da bola no chão é a referência real de posição
- Bola "cresce" quando vem em sua direção, "diminui" quando vai embora
- Isso é puramente visual — gameplay é 2D mas parece 3D

### Scoring (Regras Reais de Tênis)

#### Pontos dentro de um Game
- 0 = Love
- 1 ponto = 15
- 2 pontos = 30
- 3 pontos = 40
- Se ambos em 40 = Deuce
- Depois de Deuce: vantagem (Ad In / Ad Out)
- Precisa 2 pontos consecutivos depois de Deuce pra ganhar o Game

#### Games dentro de um Set
- Primeiro a 6 games vence o Set
- Precisa vencer por 2 games de diferença
- Se 6-6: tiebreak (primeiro a 7 pontos, vencer por 2)

#### Match
- Best of 1 set (partidas rápidas pro contexto de chat)
- Opção de best of 3 sets pra partidas longas

### Troca de Lado
- A cada game ímpar completado (1, 3, 5...): jogadores trocam de lado
- Quem sacou agora recebe, e vice-versa
- Breve pausa (~2s) na troca

### Game Modes (selectable in lobby)

1. **Classic** (padrão)
   - 1 set, first to 6 games (win by 2)
   - Tiebreak em 6-6
   - Saque alterna a cada game

2. **Quick Match**
   - Primeiro a 3 games (sem necessidade de diferença de 2)
   - Sem tiebreak
   - Partidas mais curtas (~3-4 minutos)

3. **Sudden Death**
   - Cada game é 1 ponto (sem 15-30-40)
   - Primeiro a 6 games direto
   - Ultra rápido, cada ponto importa enormemente

### Game State (synced via DataChannel)
- Player 1: position (x, y), animation state
- Player 2: position (x, y), animation state
- Ball: position (x, y), velocity (vx, vy), shadow position, active flag
- Score: points in game (0-40/deuce/ad), games per player, set
- Serving: who serves, which side (left/right)
- Game phase: `waiting` → `serving` → `rally` → `point` → `serving` → ... → `game_over`

### Authority Model
- **Host** é autoritativo para: ball physics, hit detection, scoring, serve validation
- Cada jogador envia: position, serve events
- Host simula: ball trajectory, hit zone calculation, angle computation
- Host broadcast: ball state, scores, game phase
- Guest renderiza com interpolação (ball position é crítica)

### Visual Style (Retro CRT)

- Background: azul celeste (céu)
- Quadra: verde vibrante (grama) com linhas brancas nítidas
- Rede: branca com textura de malha
- Tenista P1: verde (camiseta + shorts)
- Tenista P2: ciano (camiseta + shorts)
- Raquetes: brancas, visíveis como extensão do braço
- Bola: amarelo brilhante com sombra cinza no chão
- Trail da bola: rastro amarelo quando em alta velocidade
- Out: bola pisca vermelho + "OUT" aparece
- Net: bola para na rede + "NET" aparece
- Ace (saque não rebatido): flash dourado + "ACE!"
- Scoreboard: estilo placar de tênis real (retro digital)
  ```
  ┌─────────────────────┐
  │ P1  │ 30 │ 3 │ 1   │
  │ P2  │ 15 │ 2 │ 0   │
  └─────────────────────┘
       pts  games sets
  ```
- Perspectiva 3/4: quadra com inclinação visual
- CRT scanlines + glow

### Sound Effects
- Movimento: passos rápidos no saibro/grama
- Saque: thwack forte (som mais alto que rebatida normal)
- Rebatida: pop/thwack (volume varia com força)
- Bola na rede: plonk suave + buzz
- Bola fora: thud + "out" sutil
- Ace: whoosh + sparkle
- Ponto ganho: umpire "beep" + score update
- Game ganho: arpeggio ascendente
- Set ganho: fanfarra
- Deuce: tension chord
- Match point: heartbeat acelerado
- Rally longo (5+ rebatidas): crowd murmur crescente
- Vitória final: crowd cheer + fanfarra de campeão

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Medium | Ball trajectory com desaceleração, ângulos por zona de hit |
| Networking | Low-Medium | Ball + 2 positions + score state |
| Rendering | Medium | Perspectiva 3/4, sombras, scoreboard estilo real |
| Input | Low | 4 direções + serve (rebatida é automática!) |
| Game logic | Medium | Scoring de tênis real (15-30-40-deuce-ad), games, sets, tiebreak |
| **Overall** | **Medium** | Perspectiva 3/4 e scoring complexo são os desafios |

## Fun Factor

- Rebatida automática com ângulo por posição é BRILHANTE — emergent gameplay puro
- Rallies longos são hipnóticos — "vai, vem, vai, vem, PONTO!"
- Deuce é tensão MÁXIMA: cada ponto pode ser o último
- Match point é de roer as unhas
- Cross-court perfeito = satisfação cirúrgica
- Drop shot que o oponente não alcança = humilhação deliciosa
- Scoring real de tênis adiciona drama e narrativa a cada game
- Complementa Ice Hockey perfeitamente: hockey = caos, tênis = precisão
- Ace no saque = momento de dominância total
- O ritmo natural do tênis (serve → rally → point → serve) é perfeito pra chat
- Sem botão de rebatida = zero confusão, toda habilidade em posicionamento
