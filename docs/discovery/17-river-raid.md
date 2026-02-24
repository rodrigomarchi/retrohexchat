# Game Discovery: River Raid

## Identity

| Field | Value |
|-------|-------|
| **Name** | River Raid |
| **Original** | Activision, 1982 (criado por Carol Shaw) |
| **Genre** | Shoot 'em Up / Vertical Scroller |
| **Players** | 1 (original) → **2 (nossa adaptação)** |
| **Our ID** | `hex_raid` |

## Why This Game

River Raid é o jogo #1 do Atari no Brasil. Não existe brasileiro da geração 80 que não
conheça o som do avião, as pontes, os postos de combustível. Criado por Carol Shaw — a
primeira mulher game designer da história — é uma obra-prima de game design: o rio se
estreita, o combustível diminui, as pontes ficam mais difíceis. Foi TÃO influente que foi
PROIBIDO na Alemanha em 1984 por "glorificar violência" (um avião de 8 pixels!). A nossa
adaptação é a mais ambiciosa: dois pilotos no MESMO rio, competindo por combustível, pontos
e sobrevivência.

## Original Mechanics

### Core Loop
1. Piloto controla um jato voando sobre um rio (scrolling vertical)
2. Destruir inimigos (barcos, helicópteros, jatos) para pontos
3. Gerenciar combustível (barra diminui constantemente)
4. Passar por cima de postos de combustível para reabastecer
5. Destruir pontes para avançar pra próxima seção
6. Rio se estreita progressivamente — menos espaço pra manobrar
7. Colidir com margem, ponte ou inimigo = morte

### Inimigos e Pontuação
- Barcos (tankers): 30 pts — lentos, navegam no rio
- Helicópteros: 60 pts — voam lateralmente, mudam direção
- Jatos inimigos: 100 pts — rápidos, difíceis de acertar
- Pontes: 500 pts — obrigatório destruir pra avançar
- Postos de combustível: 80 pts SE destruir (mas perde o combustível!)

### Combustível
- Barra de combustível no HUD (diminui constantemente)
- Voar por cima de postos = reabastecer (sem parar)
- Atirar no posto = destrói (80 pts mas sem combustível)
- Velocidade maior = gasta mais combustível
- Se acabar = avião cai (vida perdida)

### Velocidade
- Joystick pra cima = acelera (scroll mais rápido)
- Joystick pra baixo = desacelera (mais tempo pra reagir)
- Velocidade afeta combustível e dificuldade de reação

### Tiro
- Um míssil na tela por vez
- Míssil viaja pra cima (direção do scroll)
- Mísseis guiados (switch B no original): curva lateralmente

### Rio e Margens
- Rio é o espaço navegável (água azul)
- Margens são verdes (terra) — colidir = morte
- Rio se estreita em seções avançadas
- Ilhas no meio do rio criam "caminhos" que obrigam escolha

## Our Adaptation: 2-Player River Duel

### Conceito Criativo

**O mesmo rio, duas perspectivas, uma guerra.**

Dois pilotos voam sobre o MESMO rio ao mesmo tempo. Ambos veem os mesmos inimigos, os mesmos
postos de combustível, as mesmas pontes. MAS: cada inimigo destruído por um jogador é ponto
DELE e desaparece pra AMBOS. Postos de combustível são disputados — quem passar primeiro,
abastece. E a mecânica killer: cada jogador pode **lançar minas flutuantes** no rio que o
oponente precisa desviar.

