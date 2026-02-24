# Game Discovery: Dodge 'Em

## Identity

| Field | Value |
|-------|-------|
| **Name** | Dodge 'Em |
| **Original** | Atari, 1980 (programado por Carla Meninsky) |
| **Genre** | Chase / Collect |
| **Players** | 2 (simultaneous, asymmetric versus) |
| **Our ID** | `hex_dodge` |

## Why This Game

Dodge 'Em é Pac-Man meets demolition derby — e é ASSIMÉTRICO. Um jogador coleta dots enquanto
o outro tenta causar uma colisão frontal. Os carros só andam em uma direção (anti-horário) em
pistas concêntricas, e só podem trocar de faixa nos cruzamentos. Essa restrição de movimento
cria uma tensão incrível: você VÊ o perseguidor vindo na sua direção e precisa trocar de faixa
no momento exato. Depois de cada crash, os papéis SE INVERTEM. É gato-e-rato com carros,
onde cada round você é ora o gato, ora o rato. Criado por Carla Meninsky, uma das poucas
mulheres programadoras da era Atari, o jogo é considerado superior ao original de arcade
(Head On, da Sega).

## Original Mechanics

### Core Loop
1. Dois carros em pistas concêntricas (4 anéis)
2. Ambos andam APENAS no sentido anti-horário (não podem frear nem dar ré)
3. **Carro Coletor**: coleta dots espalhados pelas pistas
4. **Carro Perseguidor**: tenta colidir de frente com o coletor
5. Podem trocar de faixa nos 4 cruzamentos (topo, base, esquerda, direita)
6. Colisão = round termina, papéis se invertem
7. Coletar todos os dots = round termina, coletor ganha pontos

### Pistas Concêntricas
- 4 anéis concêntricos (pistas circulares)
- Cada anel é uma "faixa" de tráfego
- Todos os carros se movem no sentido anti-horário
- 4 cruzamentos nos pontos cardeais (N, S, E, W) permitem trocar de faixa
- Nos cruzamentos: mover o joystick pra dentro (centro) ou pra fora troca a faixa

### Carro Coletor
- Começa na faixa externa
- Move-se automaticamente no sentido anti-horário (não para)
- Botão de ação: turbo (velocidade 2x)
- Dots estão espalhados pelas 4 faixas
- Coletar dot = pontos
- Coletar TODOS os dots = bônus, novo set de dots aparece

### Carro Perseguidor
- Começa na faixa interna, na direção OPOSTA do coletor
- Também se move automaticamente
- Mesma mecânica de troca de faixa nos cruzamentos
- Botão de ação: turbo (velocidade 2x)
- Objetivo: posicionar-se na mesma faixa E cruzar de frente com o coletor
- Qualquer toque = colisão fatal

### Colisão
- Carros na mesma faixa se movendo em direção um ao outro = CRASH
- Mesmo um "raspão" conta como colisão
- Após colisão: papéis se invertem (coletor vira perseguidor e vice-versa)
- Dots remanescentes ficam onde estão

### Turbo
- Cada jogador pode ativar turbo (2x velocidade) segurando o botão
- Turbo é recurso chave: coletor usa pra fugir, perseguidor usa pra alcançar
- Ambos podem usar turbo simultaneamente

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 120     DODGE 'EM      P2: 85   Rd: 3   │
│┌────────────────────────────────────────────┐│
││                                            ││
││        ╔══════════════════╗                ││
││        ║  ╔════════════╗  ║                ││
││        ║  ║  ╔══════╗  ║  ║                ││
││        ║  ║  ║  ╔══╗║  ║  ║                ││
││   ● ●──╫──╫──╫──╫  ╫╫──╫──╫── ● ●         ││
││        ║  ║  ║  ╚══╝║  ║  ║                ││
││        ║  ║  ╚══════╝  ║  ║                ││
││        ║  ╚════════════╝  ║                ││
││        ╚══════════════════╝                ││
││                                            ││
│└────────────────────────────────────────────┘│
│  ◉ Collector (green)    ◎ Chaser (cyan)      │
└──────────────────────────────────────────────┘
```

Legenda:
- ╔══╗ = 4 pistas concêntricas
- ╫ = cruzamentos (pontos de troca de faixa)
- ● = dots para coletar
- ◉ = carro coletor
- ◎ = carro perseguidor

### Arena Detalhada (vista top-down)

```
            cruzamento N
                │
    ╔═●═●═●═●══╪══●═●═●═●═╗       ← Faixa 4 (externa)
    ║  ╔═●═●═●═╪═●═●═●═╗  ║       ← Faixa 3
    ║  ║  ╔═●═●═╪═●═●╗  ║  ║       ← Faixa 2
    ║  ║  ║  ╔══╪══╗  ║  ║  ║       ← Faixa 1 (interna)
