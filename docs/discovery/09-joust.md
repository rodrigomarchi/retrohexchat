# Game Discovery: Joust

## Identity

| Field | Value |
|-------|-------|
| **Name** | Joust |
| **Original** | Williams Electronics, 1982 (arcade) / Atari 2600 port, 1983 |
| **Genre** | Platformer / Action |
| **Players** | 2 (simultaneous, cooperative OR competitive) |
| **Our ID** | `hex_joust` |

## Why This Game

Joust é um dos jogos de arcade mais icônicos da era dourada. Cavaleiros montados em avestruzes
voadoras (sim, avestruzes!) batalham em plataformas flutuantes usando uma única mecânica genial:
quem está MAIS ALTO no momento da colisão vence. Não tem tiro, não tem especial — é pura
física de "flap" (bater as asas) combinada com posicionamento vertical. O multiplayer é
brilhante porque pode ser cooperativo (enfrentar waves de inimigos juntos) ou sabotável
(trair o parceiro pra roubar pontos). Essa dualidade cooperação/traição é PERFEITA para
dinâmicas de chat.

## Original Mechanics

### Core Loop
1. Cavaleiros montados em aves voadoras em uma tela com plataformas
2. Apertar botão = flap (bater asas) = ganhar altitude
3. Gravidade puxa o cavaleiro pra baixo constantemente
4. Colisão entre cavaleiros: quem está MAIS ALTO vence
5. Cavaleiro derrotado vira um ovo que pode ser coletado (pontos)
6. Ovos não coletados chocam em novos inimigos
7. Waves de inimigos progressivamente mais difíceis

### Física de Voo (Flap)
- Cada "flap" dá um impulso vertical pra cima
- Entre flaps, gravidade puxa pra baixo
- Resultado: voo ondulante (sobe-desce ritmado)
- Movimento horizontal: joystick esquerda/direita
- Velocidade horizontal é constante, direção controlada pelo jogador
- A tela "wrapa" horizontalmente (sair pela esquerda = entrar pela direita)

### Colisão entre Cavaleiros (regra central)
- Quando dois cavaleiros colidem, ALTURA determina o vencedor
- Cavaleiro mais alto no momento do contato = VENCE
- Cavaleiro mais baixo = perde, vira ovo
- Se mesma altura: ambos ricocheteiam (bounce), sem morte
- Altura é medida pela posição Y do cavaleiro (parte inferior)

### Plataformas
- Plataformas flutuantes estáticas em vários níveis
- Cavaleiros podem pousar e andar nas plataformas
- Plataformas bloqueiam movimento (não dá pra atravessar por baixo)
- Uma plataforma no topo da tela (teto)
- Lava/chão na base (tocar = morte instantânea)

### Inimigos (no arcade original)
- Buzzards: inimigos básicos montados em buzzards (abutres)
- Shadow Lords: versão mais rápida e agressiva
- Pterodactyls: invencíveis, aparecem quando o round demora demais
- Inimigos seguem padrões de IA simples: voo errático + perseguição leve

## Our Adaptation (2-Player WebRTC)

### Modo de Jogo: Competitive Joust

Para o RetroHexChat, focamos no **modo competitivo direto** (sem waves de inimigos AI).
Dois cavaleiros, plataformas, e a mecânica de altura. Simples e puro.

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 4       JOUST          P2: 3            │
│┌────────────────────────────────────────────┐│
││════════════════════════════════════════════ ││
││                                            ││
││     ░░░░░░░░░░░                            ││
││                     ☻/                     ││
││              ░░░░░░░░░░░░░                 ││
││                                            ││
││  \☻                                        ││
││     ░░░░░░░░░░░     ░░░░░░░░░░░           ││
││                                            ││
││                                            ││
││▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
│└────────────────────────────────────────────┘│
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘
```

Legenda:
- ═══ = plataforma do teto
- ░░░ = plataformas flutuantes (vários níveis)
- ▓▓▓ = lava/chão (zona de morte)
- ☻/ e \☻ = cavaleiros montados em aves (direção indicada pela posição da ave)

### Arena Layout (plataformas)

```
Layout fixo (simétrico):