É PvE cooperativo (ambos enfrentam o mesmo rio) com PvP simultâneo (competição por recursos
+ sabotagem direta).

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 2340     RIVER RAID     P2: 1890        │
│┌────────────────────────────────────────────┐│
││▓▓▓▓▓▓▓▓▓▓│                │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓▓▓│   🚁      🚤  │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓▓▓│                │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓│      ⛽           │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓│   🚤       💣    │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓│      ✈️P1        │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓▓▓│       ✈️P2     │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓▓▓│  🚤            │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓▓▓│    ════════    │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││▓▓▓▓▓▓▓▓▓▓│     BRIDGE     │▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
│└────────────────────────────────────────────┘│
│  ⛽ ████████░░░░░    ⛽ ██████░░░░░░░░  Sec:5 │
└──────────────────────────────────────────────┘
```

Legenda:
- ✈️P1/P2 = jatos dos jogadores
- ▓▓ = margens do rio (terra/vegetação)
- 🚤 = barcos inimigos
- 🚁 = helicópteros
- ⛽ = posto de combustível
- 💣 = mina flutuante (lançada por um jogador)
- ════ = ponte (destruir pra avançar)

### Mecânicas Competitivas Novas

#### 1. Kill Stealing (corrida por pontos)
- Cada inimigo é um recurso FINITO — quem destruir primeiro leva os pontos
- Barcos (30 pts), helicópteros (60 pts), jatos (100 pts), pontes (500 pts)
- Se ambos atiram no mesmo inimigo: quem acertou PRIMEIRO leva
- O segundo tiro é desperdiçado
- Cria corrida constante por alvos — especialmente pontes (500 pts!)

#### 2. Combustível Compartilhado (recurso disputado)
- Postos de combustível aparecem no rio normalmente
- Quem voar por cima PRIMEIRO = abastece
- Depois que um jogador usa: posto DESAPARECE (o outro não recebe)
- Se atirar no posto: destrói pra ambos (80 pts mas ninguém abastece)
- Pode ser tático: destruir o posto quando VOCÊ está cheio mas o oponente precisa!
- Decisão agonizante: destruir por 80 pts ou guardar pra reabastecer?

#### 3. Minas Flutuantes (sabotagem direta)
- Cada jogador pode lançar minas no rio (máximo 2 ativas por jogador)
- Mina flutua no rio e desce lentamente com o scroll
- Se o oponente tocar na mina = mesma penalidade que encostar na margem (morte!)
- O lançador é IMUNE às suas próprias minas
- Minas são visíveis mas pequenas — fácil ignorar no calor da ação
- Cooldown de 5 segundos entre lançamentos de mina
- Cor da mina = cor do jogador que lançou

#### 4. Ponte: Corrida pela Destruição
- Pontes valem 500 pts (valor ENORME)
- Ponte precisa de 3 tiros pra ser destruída (não 1 como no original)
- Ambos podem atirar na ponte — cada tiro conta independente de quem atirou
- Quem dá o ÚLTIMO tiro (tiro que destrói) leva os 500 pts
- Cria drama: ambos despejam tiros, quem acerta o último?
- Ponte NÃO destrói = ambos morrem ao colidir (volta ao checkpoint)

#### 5. Progressão Paralela
- Ambos jogadores compartilham o scroll (câmera segue o mais avançado)
- Se um jogador fica muito atrás: é "puxado" pela câmera (não pode ficar parado)
- Se um morre: perde 1 vida, respawn rápido (3 segundos) mas atrás do oponente
- O oponente ganha vantagem de posição (mais perto dos próximos alvos)

### Jatos dos Jogadores (sprites)

```
Jato visto de cima:

    ╱╲
   ╱  ╲
  ╱    ╲      ← asas
  │    │
  │ ▼  │      ← corpo
  ╰────╯
   ╲╱╲╱       ← propulsão

Atirando:
    ╱╲
   ╱  ╲
  ╱    ╲
  │ ●↑ │      ← míssil saindo
  │    │
  ╰────╯
   ╲╱╲╱
```

- Sprite ~10x14 px (vista de cima)
- P1: verde (jato verde, mísseis verdes, minas verdes)
- P2: ciano (jato ciano, mísseis cianos, minas cianas)
- Propulsão: animação de chamas atrás do jato
- Hit: explosão + jato gira e cai

### Inimigos (sprites no rio)

```
Barco:           Helicóptero:       Jato inimigo:
  ╭──╮            ═══╤═══            ╱╲
  │🚤│            ╭─╤╯╭─╮           ╱  ╲
  ╰──╯            ╰─┤ │H│          ╱    ╲
                    ╰─╯            ╰────╯
  ~8px             ~12px            ~10px
```

- Barcos: marrom/cinza, lentos, movem lateralmente no rio
- Helicópteros: cinza, rápidos, mudam de direção
- Jatos: branco, MUITO rápidos, vêm em direção aos jogadores
- Todos são alvos compartilhados (quem acerta primeiro leva)

### Minas Flutuantes (sprite)

```
Mina:
  ╭●╮
  │💣│    ← mina flutuante com espinhos
  ╰●╯
  ~6px
