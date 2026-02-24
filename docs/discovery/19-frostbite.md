# Game Discovery: Frostbite

## Identity

| Field | Value |
|-------|-------|
| **Name** | Frostbite |
| **Original** | Activision, 1983 (criado por Steve Cartwright) |
| **Genre** | Platformer / Action |
| **Players** | 1 (original) → **2 (nossa adaptação)** |
| **Our ID** | `hex_frost` |

## Why This Game

Frostbite é o jogo de quem REALMENTE entendia de Atari no Brasil. Enquanto todo mundo jogava
River Raid e Enduro, os conhecedores sabiam que Frostbite era especial: construir um iglu
saltando em blocos de gelo flutuantes enquanto desvia de ursos polares, caranguejos, gansos
e mariscos assassinos. Criado por Steve Cartwright (o gênio por trás de Megamania), o jogo
exige "intensa coordenação, concentração e raciocínio rápido." A mecânica de pular em blocos
que mudam de cor pra construir um iglu é única e viciante. A adaptação pra 2-player
transforma a construção solitária numa CORRIDA de construção com sabotagem ártica.

## Original Mechanics

### Core Loop
1. Frostbite Bailey (personagem) está numa plataforma de gelo no topo
2. Abaixo: 4 fileiras de blocos de gelo flutuando horizontalmente
3. Pular nos blocos brancos = bloco vira azul + 1 peça adicionada ao iglu
4. Quando todos os blocos de uma fileira ficam azuis, voltam a branco
5. Completar o iglu = entrar nele (pontos bônus pela temperatura restante)
6. Desviar de inimigos: ursos, caranguejos, gansos, mariscos
7. Termômetro desce constantemente = timer de morte
8. Se temperatura chega a 0: vida perdida

### Blocos de Gelo
- 4 fileiras horizontais de blocos de gelo flutuando
- Cada fileira se move em direção oposta à anterior (alternando)
- Fileiras 1 e 3: esquerda→direita
- Fileiras 2 e 4: direita→esquerda
- Blocos são BRANCOS (não pisados) ou AZUIS (pisados)
- Pisar em branco = vira azul + peça do iglu
- Pisar em azul = vira branco novamente (DESFAZ a peça!)
- Cuidado: pisar no bloco errado destrói progresso

### Iglu
- Construído bloco a bloco no canto superior da tela
- Cada bloco de gelo pisado (branco→azul) = 1 peça do iglu
- Iglu precisa de ~15 peças pra completar
- Iglu completo: porta aparece, jogador entra pra pontuação bônus
- Pisar em bloco azul (azul→branco) = REMOVE 1 peça do iglu!

### Temperatura
- Termômetro começa em ~45° e desce constantemente
- Funciona como timer do round
- Se chega a 0°: jogador morre de hipotermia
- Ao completar iglu: temperatura restante × multiplicador = bônus
- Quanto mais rápido constrói, mais bônus

### Inimigos
- **Urso polar**: anda na plataforma superior (onde o jogador começa)
- **Gansos**: voam entre as fileiras de gelo (obstáculo aéreo)
- **Caranguejos**: andam nos blocos de gelo (mesmo nível, mesma direção)
- **Mariscos (clams)**: abrem e fecham nos blocos (timing de passagem)
- Tocar em qualquer inimigo = vida perdida

### Peixes
- Peixes nadam entre as fileiras (horizontalmente)
- Coletar peixe = 200 pts bônus
- Não são obrigatórios, mas vale o risco

### Pular
- Jogador pula pra frente (na direção que está andando) para o bloco da fileira seguinte
- Precisa calcular posição do bloco flutuante pra cair nele
- Errar o bloco (cair na água) = vida perdida
- Pular pra trás: volta à fileira anterior (seguro, mas perde tempo)

## Our Adaptation: 2-Player Arctic Race

### Conceito Criativo

**Corrida de construção de iglu com sabotagem cruzada.**

Dois Frostbite Baileys, dois iglus, MESMO campo de gelo. Ambos pulam nos mesmos blocos
flutuantes. A mecânica twist: os blocos são COMPARTILHADOS. Se P1 pisa num bloco e faz
branco→azul (ganha peça), e depois P2 pisa no MESMO bloco que agora está azul, ele faz
azul→branco — e P2 ganha a peça pro SEU iglu enquanto P1 PERDE a peça do dele!