═══════════════════════════════════════════

    ░░░░░░░░░░░              ░░░░░░░░░░░

          ░░░░░░░░░░░░░░░░

  ░░░░░░░░░░░              ░░░░░░░░░░░░

        ░░░░░░░░░░░    ░░░░░░░░░░░

▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
```

- 5-7 plataformas em disposição simétrica
- Plataforma de teto: cobre toda a largura
- Lava na base: zona de morte em toda a largura
- Wrap horizontal: sair pela esquerda = entrar pela direita
- Layout é fixo (não muda entre rounds) — foco na skill

### Cavaleiro (sprite)

```
Em voo (flapping):          Pousado:            Ovo:
     🦅
    ╭──╮                    ╭──╮                 ╭─╮
    │♞│  ← cavaleiro       │♞│                  │◯│
    │🦅│ ← ave              ╰──╯                 ╰─╯
    ╰╯╰╯   asas batendo     ─── plataforma
```

- Cavaleiro: sprite ~12x16 px
- Ave: corpo arredondado com asas que animam no flap
- Lança do cavaleiro: visual sutil indicando direção
- Player 1: verde (cavaleiro + ave verde)
- Player 2: ciano (cavaleiro + ave azul)
- Asas animam: abertas ↔ fechadas no ritmo dos flaps
- Ovo: sprite pequeno (~6x6 px), branco, pulsando suavemente

### Controls
- **Left / Right arrows** — movimento horizontal
- **Space** — flap (bater asas, ganhar altitude)
- **A / D** — movimento horizontal alternativo
- **W** — flap alternativo

Nota: NÃO há botão de ataque. A única "arma" é a posição vertical.

### Mecânica de Flap (detalhe)

#### Física
- Gravidade constante puxa pra baixo: ~400 px/s²
- Cada flap: impulso vertical de ~-200 px/s (pra cima)
- Flap rate máximo: ~5 flaps/segundo
- Velocidade horizontal: constante ~150 px/s (esq/dir)
- Sem fricção horizontal no ar
- No chão/plataforma: para imediatamente (sem slide)
- Velocidade terminal: ~300 px/s (pra baixo)

#### Resultado Perceptível
- Tapping rápido: voo sustentado com leve ondulação
- Tapping lento: arcos grandes (sobe alto, cai muito)
- Sem tap: queda livre (gravidade total)
- O skill gap está no controle preciso de altura

### Colisão Cavaleiro vs Cavaleiro

#### Regra de Altura
- Comparar posição Y dos dois cavaleiros no frame de colisão
- Y menor (mais alto na tela) = VENCEDOR
- Y maior (mais baixo) = PERDEDOR → vira ovo
- Diferença de Y < threshold (3px): BOUNCE (empate, ambos ricocheteiam)

#### Bounce (empate)
- Ambos cavaleiros são empurrados em direções opostas
- Impulso horizontal + pequeno impulso vertical
- Nenhum perde vida
- Som de "clang" metálico

#### Kill
- Perdedor: sprite muda pra "caindo", cavaleiro se separa da ave
- Ovo aparece onde o perdedor estava
- Vencedor ganha 1 ponto
- Breve invincibilidade pro vencedor (~0.5s)

### Ovos
- Cavaleiro derrotado deixa um ovo na posição onde caiu
- Ovo cai com gravidade e pousa na plataforma/lava abaixo
- Se cai na lava: ovo é destruído (ponto perdido)
- Se pousa em plataforma: ovo fica lá por 5 segundos
- Se coletado (tocar): +1 ponto bonus pro coletor
- Se não coletado em 5s: ovo choca e inimigo NPC renasce (simples AI)
- Inimigo NPC persegue ambos jogadores (ameaça compartilhada)
- Isso incentiva coletar ovos rápido!

### Lava (zona de morte)
- Faixa na base da tela
- Tocar a lava = morte instantânea (perder 1 vida)
- Respawn na plataforma mais alta após 1.5s
- Lava tem animação de borbulhas (visual)
- Ocasionalmente (a cada 30s), mão de lava sobe brevemente tentando pegar quem voa baixo
  (visual threat, hitbox pequena)

### Wrap Horizontal
- Sair pela borda esquerda = entrar pela borda direita (e vice-versa)
- Funciona pra cavaleiros, ovos e NPCs
- Tiros/lanças não existem, então sem edge case

### Scoring e Rounds
- Cada kill = 1 ponto (ao vencedor da colisão)
- Coletar ovo = 1 ponto bonus
- Cair na lava = -1 ponto (penalidade, mínimo 0)
- Primeiro a 10 pontos vence o round
- Best of 3 rounds
- Entre rounds: tela de placar (3s), plataformas e posições resetam

### Spawn de NPCs (enemigos)
- Ovos não coletados em 5s viram NPCs
- NPCs são versões simples de cavaleiros com AI básica:
  - Voam erraticamente
  - Perseguem o jogador mais próximo
  - Usam a mesma regra de altura pra colisão
- NPCs derrotados também viram ovos
- Máximo de 3 NPCs simultâneos (ovos além disso desaparecem)
- NPCs adicionam caos e ameaça compartilhada

### Game State (synced via DataChannel)
- Knight 1: position (x, y), velocity (vx, vy), facing, flap state, alive flag
- Knight 2: position (x, y), velocity (vx, vy), facing, flap state, alive flag
- Eggs: array of {position (x, y), timer, state (falling/resting/hatching)}
- NPCs: array of {position (x, y), velocity, facing, alive}
- Platform layout (static, shared at game start)
- Scores + round + game phase
- Lava hand timer/position

### Authority Model
- **Host** é autoritativo para: colisões, ovos, NPCs, lava
- Cada jogador envia: posição, velocidade, eventos de flap
- Host resolve colisões (quem está mais alto)
- Host simula NPCs e ovos
- Host broadcast: full state
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Background: preto/azul muito escuro (caverna)
- Plataformas: pedra/rocha cinza com borda iluminada
- Teto: pedra contínua
- Lava: vermelho/laranja com animação de borbulhas e brilho
- Cavaleiro P1: verde brilhante (cavaleiro + ave)
- Cavaleiro P2: ciano brilhante (cavaleiro + ave)
- Asas: animação de 3 frames (fechadas → meio → abertas)
- Ovos: brancos, pulsando suavemente
- NPCs: vermelho escuro (cavaleiros inimigos)
- Kill effect: explosão de partículas + penas
- Bounce effect: faíscas no ponto de colisão
- Mão da lava: vermelho brilhante, animação de emergir
- CRT scanlines + glow

### Sound Effects
- Flap: som de asas batendo (whoosh rápido, varia com frequência de flap)
- Pouso em plataforma: thud suave
- Colisão kill: crash + squawk da ave
- Colisão bounce: clang metálico (lanças se chocando)
- Ovo drop: plop suave
- Ovo coletado: pling satisfatório
- Ovo chocando: crack + screech
- Lava morte: sizzle + splash
- Mão da lava: rumble grave
- NPC spawn: screech distante
- Round start: trumpet medieval
- Vitória: fanfarra medieval

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Medium | Flap gravity system, plataforma collisions, wrap |
| Networking | Medium | 2 knights + NPCs + eggs, physics-heavy state |
| Rendering | Medium | Sprites animados (asas), plataformas, lava, partículas |
| Input | Low | Horizontal movement + flap (2 inputs) |
| Game logic | Medium-High | Altura resolution, ovos→NPCs, lava hand, scoring |
| **Overall** | **Medium** | Physics-driven gameplay requer tuning fino |

## Fun Factor

- Mecânica de "quem está mais alto vence" é genial na simplicidade
- Flap physics cria skill ceiling absurdo — dominar o voo leva tempo
- Momentos de "quase empate" (bounce) são tensos e hilários
- Ovos chocando em NPCs adiciona urgência e caos controlado
- Mão da lava é um jump scare constante pra quem voa baixo
- Wrap horizontal permite perseguições épicas pela tela inteira
- O som das asas batendo é hipnótico e satisfatório
- Cooperação forçada contra NPCs misturada com competição por pontos
- "Trair" o parceiro (empurrá-lo na lava enquanto foge de NPC) = momentos memoráveis
- Estética medieval + aves voadoras = visual único entre os jogos do catálogo