────╫──╫──╫──╫──┼──╫──╫──╫──╫────  cruzamentos W ←→ E
    ║  ║  ║  ╚══╪══╝  ║  ║  ║
    ║  ║  ╚═●═●═╪═●═●╝  ║  ║
    ║  ╚═●═●═●═╪═●═●═●═╝  ║
    ╚═●═●═●═●══╪══●═●═●═●═╝
                │
            cruzamento S
```

- 4 faixas concêntricas retangulares (não circulares — quadradas com cantos arredondados)
- 4 cruzamentos nos pontos cardeais
- Dots distribuídos uniformemente pelas 4 faixas (~40 dots total)
- Ambos carros são visíveis em tempo real

### Carros (sprites top-down)

```
Carro em movimento (anti-horário):

  ┌──┐
  │→ │    ← direção do movimento
  └──┘
  ~8x6 px

Com turbo ativado:

  ┌──┐
  │→ │💨   ← rastro de velocidade
  └──┘
```

- Carro Coletor (papel atual): corpo colorido + brilho dourado
- Carro Perseguidor (papel atual): corpo colorido + brilho vermelho
- Player 1: verde (quando coletor: verde+dourado, quando perseguidor: verde+vermelho)
- Player 2: ciano (quando coletor: ciano+dourado, quando perseguidor: ciano+vermelho)
- Turbo: rastro de velocidade atrás do carro + glow intensificado
- Crash: explosão de partículas + ambos carros piscando

### Controls
- **Up arrow** — trocar pra faixa INTERNA (no cruzamento)
- **Down arrow** — trocar pra faixa EXTERNA (no cruzamento)
- **Space** — turbo (2x velocidade enquanto segura)
- **W/S** — trocar faixa alternativo
- **Shift** — turbo alternativo

Nota: NÃO há controle de direção — carros se movem automaticamente no sentido anti-horário.
O skill está em QUANDO trocar de faixa e QUANDO usar turbo.

### Mecânica de Faixas e Cruzamentos

#### Movimento Automático
- Ambos carros se movem constantemente no sentido anti-horário
- Velocidade base: constante (leva ~3s pra completar um loop na faixa interna, ~5s na externa)
- Faixas internas são menores = loops mais rápidos
- Faixas externas são maiores = mais dots, mas loops mais lentos

#### Troca de Faixa
- Só é possível nos 4 cruzamentos (topo, base, esquerda, direita)
- Ao passar por um cruzamento: apertar cima = faixa interna, baixo = faixa externa
- Pode pular 1 ou 2 faixas de uma vez (se segurar a direção)
- Se não apertar nada: continua na mesma faixa
- A janela de troca é curta (~300ms ao passar pelo cruzamento)
- Trocar de faixa é a ÚNICA forma de movimento vertical

#### Encontro Frontal
- Se ambos carros estão na mesma faixa, vão se encontrar de frente
- Colisão é inevitável a menos que um troque de faixa antes do encontro
- Proximidade crescente = tensão crescente (SOM de warning)
- "Raspão" (passar muito perto): quase-colisão, som de screech, sem pontos

### Dots e Scoring

#### Dots
- ~40 dots distribuídos pelas 4 faixas
- Dots são fixos (não se movem)
- Coletor passa por cima = dot coletado + 2 pontos
- Perseguidor NÃO coleta dots (passa por cima sem efeito)
- Visual: dots brilhantes pulsando suavemente

#### Sets de Dots
- Após coletar todos os dots de um set: +20 pontos bônus
- Novo set de dots aparece (até 5 sets por turno)
- 5 sets completos = turno do coletor termina com bônus máximo

#### Scoring
- Dot coletado: 2 pontos (pro coletor)
- Set completo (todos os dots): +20 bônus
- Crash: 0 pontos (mas papéis invertem)
- Round end (5 sets ou crash): próximo round começa com papéis invertidos
- Partida: best of 6 rounds (3 como coletor, 3 como perseguidor)
- Vencedor: maior pontuação total

### Inversão de Papéis (mecânica central)
- Após cada crash OU set completo: papéis se invertem
- Quem era coletor vira perseguidor e vice-versa
- Transição visual: carros piscam, cores de papel mudam
- Dots restantes permanecem onde estão (se foi crash)
- Se foi set completo: novo set de dots aparece
- Ambos voltam a posições iniciais (opostas na arena)

### Game Modes (selectable in lobby)

1. **Classic** (padrão)
   - 4 faixas, 1 perseguidor
   - Velocidade base normal
   - Best of 6 rounds

2. **Double Trouble**
   - 4 faixas, perseguidor controla 2 carros simultaneamente
   - O segundo carro espelha os movimentos do primeiro (faixa oposta)
   - Muito mais difícil de esquivar

3. **Speed Demon**
   - Velocidade base 1.5x
   - Turbo = 3x velocidade
   - Rounds frenéticos e curtos

### Game State (synced via DataChannel)
- Car 1: lane (1-4), position along lane (angle/progress), role (collector/chaser), turbo flag
- Car 2: lane (1-4), position along lane, role, turbo flag
- Dots: bitmask of collected dots per lane
- Scores + round number + sets completed
- Game phase: `waiting` → `countdown` → `playing` → `crash`/`set_complete` → `role_swap` → `playing` → ... → `finished`

### Authority Model
- **Host** é autoritativo para: colisão, dot collection, role swaps, scoring
- Cada jogador envia: lane switch events, turbo state
- Host simula posições dos carros (determinísticas baseadas em velocidade e faixa)
- Host broadcast: car positions, dots state, scores, roles
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Background: preto/azul muito escuro
- Faixas: linhas brilhantes formando retângulos concêntricos
- Faixa 1 (interna): cor mais escura
- Faixa 4 (externa): cor mais clara
- Cruzamentos: pontos iluminados nos pontos cardeais
- Dots: pontos brancos/amarelos pulsando
- Carro coletor: brilho dourado + trail suave
- Carro perseguidor: brilho vermelho + trail agressivo
- Turbo: rastro mais longo + partículas de velocidade
- Crash: explosão radial + screen shake
- Set completo: todos os dots fazem "pop" sequencial + flash da arena
- Role swap: animação de transição (cores piscam e trocam)
- CRT scanlines + glow

### Sound Effects
- Motor: hum constante (pitch varia com velocidade)
- Turbo: aceleração rugindo
- Dot coletado: blip agudo satisfatório (pitch sobe com dots consecutivos)
- Troca de faixa: click mecânico
- Carros se aproximando: warning crescente (pitch sobe conforme distância diminui)
- Raspão (quase-colisão): screech de pneus
- Crash: BOOM + metal amassando
- Set completo: cascata de blips + fanfarra curta
- Role swap: whoosh + "ding" duplo (papéis trocando)
- Round start: semáforo (3 beeps + GO)
- Vitória: fanfarra de corrida + checkered flag sound

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low | Movimento automático em trilhos, sem física livre |
| Networking | Low | 2 posições em faixas + dot bitmask |
| Rendering | Medium | Pistas concêntricas, carros animados, dots, partículas |
| Input | Low | Troca de faixa (2 botões) + turbo (1 botão) |
| Game logic | Medium | Role swap, dot sets, colisão em faixas, 3 modos |
| **Overall** | **Low-Medium** | Geometria das pistas é o desafio visual principal |

## Fun Factor

- Assimetria coletor/perseguidor cria duas experiências totalmente diferentes
- Inversão de papéis mantém o jogo justo e fresco
- Ver o perseguidor se aproximando na mesma faixa = ADRENALINA PURA
- Trocar de faixa no último segundo = "ESCAPEI POR UM FIO!"
- Turbo cria decisões: usar agora pra fugir ou guardar pra depois?
- Dots dão satisfação progressiva (coletar set completo é lindo)
- Crashes são espetaculares e satisfatórios (mesmo quando você perde)
- 3 controles apenas (faixa interna, faixa externa, turbo) = acessível
- O conceito de "carros que não param e só andam em uma direção" é genialmente restritivo
- Mecânica totalmente única no catálogo — nenhum outro jogo tem nada parecido
