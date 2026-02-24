# Game Discovery: Enduro

## Identity

| Field | Value |
|-------|-------|
| **Name** | Enduro |
| **Original** | Activision, 1983 |
| **Genre** | Racing / Endurance |
| **Players** | 1 (original) → **2 (nossa adaptação)** |
| **Our ID** | `hex_enduro` |

## Why This Game

Enduro é O jogo de corrida do Brasil. Pergunte pra qualquer brasileiro que teve Atari nos anos
80 e a resposta é imediata: "Enduro!" O ciclo dia→neve→neblina→noite é inesquecível. A sensação
de ultrapassar 200 carros com faróis piscando na escuridão é visceral. Criado pela Activision
em 1983, é considerado o melhor jogo de corrida do Atari 2600 — e no Brasil, onde o console
durou até 1989, Enduro foi jogado por uma geração inteira. A adaptação pra 2-player transforma
a corrida solitária numa COMPETIÇÃO de resistência onde cada decisão de velocidade e risco
importa.

## Original Mechanics

### Core Loop
1. Jogador pilota um carro numa corrida de resistência (endurance race)
2. Deve ultrapassar um número mínimo de carros por "dia" (200 no dia 1, 300+ depois)
3. Condições mudam ao longo do dia: sol → neve → neblina → noite → amanhecer
4. Se não ultrapassar carros suficientes antes do dia acabar: game over
5. Jogo continua indefinidamente, ficando cada vez mais difícil

### Perspectiva e Visão
- Vista traseira do carro (behind-the-car, pseudo-3D)
- Estrada com 3 faixas, carros vêm "de trás" (aparecem no horizonte e se aproximam)
- Montanhas no horizonte, céu muda de cor com o ciclo dia/noite
- Efeito de velocidade: faixas laterais da estrada "passam" mais rápido

### Controles do Original
- Joystick esquerda/direita: trocar de faixa
- Joystick pra cima: acelerar
- Joystick pra baixo: frear
- Botão: turbo (velocidade máxima)
- Sem colisão fatal — encostar em outro carro te desacelera drasticamente

### Ciclo Dia/Noite (mecânica icônica)
- **Dia (sol)**: visibilidade total, carros coloridos, fácil de ver
- **Neve**: estrada branca, carros derrapam, controle escorregadio
- **Neblina**: visibilidade reduzida, carros aparecem de repente
- **Noite**: tela escura, só vê FARÓIS dos carros (pontos vermelhos)
- **Amanhecer**: céu gradualmente clareia, cores voltam
- O ciclo completo = 1 "dia" de corrida

### Carros Adversários
- Múltiplos carros na pista em todas as faixas
- Velocidades variadas (alguns lentos, outros rápidos)
- Não tentam te bloquear — têm padrão próprio
- Encostar = perda dramática de velocidade (não é game over)
- Ultrapassar = +1 no contador

## Our Adaptation: 2-Player Enduro Duel

### Conceito Criativo

**NÃO é split-screen.** Ambos jogadores correm na MESMA estrada, MESMA pista, ao mesmo tempo.
Você vê o carro do oponente como mais um carro na pista — mas ele é CONTROLADO pelo outro
jogador. Isso transforma Enduro de corrida contra AI em corrida DIRETA.

A adaptação adiciona mecânicas competitivas que mantêm o espírito do original mas criam
rivalidade intensa:

### Modo Principal: "Enduro Duel"