Pisar em bloco azul do oponente = ROUBAR peça. É construção E desconstrução simultânea.

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 640    FROSTBITE    P2: 510    🌡️32°   │
│┌────────────────────────────────────────────┐│
││  ┌iglu P1┐              ┌iglu P2┐          ││
││  │▓▓▓▓▓▓│   🐻    🐻   │▓▓░░░░│          ││
││  │▓▓  ▓▓│              │░░  ░░│          ││
││  └──────┘              └──────┘          ││
││ ─ ─ ─ ─ ─ ─ ─shore─ ─ ─ ─ ─ ─ ─ ─ ─ ─  ││
││                                            ││
││  ██ ☻₁██ ██ ▒▒🦀▒▒ ▒▒ ▒▒ ██ →→→         ││  fileira 1
││                                            ││
││       ▒▒ ▒▒ ▒▒ ☻₂██ 🐟 ██ ██  ←←←       ││  fileira 2
││                                            ││
││  ██ ██ 🦢▒▒ ▒▒ ▒▒ ██ ██ ██  →→→          ││  fileira 3
││                                            ││
││       ▒▒ ██ 🐚██ ▒▒ ▒▒ ██ ██  ←←←       ││  fileira 4
││                                            ││
││~~~~~~~~~~~~~~~~~~~~~~~~water~~~~~~~~~~~~~~~││
│└────────────────────────────────────────────┘│
│  Iglu: ██████░░░░  vs  Iglu: ████░░░░░░░░  │
└──────────────────────────────────────────────┘
```

Legenda:
- ██ = bloco branco (não pisado — qualquer um pode pisar pra ganhar peça)
- ▒▒ = bloco azul de P1 (pisado por P1 — se P2 pisar, ROUBA a peça)
- ░░ = bloco azul de P2 (pisado por P2 — se P1 pisar, rouba)
- ☻₁/☻₂ = Frostbite Bailey P1/P2
- 🐻 = urso polar (na shore)
- 🦀 = caranguejo (nos blocos)
- 🦢 = ganso (entre fileiras)
- 🐚 = marisco (nos blocos, abre/fecha)
- 🐟 = peixe (bônus)
- iglu P1/P2 = iglus sendo construídos

### Mecânica de Blocos Compartilhados (detalhe)

#### Estados do Bloco
Cada bloco tem 3 estados:
1. **Branco** (neutro): ninguém pisou → qualquer um pode pisar pra ganhar peça
2. **Azul-P1**: pisado por P1 → se P1 pisar de novo, vira branco (P1 PERDE peça)
3. **Azul-P2**: pisado por P2 → se P2 pisar de novo, vira branco (P2 PERDE peça)

#### Interações de Piso
| Estado atual | P1 pisa | P2 pisa |
|-------------|---------|---------|
| Branco | → Azul-P1, P1 +1 peça | → Azul-P2, P2 +1 peça |
| Azul-P1 | → Branco, P1 -1 peça | → Azul-P2, P2 +1 peça, P1 -1 peça |
| Azul-P2 | → Azul-P1, P1 +1 peça, P2 -1 peça | → Branco, P2 -1 peça |

A regra chave: **pisar no bloco do oponente ROUBA a peça** (ele perde, você ganha).
Pisar no seu próprio bloco de novo DESFAZ (você perde, ninguém ganha).

### Roubo de Peças
- Cada roubo = ganho duplo (oponente -1, você +1 = swing de 2 peças!)
- Roubar é mais eficiente que pisar em branco (2x impacto)
- Mas blocos do oponente podem estar em posições perigosas (perto de inimigos)
- Decisão constante: ir pro bloco seguro branco ou arriscar roubar?

### Frostbite Bailey (sprites)

```
Parado:            Pulando:           Caindo na água:
  ╭─╮              ╭─╮                ╭─╮
  │☻│              │☻│  ↗             │☻│  💦
 ╭┴─┴╮            ╭┴─┴╮              ╭┴─┴╮
 │   │            │ ╱╲│              │ ~~ │
 ╰┬─┬╯            ╰╱──╲╯              ╰────╯
  │ │              ~jump~               ~splash~
```

- Sprite ~8x12 px
- P1: verde (casaco verde, gorro verde)
- P2: ciano (casaco azul, gorro azul)
- Animação: idle, walk (nos blocos), jump (arco entre fileiras), splash (caiu na água)

### Inimigos (detalhados)

#### Urso Polar 🐻
```
  ╭───╮
  │ ◕◕│
  │▓▓▓│    ← grande, lento, patrulha a shore
  ╰┬─┬╯
