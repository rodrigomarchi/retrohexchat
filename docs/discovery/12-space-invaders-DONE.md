# Game Discovery: Space Invaders

## Identity

| Field | Value |
|-------|-------|
| **Name** | Space Invaders |
| **Original** | Taito, 1978 (arcade) / Atari 2600 port, 1980 |
| **Genre** | Shoot 'em Up / Fixed Shooter |
| **Players** | 2 (simultaneous, no Atari 2600 — 112 variações!) |
| **Our ID** | `hex_invaders` |

## Why This Game

Space Invaders é o jogo que criou a indústria de arcade. Causou escassez de moedas de 100 yen
no Japão. Vendeu mais Atari 2600 do que qualquer outro jogo. No Brasil, foi um dos primeiros
jogos que todo mundo jogou — reconhecível pelo formato icônico dos aliens. A versão do Atari 2600
JÁ TINHA 112 variações, incluindo modos 2-player simultâneos oficiais. Nossa adaptação eleva
essa base: dois canhões defendendo contra a invasão, mas com uma mecânica twist — aliens que
VOCÊ derruba caem no lado do OPONENTE como reforços.

## Original Mechanics

### Core Loop
1. Fileiras de aliens descem lentamente em direção à Terra
2. Jogador move um canhão horizontalmente na base
3. Atirar pra cima pra destruir aliens
4. Aliens atiram bombas pra baixo aleatoriamente
5. Escudos (bunkers) protegem parcialmente o canhão
6. Se aliens chegam ao chão: game over
7. Destruir todos: nova wave (mais rápida)

### Aliens
- 5-6 fileiras de aliens organizados em grid
- Movem-se lateralmente em grupo (esquerda→direita→descem→direita→esquerda)
- Velocidade AUMENTA conforme são destruídos (menos aliens = mais rápido)
- Cada alien desce um nível quando o grupo atinge a borda da tela
- Aliens atiram bombas verticalmente (aleatório)
- Alien misterioso (UFO) passa no topo ocasionalmente (bônus)

### Canhão do Jogador
- Move horizontalmente na base da tela
- Um tiro na tela por vez
- Tiro viaja pra cima, destrói um alien ao contato
- Se atingido por bomba de alien: perde vida

### Escudos (Bunkers)
- 3-4 escudos entre o canhão e os aliens
- Escudos absorvem tiros (do jogador E dos aliens)
- Escudos se degradam com cada impacto (pedaços desaparecem)
- Aliens passando pelo escudo também o destroem

### Modos 2-Player do Original (Atari 2600)
O port do Atari 2600 tinha 112 variações, incluindo:
- **Alternando**: jogadores revezam ao morrer
- **Cooperativo simultâneo**: dois canhões ao mesmo tempo
- **Split-screen**: cada jogador defende metade da tela
- **Sabotagem**: se um jogador é atingido, o OUTRO ganha 200 pts
- **Compartilhado**: um jogador move, outro atira
- **Variações de inimigos**: zigzag, invisíveis, rápidos

## Our Adaptation: 2-Player Invasion War

### Conceito Criativo

**Não é co-op. É GUERRA.**

Cada jogador defende SEU lado da tela contra aliens. Os aliens descem normalmente. MAS: quando
você destrói um alien no seu lado, ele NÃO desaparece — ele **CAI no lado do oponente** como
um reforço inimigo extra. Quanto melhor você joga, mais difícil fica pro outro.

É um "puzzle de ataque" invertido: você QUER destruir aliens rápido (senão chegam no seu
chão), mas cada alien destruído REFORÇA o exército inimigo do oponente.