Ambos na mesma estrada. Quem ultrapassa mais carros em um ciclo dia/noite completo vence
o round. MAS: vocês também são obstáculo um pro outro.

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 147/200    ENDURO     P2: 132/200       │
│┌────────────────────────────────────────────┐│
││              ╱  ╲                           ││
││            ╱ ☁☁  ╲         ← horizonte     ││
││         ╱⛰️      ⛰️╲                       ││
││        ╱────────────╲                       ││
││       ╱   🚗  🚙    ╲      ← carros AI    ││
││      ╱  🚗   🚙  🚗  ╲                    ││
││     ╱     ◉      🚗    ╲    ← P1 (verde)  ││
││    ╱   🚗    ◎    🚙    ╲   ← P2 (ciano)  ││
││   ╱  🚗   🚙   🚗  🚙   ╲                ││
││  ╱━━━━━━━━━━━━━━━━━━━━━━━━╲  ← estrada    ││
│└────────────────────────────────────────────┘│
│  ⛽ ████████░░░░  Day 2 — Sunset  ⛽ ██████░░░│
└──────────────────────────────────────────────┘
```

Legenda:
- ◉ = carro P1 (verde)
- ◎ = carro P2 (ciano)
- 🚗🚙 = carros AI (obstáculos)
- ⛰️ = montanhas no horizonte
- ⛽ █████ = barra de combustível de cada jogador
- Estrada com perspectiva pseudo-3D (3 faixas)

### Vista Noturna (a mágica do Enduro)

```
┌──────────────────────────────────────────────┐
│  P1: 267/300    ENDURO     P2: 245/300       │
│┌────────────────────────────────────────────┐│
││                                            ││
││              ★    ★                        ││
││         ★          ★    ★                  ││
││        ╱────────────╲                       ││
││       ╱  🔴  🔴      ╲    ← faróis traseiro││
││      ╱     🔴    🔴    ╲                    ││
││     ╱   🟢    🔴   🔴  ╲   ← P1 = verde   ││
││    ╱  🔴   🔵    🔴     ╲   ← P2 = azul   ││
││   ╱     🔴   🔴    🔴    ╲                 ││
││  ╱━━━━━━━━━━━━━━━━━━━━━━━━╲                ││
│└────────────────────────────────────────────┘│
│  ⛽ ██████░░░░  Night — Fog  ⛽ ████░░░░░░░░░│
└──────────────────────────────────────────────┘
```

- À noite: só vê faróis (pontos de luz)
- Carros AI: faróis vermelhos
- P1: faróis VERDES (identificação mesmo no escuro)
- P2: faróis AZUIS/CIANOS
- Neblina: todos os faróis ficam difusos e menores

### Mecânicas Competitivas Novas

#### 1. Combustível (NÃO existe no original — adição nossa)
- Barra de combustível pra cada jogador
- Combustível diminui conforme acelera (mais rápido = mais gasto)
- Postos de combustível aparecem na pista (faixa central)
- Passar por cima = reabastece
- Se acabar: carro desacelera ao mínimo (não morre, mas perde posições)
- Rivalidade: ambos disputam o mesmo posto de combustível!
- Posto abastece apenas o PRIMEIRO a passar

#### 2. Slipstream (vácuo aerodinâmico)
- Ficar atrás do oponente por 2+ segundos = bônus de velocidade (reboque)
- Permite ultrapassagem surpresa
- O jogador da frente NÃO ganha bônus (desvantagem natural de liderar)
- Visual: linhas de velocidade atrás do carro da frente

#### 3. Bloquear Faixa
- Ambos jogadores ocupam espaço na pista
- Ficar na mesma faixa que o oponente quando ele tenta ultrapassar = bloqueio
- Bloqueio não é fatal — apenas desacelera quem vem atrás
- Cria mente games: bloquear o oponente OU focar em ultrapassar AI?

#### 4. O Oponente como Obstáculo
- Encostar no oponente = ambos desaceleram (como encostar em AI)
- MAS quem estava mais rápido perde MAIS velocidade (penalidade por imprudência)
- Isso cria risco real ao tentar ultrapassar o rival

### Condições Climáticas (detalhado)

#### Dia (Sol Claro)
- Visibilidade: 100%
- Controle: normal
- Carros AI: velocidade normal
- Visual: céu azul, montanhas verdes, estrada cinza
- Duração: ~60 segundos

#### Neve
- Visibilidade: 80%
- Controle: ESCORREGADIO (input delay + drift)
- Estrada: branca com partículas de neve caindo
- Carros AI: mais lentos (mas seu carro também)
- Trocar de faixa demora mais (inércia lateral)
- Visual: tudo branco, flocos caindo, montanhas nevadas
- Duração: ~45 segundos

#### Neblina
- Visibilidade: 40% (carros aparecem MUITO perto)
- Controle: normal
- Perigo: carros AI "surgem do nada" — reflexo é tudo
- Visual: tela esbranquiçada, gradiente de neblina
- Faróis do oponente brilham mais (podem te enganar)
- Duração: ~30 segundos

#### Noite
- Visibilidade: faróis APENAS (pontos de luz no escuro)
- Controle: normal
- Carros AI: só faróis vermelhos visíveis
- Oponente: faróis na cor dele (verde P1, ciano P2)
- Estrada quase invisível — navegar por instinto e faróis
- Visual: preto total com estrelas, só luzes
- Duração: ~45 segundos

#### Amanhecer
- Visibilidade: gradualmente volta (20% → 100%)
- Controle: normal
- Visual: horizonte fica laranja/rosa, silhuetas dos carros aparecem
- Momento mais bonito do jogo
- Duração: ~30 segundos

### Dia Completo = 1 Round
- Sol → Neve → Neblina → Noite → Amanhecer = 1 dia (~3.5 minutos)
- Ao fim do dia: comparar ultrapassagens
- Meta: ultrapassar 200 carros no dia 1
- Quem ultrapassou mais: ganha pontos bônus
- Se um jogador NÃO atingir a meta e o outro sim: desvantagem pesada no próximo dia

### Scoring e Rounds
- Cada ultrapassagem de AI = 1 ponto
- Ultrapassar o OPONENTE = 5 pontos (satisfatório!)
- Posto de combustível capturado = 3 pontos
- Best of 3 dias
- Dia 1: meta 200 carros, AI lenta
- Dia 2: meta 250 carros, AI mais rápida
- Dia 3: meta 300 carros, neblina mais densa, noite mais longa
- Vencedor: mais pontos acumulados nos 3 dias

### Controls
- **Left / Right arrows** — trocar de faixa (3 faixas)
- **Up arrow** — acelerar
- **Down arrow** — frear
- **Space** — turbo (boost temporário, gasta combustível extra)
- **WASD + Shift** — alternativo

### Game Modes (selectable in lobby)

1. **Classic Duel** (padrão)
   - 3 dias completos, ciclo dia/noite
   - Combustível + slipstream ativos
   - Meta de ultrapassagens por dia

2. **Night Race**
   - Noite PERMANENTE (sem dia)
   - Só faróis, neblina intermitente
   - 1 round de 3 minutos, quem ultrapassou mais vence
   - Puro instinto e reflexo

3. **Sprint**
   - Apenas sol (sem condições climáticas)
   - 90 segundos, sem meta mínima
   - Foco em ultrapassar AI + bloquear oponente
   - Modo rápido pra partidas de chat

### Game State (synced via DataChannel)
- Car 1: lane (1-3), speed, fuel, overtakes count, boost state
- Car 2: lane (1-3), speed, fuel, overtakes count, boost state
- AI Cars: array of {lane, distance_from_player, speed} — determinístico (seed)
- Fuel stations: positions (determinístico)
- Weather: current condition, transition timer
- Day number, overtake targets, scores
- Game phase: `waiting` → `countdown` → `racing` → `day_end` → `racing` → ... → `finished`

### Authority Model
- **Host** é autoritativo para: AI car positions, colisões, ultrapassagem contagem, fuel stations
- AI traffic é determinístico (seed compartilhado)
- Cada jogador envia: lane, speed input, boost events
- Host valida: colisões (AI e P2P), fuel captures, overtake counts
- Host broadcast: player positions, AI relative positions, weather state, scores
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Perspectiva pseudo-3D (estrada convergindo no horizonte)
- Horizonte: montanhas que mudam de cor com o clima
- Estrada: 3 faixas, linhas laterais passando (efeito velocidade)
- Carro P1: verde brilhante (carroceria verde, faróis verdes à noite)
- Carro P2: ciano brilhante (carroceria ciano, faróis cianos à noite)
- Carros AI: variados (vermelho, amarelo, branco), faróis vermelhos à noite
- Sol: céu azul gradiente, nuvens brancas
- Neve: tela branca, flocos caindo em primeiro plano, estrada branca
- Neblina: gradiente branco que "engole" a distância
- Noite: preto total, estrelas, faróis são os únicos pontos de luz
- Amanhecer: horizonte laranja/rosa, silhuetas emergem
- Postos de combustível: ícone brilhante amarelo na pista
- Slipstream: linhas de velocidade horizontais atrás do carro da frente
- Combustível baixo: barra pisca vermelho
- CRT scanlines + glow intenso (especialmente de noite — faróis brilham)

### Sound Effects
- Motor: hum constante (pitch sobe com velocidade)
- Aceleração: rugido crescente
- Frenagem: screech
- Troca de faixa: swoosh lateral
- Ultrapassagem (AI): blip rápido
- Ultrapassagem (oponente): blip triplo + crowd "ohh!"
- Colisão (AI): bump + desaceleração audível
- Colisão (oponente): bump mais forte + screech duplo
- Slipstream ativado: whoosh crescente (vácuo aerodinâmico)
- Turbo/boost: roar de motor potente
- Posto de combustível capturado: pling satisfatório + glug de combustível
- Transição dia→neve: vento soprando gradualmente
- Transição neve→neblina: silêncio eerie
- Noite chegando: sons ficam abafados, motor ecoa
- Amanhecer: pássaros cantando suavemente
- Meta de ultrapassagens atingida: fanfarra curta
- Dia completo: buzina longa + placar
- Combustível acabando: alarm pulsante
- Vitória: fanfarra de pódio + motor acelerando

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Medium | Pseudo-3D, 3 faixas, velocidade relativa, slipstream |
| Networking | Medium | 2 carros + AI traffic + weather sync + fuel stations |
| Rendering | Medium-High | Pseudo-3D com perspectiva, clima dinâmico, noite com faróis |
| Input | Low | 3 faixas + accel/frear + boost |
| Game logic | Medium | Ultrapassagens, combustível, slipstream, clima, metas |
| **Overall** | **Medium-High** | Rendering pseudo-3D e clima são os maiores desafios |

## Fun Factor

- Nostalgia NUCLEAR pra brasileiros — reconhecimento instantâneo
- Ciclo dia/noite é hipnotizante (a transição pra noite é mágica)
- Corrida na neblina = TENSÃO PURA (carros aparecem do nada)
- Noite com faróis = experiência sensorial única
- Disputar posto de combustível com o oponente = drama real
- Slipstream cria momentos de "ele tá no meu vácuo!" e ultrapassagens épicas
- Bloquear faixa do oponente = satisfação perversa
- Meta de ultrapassagens adiciona pressão constante
- Condições climáticas mudam a dinâmica completamente a cada 30-60 segundos
- Ultrapassar o OPONENTE vale 5x mais = incentivo pra risco
- "Eu tinha 298 de 300 e a noite chegou e perdi tudo" = histórias épicas
- O jogo mais bonito do catálogo (amanhecer depois da noite = cinema)