```

- Mina P1: verde com brilho pulsante
- Mina P2: ciano com brilho pulsante
- Flutuam no rio, descem com o scroll
- Pulsam mais rápido quando jogador inimigo se aproxima (warning visual)

### Controls
- **Left / Right arrows** — mover jato lateralmente
- **Up / Down arrows** — acelerar / desacelerar
- **Space** — atirar míssil
- **Shift** — lançar mina flutuante
- **WASD + Q(mina)** — alternativo

### Rio e Progressão

#### Seções do Rio
- Rio é dividido em seções, separadas por pontes
- Cada seção: ~30 segundos de gameplay
- Seção 1-3: rio largo, poucos inimigos, bastante combustível
- Seção 4-6: rio mais estreito, mais inimigos, menos postos
- Seção 7-9: rio com ilhas (caminhos forçados), jatos inimigos
- Seção 10+: rio muito estreito, mínimo de combustível, caos total

#### Ilhas (caminhos divididos)
- A partir da seção 4: ilhas no centro do rio
- Cada jogador escolhe ir pela ESQUERDA ou DIREITA da ilha
- Inimigos e postos podem estar em um caminho mas não no outro
- Cria decisões: ir pelo caminho com posto ou pelo com mais inimigos (pontos)?
- Os caminhos se reencontram após a ilha

### Scoring
- Barco destruído: 30 pts
- Helicóptero: 60 pts
- Jato inimigo: 100 pts
- Posto de combustível destruído: 80 pts
- Ponte destruída (tiro final): 500 pts
- Mina atingiu oponente: 200 pts
- Oponente ficou sem combustível: 150 pts bônus
- Seção completada: 100 pts bônus pra ambos

### Vidas e Game Over
- Cada jogador: 3 vidas
- Morrer: colisão com margem, ponte, inimigo ou mina do oponente
- Respawn: 3 segundos de delay, volta ligeiramente atrás
- Perder todas as vidas: game over pra esse jogador
- O outro continua até também perder ou completar 10 seções
- Vencedor: maior pontuação total
- Se ambos sobrevivem 10 seções: maior score vence

### Game Modes (selectable in lobby)

1. **River Duel** (padrão)
   - 10 seções, ambos no mesmo rio
   - Minas + combustível disputado + kill stealing
   - Full experience

2. **Pacifist Run**
   - Minas DESABILITADAS
   - Sem sabotagem direta — pura corrida por pontos e combustível
   - Foco: eficiência de tiro e gerenciamento de combustível

3. **Blitz**
   - 5 seções, rio já começa estreito
   - Combustível escasso desde o início
   - Minas com cooldown de 3s (mais frequentes)
   - Modo caótico e rápido

### Game State (synced via DataChannel)
- Jet 1: position (x, y), speed, fuel, lives, score, mine cooldown
- Jet 2: position (x, y), speed, fuel, lives, score, mine cooldown
- Enemies: determinístico (seed + section)
- Fuel stations: state (available/used/destroyed)
- Bridges: HP (3 hits), destroyed_by
- Mines: array of {owner, position (x, y), active}
- Section number, scroll position
- Game phase: `waiting` → `countdown` → `flying` → `section_clear` → ... → `finished`

### Authority Model
- **Host** é autoritativo para: colisões, kills, fuel captures, bridge destruction credit, mine hits
- Rio layout é determinístico (seed compartilhado)
- Cada jogador envia: position, speed, fire events, mine events
- Host valida: who hit first, fuel capture priority, mine collisions
- Host broadcast: all positions, enemy states, fuel states, scores
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Vista top-down com scrolling vertical
- Rio: azul escuro (água) com variação de tonalidade
- Margens: verde (vegetação) com detalhes de árvores/rochas pixel art
- Jato P1: verde brilhante com chamas de propulsão laranjas
- Jato P2: ciano brilhante com chamas de propulsão laranjas
- Barcos: marrom/cinza sobre a água
- Helicópteros: cinza com hélice animada
- Jatos inimigos: branco com trail
- Pontes: marrom/cinza, barras horizontais cruzando o rio
- Postos de combustível: verde brilhante com ícone ⛽
- Posto capturado: flash dourado → desaparece
- Posto destruído: explosão → desaparece
- Minas: cor do lançador, pulsando, espinhos visíveis
- Explosões: laranja/amarelo com partículas
- Margens se estreitando: transição visual gradual
- Ilhas: verde com detalhes, dividindo o rio
- CRT scanlines + glow

### Sound Effects
- Motor do jato: hum constante (pitch varia com velocidade)
- Tiro: pew agudo (clássico do River Raid!)
- Inimigo destruído: explosão curta (pitch varia por tipo)
- Ponte recebendo tiro: clang metálico
- Ponte destruída: explosão grande + collapse
- Posto de combustível capturado: glug + pling satisfatório
- Posto destruído: explosão + missed opportunity tone
- Mina lançada: splash (cai na água)
- Mina explodiu (atingiu oponente): BOOM aquático + splash
- Colisão com margem: crash + explosão
- Vida perdida: descending tone clássico
- Respawn: whoosh ascendente
- Seção completa: arpeggio rápido
- Combustível baixo: alarm pulsante
- Kill steal (acertou antes do oponente): blip triplo satisfatório
- Vitória: fanfarra militar + jato passando (flyby)

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low-Medium | Scroll vertical, colisão com margens/inimigos/minas |
| Networking | Medium | 2 jatos + inimigos + minas + fuel stations + bridges |
| Rendering | Medium | Scroll vertical, rio com margens variáveis, ilhas |
| Input | Low | Lateral movement + speed + fire + mine |
| Game logic | Medium-High | Kill priority, fuel disputes, mines, bridge HP, sections |
| **Overall** | **Medium** | Lógica de disputa por recursos é o desafio principal |

## Fun Factor

- Nostalgia MÁXIMA — o som do River Raid vai fazer brasileiro chorar de emoção
- Kill steal é DELICIOSO: acertar o helicóptero que o oponente estava mirando
- Disputar posto de combustível quando ambos estão no vermelho = DRAMA EXISTENCIAL
- Destruir o posto quando você tá cheio e o oponente precisa = jogada DIABÓLICA
- Minas no rio adicionam paranoia constante (aquele ponto pulsando é uma mina?!)
- Ponte de 500 pts com 3 HP: corrida pra dar o tiro final é épica
- Ilhas dividem caminhos: "ele foi pela esquerda, os barcos estão na direita!"
- O rio se estreitando cria tensão crescente natural
- Dois aviões no mesmo rio = caos controlado que o original nunca teve
- Carol Shaw's masterpiece, agora com rivalidade humana. Perfeito.
