# Game Discovery: Skiing

## Identity

| Field | Value |
|-------|-------|
| **Name** | Skiing |
| **Original** | Activision, 1980 (criado por Bob Whitehead) |
| **Genre** | Racing / Sports |
| **Players** | 1 (original) → **2 (nossa adaptação)** |
| **Our ID** | `hex_skiing` |

## Why This Game

Skiing da Activision é o clássico de descida na neve do Atari. Bob Whitehead criou uma
simulação de esqui surpreendentemente satisfatória: controlar o ângulo do esquiador, desviar
de árvores, passar entre portões de slalom. No Brasil, era um daqueles jogos que todo mundo
tinha no cartucho "20 em 1" da CCE/Dactar. A mecânica é elegantemente simples — a gravidade
te puxa pra baixo, você só controla esquerda/direita — mas a velocidade crescente e os
obstáculos densos criam tensão real. A adaptação pra 2-player é a mais natural: dois
esquiadores descendo a MESMA montanha, lado a lado, disputando quem chega primeiro.

## Original Mechanics

### Core Loop
1. Esquiador começa no topo da montanha
2. Gravidade puxa pra baixo automaticamente (scrolling vertical descendente)
3. Jogador controla esquerda/direita (ângulo do esquiador)
4. Desviar de árvores e rochas (colidir = perda de tempo)
5. Passar entre portões de slalom (no modo slalom)
6. Chegar ao fundo no menor tempo possível

### Movimento
- Esquiador desce AUTOMATICAMENTE (gravidade constante)
- Joystick esquerda/direita: mover lateralmente
- Velocidade de descida é constante (não há aceleração manual)
- Quanto mais lateral o movimento, MAIS LENTO o esquiador desce
- Ir reto (sem input lateral) = velocidade máxima de descida
- Isso cria trade-off: desviar = mais seguro mas mais lento

### Obstáculos
- **Árvores**: fixas, espaçadas irregularmente
- **Rochas**: fixas, menores que árvores
- Colisão com obstáculo: esquiador PARA momentaneamente (~1 segundo)
- Não há morte — apenas perda de tempo
- Obstáculos ficam mais densos conforme desce

### Modos do Original
- **Downhill**: descer sem portões, menor tempo possível, desviar de tudo
- **Slalom**: descer passando entre portões (bandeiras azuis/vermelhas)
  - Perder um portão = penalidade de tempo (+5 segundos)
  - Portões ficam mais apertados conforme desce

### Variações (10 modos no original)
- 5 modos downhill (densidades diferentes de árvores)
- 5 modos slalom (dificuldades diferentes de portões)

## Our Adaptation: 2-Player Alpine Duel

### Conceito Criativo

**Mesma montanha, mesma neve, corrida direta.**

Dois esquiadores descendo LADO A LADO na mesma montanha. Não é split-screen — é a mesma
tela, mesmos obstáculos, competição visual direta. Você VÊ o oponente ao seu lado e isso
cria pressão psicológica: ele tá na frente! Preciso ir mais reto! Mas tem uma árvore...

A adaptação adiciona: avalanche (que persegue ambos), itens de boost/sabotagem na pista,
e portões que dão bônus de tempo.

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 42.3s    SKIING    P2: 41.8s            │
│┌────────────────────────────────────────────┐│
││                                            ││
││         🌲          🌲                     ││
││                                            ││
││    🌲    ☻₁   ☻₂          🌲              ││
││              🌲                 🌲          ││
││   🏁──🏁         🌲                        ││
││         🌲               ⚡                ││
││                  🪨    🌲                   ││
││    🌲         🌲              🌲            ││
││         🪨          🌲                      ││
││                                            ││
││    🌲    🏁──🏁         🌲       🌲        ││
││                  🌲          🪨             ││
││                                            ││
│└────────────────────────────────────────────┘│
│  ████████████████ AVALANCHE ████████████████ │
└──────────────────────────────────────────────┘
```

Legenda:
- ☻₁/☻₂ = esquiadores (P1 verde, P2 ciano)
- 🌲 = árvores (obstáculo)
- 🪨 = rochas (obstáculo)
- 🏁──🏁 = portão de slalom (bônus)
- ⚡ = item de boost
- AVALANCHE = barra de avalanche perseguindo (topo da tela)

### Pista (Arena)
- Vista top-down com scrolling vertical descendente
- Neve branca como base
- Ambos esquiadores compartilham a mesma pista
- Pista é larga o suficiente pra ambos (~2x a largura do original)
- Obstáculos são gerados proceduralmente (seed compartilhado)
- Portões de slalom aparecem periodicamente
- Itens aparecem raramente na pista

### Esquiadores (sprites top-down)

```
Esquiador descendo reto:     Virando à esquerda:    Colidiu:
       ╭╮                      ╭╮                    ╭╮
      ╱  ╲                    ╱  ╲                   ╱╲
     ╱ ☻  ╲                 ╱☻   │                  │☻│ 💥
     │    │                 ╲    │                   ╲╱
     ╱  ╲                    ╲  ╱                    splash
    ╱    ╲                    ╲╱                     neve
