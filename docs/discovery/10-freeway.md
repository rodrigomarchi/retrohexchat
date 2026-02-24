# Game Discovery: Freeway

## Identity

| Field | Value |
|-------|-------|
| **Name** | Freeway |
| **Original** | Activision, 1981 (criado por David Crane) |
| **Genre** | Action / Arcade |
| **Players** | 2 (simultaneous, competitive) |
| **Our ID** | `hex_freeway` |

## Why This Game

Freeway é o jogo mais acessível do Atari 2600. Duas galinhas tentando atravessar uma rodovia
de 10 faixas cheia de tráfego em velocidades variadas. Quem atravessa mais vezes em 2 minutos
vence. É "Frogger competitivo" — todo mundo entende em 2 segundos, e a diversão é IMEDIATA.
A beleza está no caos: você VÊ a outra galinha quase chegando do outro lado e se desespera
pra acelerar, toma um carro na cara, e volta pro início. Humor, tensão e rivalidade pura.
David Crane (sim, Pitfall + Outlaw) criou mais uma obra-prima de game design minimalista.

## Original Mechanics

### Core Loop
1. Cada jogador controla uma galinha na base da tela
2. Objetivo: atravessar 10 faixas de tráfego até o outro lado
3. Cada travessia completa = 1 ponto
4. Se atingido por um veículo, galinha é empurrada de volta uma faixa
5. Timer de 2:16 minutos
6. Quem tem mais travessias ao fim do timer vence

### Movimento da Galinha
- Apenas VERTICAL: cima e baixo
- Cima: avançar uma faixa em direção ao objetivo
- Baixo: recuar uma faixa (estratégico para esquivar)
- Sem movimento horizontal — galinha fica na sua "coluna"
- Cada jogador tem sua própria coluna (P1 esquerda, P2 direita)

### Tráfego
- 10 faixas horizontais de veículos
- Cada faixa tem veículos movendo em uma direção (alternando esquerda→direita, direita→esquerda)
- Velocidades variam por faixa:
  - Faixas inferiores (perto do início): tráfego lento
  - Faixas superiores (perto do objetivo): tráfego rápido
  - Progressão de dificuldade natural
- Veículos são espaçados com gaps irregulares
- Veículos "wrappam" (saem de um lado, entram no outro)
- Tipos: carros, caminhões, ônibus (tamanhos diferentes)

### Colisão
- Galinha atingida por veículo = empurrada de volta UMA faixa
- Não há "morte" — galinha nunca morre, apenas recua
- Se atingida na faixa mais baixa: galinha fica na base (não pode recuar mais)
- A galinha NÃO reinicia no começo — apenas recua uma posição

### Variações do Original (8 modos)
- Variam a velocidade do tráfego e o tipo de veículos
- Modos fáceis: tráfego espaçado, velocidade baixa
- Modos difíceis: tráfego denso, velocidade alta
- Modo "Ônibus apenas": ônibus são os maiores veículos, gaps menores

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 5       FREEWAY       P2: 3    1:42     │
│┌────────────────────────────────────────────┐│
││▓▓▓▓▓▓▓▓▓▓▓▓▓▓CHEGADA▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓││
││     🚛→→                 ←←🚌              ││
││  ←←🚗         🐔   🐔        🚗→→         ││
││       🚙→→              🚙→→               ││
││  ←←🚌                          ←←🚛       ││
││        🚗→→         🚗→→                   ││
││  ←←🚛              ←←🚗                   ││
││     🚙→→                    🚙→→           ││
││  ←←🚗                  ←←🚙               ││
││          🚗→→      🚗→→                    ││
││  ←←🚙           ←←🚗                      ││
││▒▒▒▒▒▒▒▒▒▒▒▒▒▒PARTIDA▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒││
│└────────────────────────────────────────────┘│
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘
```

Legenda:
- 🐔 = galinhas (cada uma em sua coluna)
- 🚗🚙🚛🚌 = veículos em várias faixas e direções
- ▓▓ CHEGADA = zona de objetivo (topo)
- ▒▒ PARTIDA = zona de início (base)
- →→ / ←← = direção do tráfego na faixa

### Rodovia (Arena)
- 10 faixas de tráfego horizontais
- Zona de partida na base (safe zone)
- Zona de chegada no topo (safe zone)
- Cada faixa tem uma cor/tom levemente diferente (asfalto alternando claro/escuro)
- Marcações centrais tracejadas entre faixas (estilo rodovia)
- A tela é vertical: base = início, topo = destino

### Galinhas (sprites)

```
Galinha vista de cima (caminhando pra cima):

   ╭╮
  ╭┤├╮
  │  │    ← corpo
  ╰┬┬╯
   ╵╵     ← patinhas