```
- Patrulha horizontalmente na plataforma superior (shore)
- Jogador precisa desviar pra entrar no iglu
- Não desce pros blocos de gelo
- Matar: impossível (desviar apenas)

#### Caranguejo 🦀
```
  ╱╲╱╲
  │◉◉│    ← anda nos blocos de gelo
  ╰┬┬╯
```
- Anda horizontalmente nos blocos (mesma velocidade dos blocos)
- Se encostar: vida perdida
- Aparece a partir do round 2

#### Ganso 🦢
```
  ═╗
  ╚═══    ← voa entre fileiras
```
- Voa horizontalmente entre as fileiras de blocos
- Obstáculo aéreo durante pulos
- Se tocar durante o pulo: vida perdida
- Aparece a partir do round 3

#### Marisco 🐚
```
  Aberto:     Fechado:
  ╭──╮        ╭╮
  │◉ │        ││     ← abre e fecha ritmadamente
  ╰──╯        ╰╯
```
- Fica parado num bloco de gelo
- Abre e fecha ciclicamente
- Aberto = perigoso (encostar = morte)
- Fechado = seguro (pode pular por cima)
- Timing é tudo

#### Peixe 🐟
```
  ><>    ← nada entre fileiras, bônus
```
- Nada horizontalmente entre fileiras
- Coletar = 200 pts
- NÃO é perigoso (é bônus)
- Compartilhado: quem tocar primeiro leva

### Controls
- **Left / Right arrows** — andar horizontalmente no bloco/plataforma
- **Up arrow** — pular pra fileira de cima (avançar)
- **Down arrow** — pular pra fileira de baixo (recuar)
- **WASD** — alternativo

Nota: NÃO há botão de ataque. É puro movimento e pulo.

### Temperatura (timer compartilhado)
- Termômetro começa em 45° e desce ~1° por segundo
- Temperatura é COMPARTILHADA (mesmo timer pra ambos)
- Se chegar a 0°: round termina, quem tem iglu mais completo ganha
- Se um jogador completar iglu antes: ele entra, ganha bônus de temperatura
- O outro jogador continua tentando completar até temperatura chegar a 0°
- Incentivo: completar RÁPIDO pra maximizar bônus E encerrar o round primeiro

### Iglu e Vitória

#### Construção
- Cada jogador tem seu iglu no topo da tela (um de cada lado)
- Iglu precisa de 15 peças pra completar
- Peças são ganhas pisando em blocos brancos OU roubando blocos do oponente
- Peças podem ser PERDIDAS se oponente roubar seus blocos ou se você pisar no próprio
- Iglu visual: vai sendo construído bloco a bloco (satisfatório!)
- Porta aparece quando falta 1 peça

#### Completando o Iglu
- Iglu completo: jogador precisa voltar à shore (plataforma superior)
- Entrar no iglu = round VENCIDO por esse jogador
- Bônus: temperatura restante × 10 pts
- Oponente: round termina pra ambos, jogador sem iglu = 0 bônus

#### Scoring
- Pisar em bloco branco: 10 pts + peça de iglu
- Roubar bloco do oponente: 20 pts + peça + oponente perde peça
- Coletar peixe: 200 pts
- Completar iglu: 500 pts + bônus de temperatura
- Sobreviver round sem completar: pontos acumulados dos blocos apenas

### Rounds e Match
- Best of 5 rounds
- Cada round: nova disposição, temperatura reset a 45°
- Dificuldade aumenta por round:
  - Round 1: sem caranguejos, blocos lentos
  - Round 2: caranguejos aparecem
  - Round 3: gansos aparecem
  - Round 4: mariscos aparecem, blocos mais rápidos
  - Round 5: todos os inimigos, blocos MUITO rápidos, temperatura cai 1.5°/s

### Game Modes (selectable in lobby)

1. **Arctic Race** (padrão)
   - Best of 5 rounds, todos os inimigos progressivos
   - Roubo de blocos ativo
   - Temperatura compartilhada

2. **Blizzard**
   - 1 round longo (temperatura começa em 60°, cai 0.5°/s)
   - TODOS os inimigos desde o início
   - Iglu precisa de 20 peças
   - Épico e caótico

3. **Peaceful Build**
   - SEM roubo de blocos (pisar em azul do oponente = nada acontece)
   - Apenas corrida pura: quem constrói primeiro
   - Pra quem quer competir sem sabotagem

### Game State (synced via DataChannel)
- Bailey 1: position (x, row), facing, jump state, alive
- Bailey 2: position (x, row), facing, jump state, alive
- Ice blocks: array per row of {position_x, state (white/blue_p1/blue_p2)}
- Igloos: {p1_pieces, p2_pieces, p1_complete, p2_complete}
- Enemies: array of {type, position, row, state}
- Fish: array of {position, row, collected_by}
- Temperature
- Scores + round number
- Game phase: `waiting` → `countdown` → `building` → `round_end` → ... → `finished`

### Authority Model
- **Host** é autoritativo para: block state changes, steal resolution, enemy collisions, fish collection, igloo completion
- Block movement é determinístico (speed + direction per row)
- Cada jogador envia: position, jump events
- Host valida: block landing (which block, state change), enemy contact, fish collection
- Host broadcast: block states, bailey positions, igloo progress, enemies, temperature
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Background: azul-gelo claro (céu ártico)
- Água: azul escuro com ondulação suave
- Shore (plataforma superior): branco/cinza (neve e gelo)
- Blocos de gelo brancos: brancos brilhantes com textura cristalina
- Blocos azul-P1: azul com tint verde (indicação de P1)
- Blocos azul-P2: azul com tint ciano (indicação de P2)
- Bailey P1: casaco/gorro verde brilhante
- Bailey P2: casaco/gorro ciano brilhante
- Urso polar: branco com olhos pretos
- Caranguejos: vermelhos
- Gansos: brancos com asas animadas
- Mariscos: roxo, animação abre/fecha
- Peixes: laranja brilhante
- Iglu P1: gelo com tint verde, construção visual bloco a bloco
- Iglu P2: gelo com tint ciano, construção visual bloco a bloco
- Roubo de bloco: flash vermelho no iglu que perdeu peça + flash dourado no que ganhou
- Queda na água: splash azul + partículas
- Termômetro: grande, visível, cor muda (verde→amarelo→vermelho com a temperatura)
- CRT scanlines + glow

### Sound Effects
- Pulo: boing satisfatório
- Pouso em bloco: thud suave no gelo
- Bloco pisado (branco→azul): pling cristalino + peça de iglu (construction sound)
- Bloco roubado: pling cristalino + alarm no oponente (peça roubada!)
- Próprio bloco desfeito: buzz de erro
- Peixe coletado: splash + pling bônus
- Queda na água: splash grande + "brrr!"
- Urso polar rugindo: growl grave (quando passa perto)
- Caranguejo: click-click rápido
- Ganso: squawk (quando passa voando)
- Marisco: snap (quando fecha)
- Iglu ganhando peça: building block sound (satisfatório!)
- Iglu perdendo peça: crumble sound (devastador!)
- Iglu completo: fanfarra gelada + porta abrindo
- Entrando no iglu: door close + warmth sound + bônus contando
- Temperatura baixa (10°): vento uivando + alarm
- Temperatura zero: congelamento + shatter
- Vitória: fanfarra ártica + fogos de artifício (aurora boreal sound)

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Medium | Blocos flutuantes, pulo com arco, timing de pouso |
| Networking | Medium | Block states (compartilhados) + 2 baileys + enemies |
| Rendering | Medium | Blocos animados, 4 fileiras, iglus construindo, inimigos variados |
| Input | Low | Horizontal movement + jump up/down (4 inputs) |
| Game logic | Medium-High | 3 estados de bloco, roubo, iglu peças, temperatura, inimigos |
| **Overall** | **Medium** | Sistema de blocos compartilhados é o core challenge |

## Fun Factor

- Construir iglu bloco a bloco é INCRIVELMENTE satisfatório (visual + som)
- Ver o oponente ROUBAR seu bloco e seu iglu perder uma peça = RAIVA cômica
- Decisão constante: "piso no branco seguro ou arrisco roubar o azul dele?"
- Timing de pulo nos blocos flutuantes é skill pura
- Inimigos variados criam caos imprevisível (caranguejo no bloco que você quer!)
- Marisco que fecha JUSTO quando você ia pular = momento de comédia
- Temperatura caindo adiciona urgência constante
- Completar o iglu primeiro e ver o oponente lutando com 3 peças = triunfo
- O visual ártico é lindo e totalmente diferente dos outros jogos do catálogo
- Som de peça de iglu construindo é dos mais satisfatórios possíveis
- "Ele roubou meu bloco MAS tem um caranguejo lá" = schadenfreude