Inspirado em Tetris Attack/Puzzle Fighter: o conceito de "lixo enviado" aplicado a Space
Invaders.

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 1240  SPACE INVADERS  P2: 980   Wv: 3  │
│┌───────────────────╫───────────────────┐     │
││  👾 👾 👾 👾 👾   ║  👾 👾 👾 👾 👾  │     │
││  👾 👾 👾 👾 👾   ║  👾 👾    👾 👾  │     │
││  👾    👾 👾 👾   ║  👾 👾 👾 👾 👾  │     │
││  👾 👾 👾    👾   ║  👾 👾 👾    👾  │     │
││        💥         ║       💥          │     │
││     ●↑            ║          ●↑       │     │
││                   ║                   │     │
││   ▓▓▓   ▓▓▓      ║    ▓▓▓   ▓▓▓     │     │
││                   ║                   │     │
││       ◉           ║        ◎          │     │
│└───────────────────╫───────────────────┘     │
│  Lives: ♥♥♥         Lives: ♥♥               │
└──────────────────────────────────────────────┘
```

Legenda:
- ║ = divisor central (barreira visual, NÃO colide)
- 👾 = aliens (grid de invasores descendo)
- ◉ = canhão P1 (verde)
- ◎ = canhão P2 (ciano)
- ●↑ = mísseis dos jogadores
- 💥 = explosão de alien destruído
- ▓▓▓ = escudos (bunkers)
- Cada lado tem seu próprio grid de aliens, escudos e canhão

### Mecânica Central: "Alien Drop" (lixo enviado)

#### Como Funciona
1. Jogador P1 destrói um alien no lado esquerdo
2. Alien destruído "cai" no lado do P2 como reforço
3. Reforço aparece na fileira mais BAIXA do grid de P2 (perto do chão!)
4. Isso é PERIGOSO pro P2 — alien aparece já perto
5. Vice-versa: aliens destruídos por P2 caem no lado de P1

#### Tipo de Alien Enviado
- Alien regular destruído → reforço regular no lado oposto
- Alien de fileira superior (mais pontos) → reforço MAIS RÁPIDO enviado
- UFO destruído → reforço ESPECIAL: alien blindado (precisa 2 tiros) enviado!

#### Timing do Drop
- Alien destruído não cai instantaneamente
- Delay de ~2 segundos (dá tempo pro receptor se preparar)
- Visual: alien desce como "preview" do lado oposto (transparente → sólido)
- Som: warning distinto quando alien vai cair no seu lado

#### Combo System
- Destruir 3+ aliens em sequência rápida (<1.5s entre kills): COMBO
- Combo de 3: envia 1 alien extra (total 4 caem no oponente)
- Combo de 5: envia 2 extras + um alien blindado
- Combo de 8+: envia 3 extras + alien bomba (explode aliens vizinhos do oponente... ou escudos)
- Combos incentivam jogo rápido e preciso

### Aliens (sprites)

```
Alien regular (3 tipos por fileira):

Tipo 1 (topo):    Tipo 2 (meio):    Tipo 3 (base):
   ╱▔╲               ╭─╮              ▄█▄
  ╱ ◉◉╲              │◉◉│             █◉◉█
  ╰┬──┬╯             ╰┬┬╯             ╰██╯
   ╱╲╱╲               ╱╲               ╱╲

Alien blindado (enviado por UFO kill):
   ╔══╗
   ║◉◉║    ← escudo metálico (2 hits)
   ╚══╝

Alien bomba (combo 8+):
   ╭💣╮
   │◉◉│    ← explode ao ser destruído (area damage)
   ╰──╯
```

- 3 tipos base com valores diferentes (10, 20, 30 pts)
- Tipo topo: tentáculos, 30 pts
- Tipo meio: antenas, 20 pts
- Tipo base: quadrado, 10 pts
- Aliens reforço (caídos): brilho vermelho pulsante (distinção visual)
- Blindados: sprite metálico, precisa 2 tiros
- Bomba: sprite com ícone de explosão

### UFO (nave misteriosa)

```
UFO:
  ╭─────╮
  │ ═══ │    ← luzes piscando
  ╰─────╯
  ~16px