Galinha atingida (empurrada):

   ╭╮
  ╭┤├╮
  │><│    ← expressão de choque
  ╰┬┬╯
   ╵╵     (flash + recua uma faixa)
```

- Sprite pequeno (~8x10 px)
- Player 1 (coluna esquerda): galinha verde
- Player 2 (coluna direita): galinha ciano
- Animação de caminhada: patas alternando
- Animação de hit: flash + expressão cômica + recuo
- Animação de chegada: galinha comemora (pula) + ponto

### Veículos (sprites)

```
Carro (pequeno):     Caminhão (médio):     Ônibus (grande):
  ┌──┐                ┌────┐               ┌──────┐
  │🚗│                │ 🚛 │               │  🚌  │
  └──┘                └────┘               └──────┘
  ~12px               ~20px                ~28px
```

- 3 tipos de veículos com tamanhos diferentes
- Carro: pequeno, pode ser rápido ou lento
- Caminhão: médio, geralmente velocidade média
- Ônibus: grande, gap menor entre veículos
- Cores variadas por veículo (vermelho, azul, amarelo, branco)
- Veículos NÃO colidem entre si (cada faixa é independente)

### Controls
- **Up arrow** — avançar uma faixa (em direção à chegada)
- **Down arrow** — recuar uma faixa (em direção à partida)
- **W / S** — alternativo

Nota: SÓ ISSO. Dois botões. A simplicidade é intencional e genial.

### Mecânica de Faixas (detalhe)

#### Distribuição de Dificuldade
```
Faixa 10 (topo)  : ←← tráfego MUITO rápido, gaps curtos
Faixa 9           : →→ tráfego rápido
Faixa 8           : ←← tráfego rápido, veículos grandes
Faixa 7           : →→ tráfego médio-rápido
Faixa 6           : ←← tráfego médio
Faixa 5           : →→ tráfego médio
Faixa 4           : ←← tráfego médio-lento
Faixa 3           : →→ tráfego lento, gaps grandes
Faixa 2           : ←← tráfego lento
Faixa 1 (base)    : →→ tráfego MUITO lento, gaps enormes
```

- Faixas ímpares: direita→esquerda
- Faixas pares: esquerda→direita
- Progressão natural: começa fácil, fica frenético

#### Geração de Veículos
- Cada faixa tem padrão de spawn: espaçamento base + variação aleatória
- Veículos são contínuos (circulam pela faixa)
- Faixas rápidas: mais veículos, gaps menores
- Faixas lentas: menos veículos, gaps generosos
- O padrão é determinístico (seeded random) — ambos jogadores veem o MESMO tráfego

### Mecânica de Travessia

#### Avançar
- Apertar "cima" move a galinha UMA faixa pra cima
- Movimento é instantâneo (snap to lane), não contínuo
- Há um breve cooldown entre movimentos (~200ms) pra evitar spam
- Na zona de chegada: +1 ponto, galinha teleporta de volta à partida
- Ao retornar, mantém a coluna original

#### Recuar
- Apertar "baixo" move a galinha UMA faixa pra baixo
- Mesmo snap e cooldown
- Na zona de partida: não pode recuar mais (já está no início)
- Recuar é estratégico: evitar um veículo iminente

#### Ser Atingido
- Galinha na mesma faixa E mesma posição X que um veículo = HIT
- Hitbox da galinha: centro do sprite
- Hitbox do veículo: retângulo do sprite
- Hit empurra a galinha UMA faixa pra baixo (como se apertasse "baixo")
- Breve invincibilidade após hit (~500ms) pra evitar chain hits
- Progresso não é perdido completamente — apenas recua uma faixa

### Modos de Jogo (selectable in lobby)

1. **Classic** (padrão)
   - 10 faixas, dificuldade progressiva
   - Timer: 2 minutos
   - Tráfego determinístico

2. **Rush Hour**
   - 10 faixas, tráfego MUITO denso em todas as faixas
   - Timer: 2 minutos
   - Pra jogadores que querem caos máximo

3. **Sprint**
   - 6 faixas apenas (mais curto)
   - Timer: 1 minuto
   - Rounds rápidos, partidas best of 5

### Game State (synced via DataChannel)
- Chicken 1: lane (0-11, incluindo start/finish zones), cooldown timer, invincibility timer
- Chicken 2: lane (0-11), cooldown timer, invincibility timer
- Traffic: seed + frame counter (determinístico, ambos calculam igual)
- Scores (travessias completadas)
- Timer
- Game phase: `waiting` → `countdown` → `playing` → `finished`

### Authority Model
- **Host** é autoritativo para: colisão galinha/veículo, pontuação
- Tráfego é determinístico (seed compartilhado) — ambos clientes calculam posições
- Cada jogador envia: eventos de movimento (cima/baixo)
- Host valida colisões e broadcast: lanes das galinhas, scores
- Guest renderiza tráfego localmente (mesmo seed = mesmo resultado)
- Isso minimiza dados de rede (tráfego NÃO precisa ser sincronizado!)

### Scoring
- Cada travessia completa (base → topo) = 1 ponto
- Timer: 2 minutos (modo Classic/Rush Hour) ou 1 minuto (Sprint)
- Quem tem mais pontos ao fim do timer vence
- Se empate: sudden death (próxima travessia completa vence)
- Best of 3 rounds (Classic/Rush Hour) ou best of 5 (Sprint)

### Visual Style (Retro CRT)

- Background: asfalto cinza escuro com variação sutil entre faixas
- Faixas: alternando cinza claro/escuro
- Marcações: tracejado branco/amarelo entre faixas (estilo rodovia real)
- Zona de partida: verde (grama)
- Zona de chegada: verde (grama do outro lado)
- Galinha P1: verde brilhante, animação de caminhar
- Galinha P2: ciano brilhante, animação de caminhar
- Veículos: cores variadas (vermelho, azul, amarelo, branco), sprites pixelados
- Hit: flash branco + penas voando + recuo
- Travessia: flash dourado + número "+1" flutuando
- Timer: grande e visível no topo
- CRT scanlines + glow
- Efeito de "calor do asfalto": leve ondulação no background (sutil)

### Sound Effects
- Galinha andando: pat-pat rápido (patas no asfalto)
- Tráfego: hum constante de motores (volume varia com faixa — mais alto nas rápidas)
- Hit por veículo: buzina curta + SQUAWK da galinha + som de freada
- Recuo: slide sound
- Travessia completa: pling celebratório + crowd "ohh!"
- Retorno à base: whoosh (teleport)
- Timer warning (15s): ticking acelerado
- Sudden death: heartbeat + tráfego acelera (sonoramente mais intenso)
- Vitória: fanfarra + galinha cacarejando triunfante
- Empate: crowd murmurmuring

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low | Snap-to-lane, sem física contínua |
| Networking | Low | Apenas 2 lane positions + scores, tráfego é determinístico |
| Rendering | Low-Medium | 10 faixas de veículos animados, 2 galinhas |
| Input | Minimal | Literalmente 2 botões (cima e baixo) |
| Game logic | Low | Lane collision, scoring, timer |
| **Overall** | **Low** | O mais simples dos 5 — perfeito pra implementar rápido |

## Fun Factor

- ZERO learning curve: 2 botões. Cima e baixo. É isso.
- Humor built-in: galinhas atravessando rodovia é inerentemente engraçado
- Tensão do timer: ver os segundos acabando com o oponente 1 ponto na frente = desespero
- "UM CARRO ME PEGOU NA FAIXA 9!!!" — frustração cômica que gera risadas
- Rivalidade visual: você VÊ a galinha do oponente progredindo ao lado
- Sudden death é eletrizante: ambos tentando atravessar freneticamente
- Partidas curtíssimas (2 min): replay instantâneo
- O modo Rush Hour é puro caos hilário
- Perfeito pra apostas no chat: "quem perde paga uma cerveja virtual"
- Acessível pra QUALQUER pessoa, inclusive quem nunca jogou nada
- É o "party game" do catálogo — diversão garantida sem pretensão
