# Game Discovery: Outlaw

## Identity

| Field | Value |
|-------|-------|
| **Name** | Outlaw |
| **Original** | Atari, 1978 (criado por David Crane) |
| **Genre** | Action / Shooter |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_outlaw` |

## Why This Game

Outlaw é o duelo western definitivo do Atari. Dois pistoleiros, um de cada lado da tela,
trocando tiros com um obstáculo no meio. A genialidade está nas variações: cactos que bloqueiam,
muros que se movem, tiros que ricocheteiam, diligências passando. O jogo original de David Crane
(sim, o mesmo criador de Pitfall!) tinha 16 variações que transformavam um conceito simples numa
experiência surpreendentemente profunda. A vibe de "duelo ao meio-dia" é irresistível e
perfeita para o contexto de chat — é literalmente um "1v1 me bro" do Velho Oeste.

## Original Mechanics

### Core Loop
1. Dois pistoleiros se posicionam em lados opostos da tela
2. Um obstáculo (cacto, muro, diligência) fica no meio
3. Jogadores se movem verticalmente e atiram horizontalmente
4. Tiros podem ser bloqueados pelo obstáculo ou ricochetearem
5. Acertar o oponente = 1 ponto
6. Primeiro a 10 pontos vence

### Movimento do Pistoleiro
- Movimento vertical (cima/baixo) no original
- Algumas variações permitiam movimento horizontal limitado
- Cada pistoleiro fica "preso" ao seu lado da tela
- Velocidade constante, sem inércia

### Tiro
- Um tiro na tela por jogador de cada vez
- Tiro viaja horizontalmente (esquerda→direita ou direita→esquerda)
- Velocidade do tiro é moderada (dá pra ver e tentar desviar)
- Tiro desaparece ao atingir a borda oposta, o obstáculo ou o oponente

### Obstáculos (centro da tela)
- **Cacto**: obstáculo fixo, bloqueia tiros
- **Muro**: obstáculo fixo maior, mais cobertura
- **Diligência (stagecoach)**: obstáculo que se MOVE verticalmente
- Obstáculos bloqueiam tiros mas NÃO bloqueiam movimento

### Variações do Original (16 modos)
Agrupadas em 2 categorias: Gunslinger (2P) e Target Shoot (1P)
Para 2 jogadores, as variações combinam:
- Obstáculo: cacto / muro / diligência / nenhum
- Tiros: retos / ricochete (bouncing bullets)
- Movimento: fixo horizontal / livre
- Tiros guiados: não / sim (tiro acompanha movimento vertical)

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 4       OUTLAW        P2: 6             │
│┌────────────────────────────────────────────┐│
││                                            ││
││   🤠                                  🤠   ││
││   ╽           ┌──┐                    ╽    ││
││   │ ──•       │▓▓│           •──      │    ││
││   ╿           │▓▓│                    ╿    ││
││               │▓▓│                         ││
││               └──┘                         ││
││                                            ││
│└────────────────────────────────────────────┘│
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘
```

Legenda:
- 🤠 = pistoleiros (sprites laterais estilizados)
- • = projéteis em voo
- ▓▓ = obstáculo central (cacto/muro/diligência)
- ╽│╿ = pistoleiro com arma

### Game Modes (selectable in lobby)

1. **Quick Draw** (padrão)
   - Obstáculo: cacto fixo no centro
   - Tiros: retos
   - Movimento: vertical apenas
   - O modo clássico e puro

2. **Ricochet Alley**
   - Obstáculo: muro largo no centro
   - Tiros: ricocheteiam 1x nas paredes superior/inferior
   - Movimento: vertical apenas
   - Tiros indiretos criam ângulos criativos

3. **Stagecoach Chaos**
   - Obstáculo: diligência que se move verticalmente (ida e volta)
   - Tiros: retos
   - Movimento: vertical apenas
   - Timing é tudo — atirar entre as passagens da diligência

4. **No Man's Land**
   - Obstáculo: nenhum
   - Tiros: retos
   - Movimento: vertical + horizontal limitado (cada jogador pode avançar até 30% da tela)
   - Duelo puro — sem esconderijo, pura habilidade

### Pistoleiro (sprite lateral)

```
Vista lateral do pistoleiro:

     ╭─╮
     │☻│     ← cabeça com chapéu
    ╭┴─┴╮
    │   │──╸  ← braço com revólver
    ╰┬─┬╯
     │ │     ← pernas
     ╵ ╵

Atirando:

     ╭─╮
     │☻│
    ╭┴─┴╮
    │   │──── •  ← tiro saindo
    ╰┬─┬╯
     │ │
     ╵ ╵
```

- Tamanho: ~16x24 pixels equivalente
- Player 1 (esquerda): aponta pra direita, cor verde
- Player 2 (direita): aponta pra esquerda, cor ciano
- Animação: idle (parado) / walking (pernas alternando) / shooting (recuo do braço) / hit (flash + tombo)