```

- Sprite ~8x12 px
- P1: verde (casaco/gorro verde, esquis verdes)
- P2: ciano (casaco/gorro azul, esquis azuis)
- Animação: reto (esquis paralelos), virando (esquis angulados), colisão (tombo + neve)
- Trail na neve: rastro atrás do esquiador (branco no fundo branco = sutil)
- Boost ativo: partículas de velocidade atrás

### Obstáculos

#### Árvores 🌲
```
    🌲
   ╱██╲
  ╱████╲     ← pinheiro pixel art
  ╱██████╲
     ██       ← tronco
```
- Fixas na pista, posições procedurais
- Hitbox: tronco (pequeno, mas colidir com galhos também conta)
- Colisão: esquiador para ~1.5s, animação de tombo
- Mais comuns que rochas

#### Rochas 🪨
```
   ╭──╮
   │▓▓│     ← rocha cinza
   ╰──╯
```
- Menores que árvores, mais difíceis de ver
- Colisão: esquiador para ~1s
- Aparecem a partir do trecho 3

### Avalanche (mecânica nova — pressão constante)

#### Conceito
- Uma parede de neve desce ATRÁS dos jogadores, perseguindo-os
- A avalanche começa lenta e ACELERA gradualmente
- Se a avalanche alcançar um jogador: ele é ENGOLIDO (perde o round)
- A avalanche é a mesma pra ambos (mesma altura na tela)
- Visual: parede branca/cinza com partículas no topo da tela, descendo

#### Mecânica
- Avalanche começa a ~20% do topo da tela
- Desce a uma velocidade constante que aumenta a cada 30 segundos
- Colidir com árvore/rocha = parar = avalanche se aproxima perigosamente
- Ir reto (velocidade máxima) = manter distância da avalanche
- Ir muito lateral = perder velocidade = avalanche se aproxima
- Se ambos são engolidos: quem desceu mais longe vence

#### Visual da Avalanche
```
████████████████████████████████████
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
░░░░░░ AVALANCHE ░░░░░░░░░░░░░░░░░
  ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
```
- Ocupa toda a largura da tela
- Gradiente: branco denso no topo → partículas soltas na borda
- Rugido crescente conforme se aproxima

### Portões de Slalom (bônus)

```
  🔵──────────🔴    ← portão (passar entre = bônus)
      ~20px
```

- Pares de bandeiras (azul + vermelha) formando um portão
- Aparecem a cada ~10 segundos
- Passar ENTRE as bandeiras: -2 segundos no timer (bônus de tempo)
- Falhar (passar por fora): nada acontece (sem penalidade)
- Portões ficam mais estreitos conforme a corrida avança
- Ambos jogadores podem pegar o mesmo portão (não é exclusivo)

### Itens na Pista (power-ups)

#### ⚡ Speed Boost
```
  ⚡    ← relâmpago amarelo brilhante
```
- Coletar: 3 segundos de velocidade 1.5x
- Um por vez na pista
- Se um jogador coleta: desaparece pra ambos

#### ❄️ Ice Patch (armadilha natural)
```
  ~~~    ← gelo azul brilhante