```

- Cruza o topo da tela horizontalmente (aleatório, a cada ~30s)
- Vale 100-300 pts (aleatório)
- Destruir UFO = envia alien BLINDADO pro oponente
- UFO é compartilhado: cruza AMBOS os lados da tela
- Quem acertar primeiro leva (corrida pelo tiro!)

### Escudos / Bunkers

```
Escudo intacto:        Escudo danificado:      Escudo destruído:
  ▓▓▓▓▓▓▓▓             ▓▓ ▓▓ ▓▓               ▓  ▓   ▓
  ▓▓▓▓▓▓▓▓             ▓▓▓  ▓▓▓                ▓    ▓
  ▓▓    ▓▓             ▓      ▓
```

- 2 escudos por lado
- Degradam pixel a pixel com cada impacto
- Protegem contra bombas de aliens E reforços caindo
- Reforço que cai EM CIMA do escudo destrói parte dele
- Escudos NÃO regeneram entre waves

### Canhões dos Jogadores

```
Canhão:
    ▲
  ╔═╧═╗
  ╚═══╝
  ~10px
```

- P1: verde brilhante
- P2: ciano brilhante
- Move horizontalmente (apenas no seu lado da tela)
- Um tiro na tela por vez (clássico Space Invaders)
- Hit por bomba: explosão + perda de vida

### Controls
- **Left / Right arrows** — mover canhão
- **Space** — atirar
- **WASD + Shift** — alternativo

Simples. 3 inputs. Como Deus quis.

### Waves e Progressão
- Cada wave: grid novo de aliens (5 fileiras × 6 colunas = 30 aliens por lado)
- Wave 1: aliens lentos, poucas bombas
- Wave 2: aliens mais rápidos, mais bombas
- Wave 3+: aliens com padrões zigzag, bombas guiadas
- Wave 5+: aliens invisíveis (aparecem brevemente ao atirar)
- Entre waves: escudos NÃO regeneram, mas reforços acumulados são limpos
- Aliens reforço (caídos) persistem entre waves se não destruídos!

### Scoring
- Alien tipo 1 (base): 10 pts
- Alien tipo 2 (meio): 20 pts
- Alien tipo 3 (topo): 30 pts
- Alien reforço (caído): 15 pts (vale menos — incentiva não deixar acumular)
- Alien blindado: 50 pts
- UFO: 100-300 pts (aleatório)
- Combo bonus: 50 pts por nível de combo
- Sobreviver wave: 200 pts bônus

### Vidas e Game Over
- 3 vidas cada
- Bomba de alien atinge canhão: -1 vida
- Alien chega ao chão (sua fileira): GAME OVER INSTANTÂNEO pra esse jogador
- Oponente continua jogando (score bônus por sobrevivência)
- Se ambos sobrevivem após 10 waves: maior score vence
- Último jogador vivo: +500 pts bônus de sobrevivência

### Game Modes (selectable in lobby)

1. **Invasion War** (padrão)
   - Tela dividida, alien drop ativo
   - Combos enviam extras
   - 10 waves ou game over

2. **Classic Co-op**
   - Tela COMPARTILHADA (ambos canhões no mesmo campo)
   - SEM alien drop (aliens destruídos somem de vez)
   - Cooperativo: ambos lutam contra as mesmas waves
   - Score individual mas objetivo compartilhado (sobreviver)

3. **Blitz Mode**
   - Alien drop acelerado (sem delay)
   - Combos mais fáceis (2 aliens = combo)
   - 5 waves, velocidade alta desde o início
   - Caótico e rápido

### Game State (synced via DataChannel)
- Cannon 1: position_x, lives, shot state
- Cannon 2: position_x, lives, shot state
- Alien grid P1: array of {type, position, alive, is_reinforcement, is_armored, HP}
- Alien grid P2: array of {type, position, alive, is_reinforcement, is_armored, HP}
- Alien bombs: array of {side, position (x, y), velocity}
- Shields: pixel state per shield (bitmask of alive pixels)
- UFO: position_x, active, side
- Pending drops: queue of aliens about to fall on each side
- Scores + wave + combo counters
- Game phase: `waiting` → `countdown` → `wave_start` → `playing` → `wave_clear` → ... → `finished`

### Authority Model
- **Host** é autoritativo para: all collisions, alien drop queue, combo counting, UFO
- Alien movement é determinístico (speed based on count remaining)
- Cada jogador envia: position, fire events
- Host valida: hits, bomb hits, drops, UFO capture
- Host broadcast: alien grids, cannon positions, bombs, scores, drops
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Background: preto (espaço)
- Divisor central: linha vertical sutil (tracejada, roxo escuro)
- Aliens: verde/branco clássico com animação 2-frame (pernas alternando)
- Aliens reforço: mesmo sprite mas com brilho VERMELHO pulsante
- Aliens blindados: sprite metálico prateado
- Alien bomba: sprite com glow laranja
- Canhão P1: verde brilhante
- Canhão P2: ciano brilhante
- Tiros: brancos brilhantes
- Bombas de aliens: relâmpagos verticais (zigzag)
- UFO: multicolorido, luzes piscando, trail arco-íris
- Escudos: verde (P1 side) / ciano (P2 side), pixel art que degrada
- Explosão de alien: flash + partículas da cor do alien
- Alien caindo (preview de drop): transparente descendo do topo do lado oposto
- Game over de um lado: lado escurece, "INVADED" em vermelho
- CRT scanlines + glow intenso (especialmente nos tiros)

### Sound Effects
- Alien march: tum-tum-tum-tum (clássico! acelera com menos aliens)
- Tiro do jogador: pew agudo
- Alien destruído: pop/crackle
- Bomba de alien caindo: whoosh descendente
- Bomba atingiu canhão: explosion + alarm
- Escudo atingido: thud sólido
- UFO aparecendo: theremin clássico (wooo-wooo)
- UFO destruído: sparkle + bonus sound
- Combo x3: drum fill rápido
- Combo x5: drum fill + crowd "ohh!"
- Combo x8+: drum fill + alarme do oponente
- Alien drop (preview): descending whistle de aviso
- Alien drop (materializa): thud grave
- Alien blindado recebendo 1º tiro: clang metálico
- Wave clear: fanfarra curta + respiro
- Game over (aliens chegaram): alarm grave + collapse
- Vitória: Space Invaders theme triumphant + laser show

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low | Tiros retos, aliens em grid, bombas verticais |
| Networking | Medium | 2 grids de aliens + drop queue + bombs + UFO |
| Rendering | Low-Medium | Grid de sprites, escudos degradáveis, partículas |
| Input | Minimal | Esquerda/direita + atirar (3 inputs) |
| Game logic | Medium-High | Alien drop system, combos, blindados, UFO dispute, waves |
| **Overall** | **Medium** | Drop system é a peça complexa; o resto é clássico |

## Fun Factor

- O som "tum-tum-tum" acelerando é dos mais icônicos da história dos games
- Alien drop transforma o jogo de "eu vs aliens" em "eu vs VOCÊ via aliens"
- Combos incentivam jogo rápido e preciso — recompensa habilidade
- Ver aliens caindo no lado do oponente = satisfação PURA
- "Ele destruiu o UFO e agora tem um alien blindado no meu lado!" = drama
- Escudos degradando criam senso de urgência crescente
- Wave final com aliens invisíveis + reforços acumulados = caos absoluto
- 3 inputs apenas: toda complexidade é emergente, não mecânica
- Classic Co-op mode: perfeito pra quando querem jogar juntos em vez de competir
- Todo mundo CONHECE Space Invaders — reconhecimento universal
- O grid de aliens descendo lentamente é hipnótico e ameaçador
- "Os aliens chegaram no chão!" é game over instantâneo — high stakes