### Controls
- **Up / Down arrows** — mover pistoleiro verticalmente
- **Left / Right arrows** — mover horizontalmente (modo No Man's Land)
- **Space** — atirar
- **WASD + Shift** — alternativo

### Mecânica de Tiro Detalhada

#### Tiro Reto
- Projétil viaja horizontalmente na altura da arma do pistoleiro
- Velocidade: moderada (projétil leva ~0.8s pra cruzar a tela)
- O jogador pode VER o tiro chegando e tentar desviar (mover verticalmente)
- Um tiro na tela por vez — precisa esperar o tiro anterior resolver

#### Tiro Ricochete
- Projétil viaja na diagonal (ângulo de ~30° para cima ou para baixo)
- Ao atingir parede superior ou inferior, ricocheteiam na direção oposta
- Máximo de 1 ricochete
- Cria ângulos de ataque imprevisíveis

#### Interação com Obstáculo
- Tiros retos são bloqueados pelo obstáculo (desaparecem)
- Tiros ricochete podem contornar o obstáculo pelo ângulo
- No modo Stagecoach: timing importa — janela de tiro entre passagens

### Obstáculo Central (detalhado)

#### Cacto (Quick Draw)
- Fixo no centro vertical e horizontal da tela
- Altura: ~40% da arena
- Largura: estreita (~10% da arena)
- Bloqueia tiros que o atingem
- Visual: pixel art de cacto verde com braços

#### Muro (Ricochet Alley)
- Fixo no centro horizontal
- Altura: ~60% da arena (mais alto que o cacto)
- Largura: mais larga (~15% da arena)
- Força o uso de tiros ricochete pra atingir o oponente
- Visual: muro de adobe/madeira estilizado

#### Diligência (Stagecoach Chaos)
- Move-se verticalmente no centro da tela (ida e volta)
- Velocidade: constante, moderada
- Altura: ~30% da arena
- Largura: ~20% da arena
- Bloqueia tiros como os outros obstáculos
- Visual: diligência pixel art com cavalos (animada)

### Game State (synced via DataChannel)
- Gunslinger 1: position (x, y), facing, shoot state
- Gunslinger 2: position (x, y), facing, shoot state
- Bullet 1: position (x, y), velocity (vx, vy), active flag
- Bullet 2: position (x, y), velocity (vx, vy), active flag
- Obstacle: type, position (y para stagecoach), direction
- Scores + game phase
- Game mode selecionado

### Authority Model
- **Host** é autoritativo para colisão de tiros (hit detection) e pontuação
- Cada jogador envia: posição vertical, eventos de tiro
- Host simula trajetória dos tiros e colisões
- Host broadcast: posições, bullets, obstacle state, scores
- Guest renderiza com interpolação

### Hit e Respawn
- Tiro acerta oponente = 1 ponto pro atirador
- Animação de hit: pistoleiro tomba pra trás, flash vermelho, chapéu voa
- Breve pausa (~1.5s) após cada hit
- Ambos retornam a posições iniciais (extremos da tela)
- Tiros em voo desaparecem no reset

### Scoring
- Cada hit = 1 ponto
- Primeiro a 10 pontos vence
- Sem timer fixo (jogo acaba por pontuação)
- Best of 3 matches
- Placar visível no topo o tempo todo

### Visual Style (Retro CRT)

- Background: degradê de deserto (laranja escuro → marrom, tons terrosos)
- Chão: linha de areia/terra na base
- Céu: tons de azul-escuro/roxo (vibe crepúsculo)
- Pistoleiros: sprites laterais detalhados com chapéu de cowboy
- Player 1: tons de verde (bandana verde)
- Player 2: tons de ciano (bandana azul)
- Projéteis: pontos brancos brilhantes com trail curto
- Cacto: verde com sombra
- Muro: marrom/bege com textura
- Diligência: marrom com rodas animadas
- Hit: flash vermelho + chapéu voando + estrelas
- CRT scanlines + glow consistentes

### Sound Effects
- Tiro: bang clássico de revólver (curto, seco)
- Projétil viajando: whoosh suave
- Hit no obstáculo: thud/clunk
- Hit no oponente: ricochet metálico + "ugh" estilizado
- Ricochete na parede: ping metálico agudo
- Chapéu voando: whoosh
- Round start: sino de duelo (como sino de igreja do Velho Oeste)
- Vitória: harmônica western + tiro pro alto
- Diligência: som de cavalos e rodas (loop, modo Stagecoach)

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low | Projéteis lineares, ricochete simples (reflexão Y) |
| Networking | Low | 2 posições + 2 bullets + obstacle pos |
| Rendering | Medium | Sprites laterais detalhados, obstáculo animado, cenário western |
| Input | Low | Vertical movement + fire |
| Game logic | Medium | 4 modos de jogo, obstáculo móvel, ricochete |
| **Overall** | **Low-Medium** | Mecânica simples, variedade vem dos modos |

## Fun Factor

- "Duelo ao meio-dia" é um conceito universalmente entendido e empolgante
- Tentar desviar de um tiro que você VÊ chegando = adrenalina pura
- Ricochete cria momentos "calculei o ângulo perfeito!" extremamente satisfatórios
- Diligência addiciona caos controlado — timing de tiro é tenso
- Modo No Man's Land: avançar pra perto é corajoso mas letal
- Curva de aprendizado zero: todo mundo sabe atirar e desviar
- 4 modos de jogo mantêm o jogo fresco por muito mais tempo
- Rivalidade natural: "duelo" é a metáfora perfeita pra 1v1 no chat