```
- Área no chão: pisar = perda de controle lateral por 2 segundos
- O esquiador derrapa na direção que estava indo
- Ambos podem ser afetados
- Não é item coletável — é obstáculo ambiental

#### 🌫️ Nevasca (evento temporário)
- A cada ~45 segundos: nevasca cobre a tela
- Visibilidade reduzida drasticamente (~30%)
- Dura 10 segundos
- Obstáculos ficam quase invisíveis
- Ambos jogadores afetados igualmente

### Controls
- **Left / Right arrows** — mover esquiador lateralmente
- **WASD** — alternativo

Nota: SÓ ISSO. Dois botões. Gravidade faz o resto. A simplicidade é a alma do Skiing.

### Velocidade e Física

#### Descida
- Gravidade puxa pra baixo constantemente
- Velocidade base: constante
- Mover lateralmente: velocidade de descida diminui proporcionalmente
  - Input lateral leve: 90% velocidade
  - Input lateral forte: 70% velocidade
  - Sem input: 100% velocidade
- Speed boost: 150% velocidade por 3s
- Pós-colisão: 0% por 1-1.5s (parado), depois volta gradualmente

#### Inércia Lateral
- Leve inércia ao mudar de direção (não é instantâneo)
- Simula o esqui real (curvas em arco, não em ângulo reto)
- Mais elegante e skill-based que movimento instantâneo

### Scoring e Vitória

#### Timer
- Cada jogador tem seu próprio timer (começa em 0, sobe)
- Timer PARA quando colide com obstáculo (não conta tempo parado)
- Portão de slalom: -2 segundos no timer
- Quem chegar ao fundo com MENOR tempo vence

#### Distância
- Pista tem comprimento fixo (equivalente a ~90 segundos de descida limpa)
- Se avalanche engole jogador: a distância percorrida fica registrada
- Se ninguém é engolido: menor tempo vence

#### Match
- Best of 3 descidas
- Descida 1: árvores esparsas, avalanche lenta, portões largos
- Descida 2: mais árvores + rochas, avalanche média, portões médios
- Descida 3: árvores densas + rochas + ice patches, avalanche rápida, portões estreitos

### Game Modes (selectable in lobby)

1. **Alpine Race** (padrão)
   - Best of 3 descidas com dificuldade crescente
   - Avalanche + portões + itens
   - Full experience

2. **Avalanche Escape**
   - 1 descida INFINITA (pista não tem fim)
   - Avalanche começa lenta e NUNCA para de acelerar
   - Último jogador a ser engolido vence
   - Puro survival

3. **Clean Run**
   - SEM avalanche, SEM itens
   - Apenas árvores, rochas e portões
   - Menor tempo na descida vence
   - Modo purista (closest ao original)

### Game State (synced via DataChannel)
- Skier 1: position (x, y), velocity, state (skiing/crashed/boosted), timer
- Skier 2: position (x, y), velocity, state, timer
- Obstacles: determinístico (seed + scroll position)
- Gates: array of {position, width, cleared_by_p1, cleared_by_p2}
- Items: array of {type, position, collected_by}
- Avalanche: position_y, speed
- Blizzard: active flag, timer
- Scroll position, distance remaining
- Game phase: `waiting` → `countdown` → `racing` → `finish`/`avalanche` → `round_end`

### Authority Model
- **Host** é autoritativo para: collisions, gate clearance, item collection, avalanche position
- Obstacle layout é determinístico (seed compartilhado)
- Cada jogador envia: lateral input
- Host simula: positions, speeds, avalanche, collisions
- Host broadcast: positions, obstacle scroll, avalanche, items, gates, timers
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Background: branco (neve) com textura sutil de neve
- Árvores: verde escuro (pinheiros pixel art com sombra)
- Rochas: cinza com sombra
- Esquiador P1: verde brilhante (casaco + esquis)
- Esquiador P2: ciano brilhante (casaco + esquis)
- Rastro de esqui: linhas sutis na neve (par de linhas paralelas)
- Portões: bandeira azul + bandeira vermelha com corda/barra
- Portão cleared: flash dourado ao passar
- Speed boost: relâmpago amarelo, partículas de velocidade
- Ice patch: área azul-claro cintilante
- Nevasca: partículas brancas densas + redução de visibilidade
- Avalanche: parede branca/cinza com textura de neve e rochas misturadas
- Borda da avalanche: partículas voando, nuvem de neve
- Colisão: explosão de neve + tombo do esquiador
- Chegada: linha de chegada vermelha/branca estilo corrida
- CRT scanlines + glow sutil (neve brilha)

### Sound Effects
- Esqui na neve: shhhhh constante (swoosh de neve, pitch varia com velocidade)
- Curva: swoosh mais agudo (neve sendo cortada)
- Speed boost: whoosh + brilho sonoro
- Colisão com árvore: CRACK + poof de neve
- Colisão com rocha: thud + slide
- Recuperação pós-colisão: shake off + retomada
- Portão cleared: ding satisfatório
- Ice patch: slide sound (perda de controle)
- Nevasca chegando: vento uivando crescente
- Nevasca passando: vento diminuindo
- Avalanche rugido: rumble grave constante (volume cresce com proximidade)
- Avalanche muito perto: alarm + heartbeat
- Engolido pela avalanche: rumble máximo + silêncio repentino
- Chegada: sino de final + crowd cheer
- Vitória: fanfarra de pódio + hino dos campeões

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low-Medium | Scroll vertical, inércia lateral, velocidade por ângulo |
| Networking | Low | 2 posições + obstacle seed + avalanche + items |
| Rendering | Medium | Neve com árvores, avalanche, nevasca particles, rastros |
| Input | Minimal | Esquerda/direita apenas (2 inputs!) |
| Game logic | Medium | Avalanche speed, gate scoring, ice patches, items, timer |
| **Overall** | **Low-Medium** | Visual polish (neve, avalanche) é o maior esforço |

## Fun Factor

- 2 botões. Esquerda e direita. Gravidade faz o resto. QUALQUER UM joga.
- Ver o oponente bater numa árvore ao seu lado = GARGALHADA garantida
- Avalanche perseguindo = tensão constante + decisão (ir reto e arriscar ou desviar e perder velocidade)
- "Ele pegou o boost e eu peguei a árvore" = drama cômico
- Nevasca repentina: "NÃO CONSIGO VER NADA" → colide → avalanche se aproxima
- Portões de slalom recompensam habilidade (2 segundos menos é MUITO)
- Ice patches criam momentos de pânico ("estou derrapando direto pra árvore!")
- A descida tem ritmo perfeito: começa suave, termina frenético
- Modo Avalanche Escape é viciante: "até onde a gente chega?"
- Rastros de esqui na neve são satisfatórios visualmente
- Corrida lado a lado: você SENTE a competição (oponente visível o tempo todo)
- O jogo mais acessível do catálogo inteiro (ao lado do Freeway)
