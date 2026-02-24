# Game Discovery: Fishing Derby

## Identity

| Field | Value |
|-------|-------|
| **Name** | Fishing Derby |
| **Original** | Activision, 1980 (criado por David Crane) |
| **Genre** | Strategy / Action |
| **Players** | 2 (simultaneous, competitive) |
| **Our ID** | `hex_fishing` |

## Why This Game

Fishing Derby é a prova de que David Crane era um gênio do game design. Um lago, dois
pescadores, seis fileiras de peixes e um tubarão faminto. A mecânica de profundidade-vs-risco
é brilhante: peixes no fundo valem 3x mais, mas o tubarão patrulha justamente lá embaixo.
Você VÊ o oponente puxando um peixe gordo de 6 lbs e precisa decidir: ir pro seguro (2 lbs
rápido) ou arriscar nas profundezas? O jogo é "amazingly addictive with two players" segundo
a comunidade AtariAge. Totalmente diferente de qualquer outro jogo no catálogo — é estratégia,
paciência e timing numa embalagem minimalista.

## Original Mechanics

### Core Loop
1. Dois pescadores sentados em docas opostas sobre um lago
2. Cada jogador controla uma linha de pesca com isca na ponta
3. Mover a isca até a boca de um peixe para fisgar
4. Puxar o peixe para a superfície (reeling)
5. Cuidado com o tubarão — ele come seu peixe se tocar nele
6. Primeiro a 99 lbs de peixe vence

### Lago e Peixes
- 6 fileiras horizontais de peixes, nadando em direções alternadas
- Cada fileira tem 4-6 peixes nadando continuamente
- Profundidade determina o valor:
  - **Fileiras 1-2** (superfície): peixes de 2 lbs — lentos, fáceis de pegar
  - **Fileiras 3-4** (meio): peixes de 4 lbs — velocidade média
  - **Fileiras 5-6** (fundo): peixes de 6 lbs — rápidos, perto do tubarão
- Peixes se movem horizontalmente, "wrappando" nas bordas
- Quando um peixe é pescado, ele é reposto na mesma fileira

### Linha de Pesca
- Jogador move a linha em 4 direções (cima, baixo, esquerda, direita)
- A isca fica na ponta da linha
- Linha é visual: fio que vai do pescador (doca) até a isca
- Para fisgar: posicionar a isca perto da boca do peixe
- Dificuldade A: isca precisa tocar exatamente a boca
- Dificuldade B: proximidade mais generosa

### Fisgando e Puxando (Reeling)
- Quando isca toca um peixe: peixe é fisgado automaticamente
- Peixe fisgado começa a subir lentamente em direção à superfície
- Apertar botão de ação: puxa mais rápido (reel)
- Soltar botão: peixe sobe devagar
- Durante o reel, jogador pode mover a linha horizontalmente (esquivar do tubarão!)
- Peixe só é contabilizado quando chega à superfície (doca)
- **Regra crucial**: quando ambos jogadores fisgam ao mesmo tempo, só o PRIMEIRO pode dar reel — o outro espera

### Tubarão
- Um único tubarão patrulha horizontalmente nas fileiras inferiores
- Move-se de um lado ao outro continuamente
- Se o peixe que você está puxando TOCAR no tubarão em qualquer ponto: tubarão come o peixe instantaneamente
- O peixe desaparece, volta pra fileira, e você perdeu o tempo investido
- Tubarão é mais perigoso para peixes do fundo (mais tempo de exposição)
- Tubarão não come peixes que estão nadando livres — só peixes na sua linha
- O tubarão adiciona risco real à estratégia "ir fundo pelo peixe gordo"

### Estratégia do Original
- Pescar no fundo é arriscado mas eficiente (6 lbs vs 2 lbs)
- Pescar na superfície é seguro mas lento
- Mover a linha horizontalmente durante o reel para esquivar do tubarão
- Observar de qual lado os peixes começam (seu dock = repõe do seu lado)
- Timing: esperar o tubarão passar antes de iniciar o reel

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 34 lbs   FISHING DERBY   P2: 28 lbs    │
│┌────────────────────────────────────────────┐│
││  🧑‍🎣                              🧑‍🎣      ││
││  ╔══DOCK══╗    ~~~~~~~~    ╔══DOCK══╗      ││
││~~╝~~~~~~~~╚~~~~~~~~~~~~~~~~╝~~~~~~~~╚~~~~~ ││
││    │                              │        ││
││  ><>  ><>  │  ><>  ><>  ><>    ><>  │      ││  2 lbs
││            │                       │       ││
││  <><  <><  │    <><  <><  <><   <><│       ││  2 lbs
││            │                       │       ││
││  ><>  ><>  ☗  ><>  ><>  ><>  ><>   │       ││  4 lbs
││            │                       │       ││
││  <><  <><  │    <><  <><  <><  <><         ││  4 lbs
││            │                               ││
││  ><>  ><>  ☗  ><>  ><>  ><>  ><>           ││  6 lbs
││                                            ││
││  <><  🦈→→  <><  <><  <><  <><  <><        ││  6 lbs
││                                            ││
│└────────────────────────────────────────────┘│
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘
```

Legenda:
- 🧑‍🎣 = pescadores nas docas
- │ = linha de pesca (vertical com isca na ponta)
- ☗ = isca (ponta da linha)
- ><> e <>< = peixes (nadando em direções opostas por fileira)
- 🦈 = tubarão patrulhando no fundo
- ~~ = água (superfície)

### Lago (Arena)
- Vista lateral do lago (corte transversal)
- Superfície da água no topo com ondulação visual
- Duas docas nos cantos superiores (P1 esquerda, P2 direita)
- 6 fileiras de peixes abaixo da superfície
- Profundidade indicada por gradiente de cor (claro → escuro)
- Fundo do lago na base

### Pescadores (sprites)

```
Pescador na doca:

    ╭─╮
    │☻│ ← chapéu de pesca
   ╭┴─┴╮
   │   │╮ ← vara de pesca (estende pra baixo)
   ╰───╯│
        │  ← linha
        │
        ☗  ← isca/anzol
```

- Player 1 (doca esquerda): verde
- Player 2 (doca direita): ciano
- Vara de pesca se inclina na direção do movimento horizontal
- Animação de "puxada" quando faz reel (vara curva)

### Peixes (sprites por fileira)

```
Peixe pequeno (2 lbs):    Peixe médio (4 lbs):    Peixe grande (6 lbs):
    ><>                      ><==>                    ><====>
    ~6px                     ~10px                    ~14px
```

- Fileiras 1-2: peixes pequenos, verde-claro/amarelo
- Fileiras 3-4: peixes médios, laranja
- Fileiras 5-6: peixes grandes, vermelho/dourado
- Peixes nadam horizontalmente com animação de barbatana
- Cada fileira alterna direção (esquerda↔direita)
- Peixes fisgados: sprite muda (boca aberta, tremendo na linha)

### Tubarão (sprite)

```
Tubarão:
   ╱▔▔▔╲
  ▕ ● ▔▔▕▬▬▷    ← barbatana dorsal visível
   ╲▁▁▁╱
   ~20px de largura
```

- Grande, cinza escuro com barbatana dorsal proeminente
- Patrulha horizontalmente nas fileiras 4-6
- Animação de nado: barbatana ondulando, cauda mexendo
- Quando come peixe: boca abre, flash vermelho, peixe desaparece
- Olho vermelho brilhante (ameaçador)

### Controls
- **Arrow keys** — mover isca (cima, baixo, esquerda, direita)
- **Space** — reel (puxar peixe mais rápido quando fisgado)
- **WASD + Shift** — alternativo

### Mecânica de Pesca Detalhada

#### Fase 1: Posicionamento
- Jogador move a isca livremente pelo lago
- Isca desce/sobe com as setas
- Isca se move horizontalmente (mas limitada ao "alcance" da doca)
- P1 cobre a metade esquerda + centro
- P2 cobre a metade direita + centro
- Zona central é disputada por ambos

#### Fase 2: Fisgando
- Isca toca na boca de um peixe = FISGOU!
- Som de "tug" + vibração visual
- Peixe fica preso na linha e para de nadar
- A partir daqui, o peixe sobe automaticamente (devagar)

#### Fase 3: Reeling
- Segurar Space = puxar peixe mais rápido
- Soltar = subida lenta (padrão)
- Durante o reel, mover esquerda/direita para desviar do tubarão
- O peixe segue a linha (move horizontalmente com você)
- Se o peixe tocar no tubarão durante a subida: COMIDO!
- Se o peixe chega à superfície: PESCOU! Pontos adicionados

#### Fase 4: Reset
- Após pescar (ou perder pro tubarão): isca volta à doca
- Pode imediatamente lançar de novo
- Peixe pescado é reposto na mesma fileira (do lado da doca de origem)

### Regra de Prioridade de Reel
- Se ambos jogadores fisgam ao mesmo tempo: primeiro a fisgar tem prioridade
- Jogador com prioridade pode dar reel normalmente
- Outro jogador: peixe sobe na velocidade mínima, sem reel boost
- Prioridade libera quando o peixe é pescado ou comido
- Isso incentiva pescar rápido para garantir prioridade

### Tubarão Behavior (detalhado)
- Patrulha horizontal: ida e volta no fundo do lago
- Velocidade: constante, moderada
- Caminho: fileiras 4-6 (nunca sobe acima da fileira 3)
- Quando um peixe fisgado está próximo: tubarão ACELERA na direção
- Hitbox: qualquer parte do peixe toca qualquer parte do tubarão = comido
- Após comer: tubarão faz "smirk" visual e volta a patrulhar
- O tubarão NÃO tem preferência por jogador — é ameaça igual pra ambos

### Scoring e Vitória
- Peixes das fileiras 1-2: 2 lbs cada
- Peixes das fileiras 3-4: 4 lbs cada
- Peixes das fileiras 5-6: 6 lbs cada
- Primeiro a 99 lbs vence
- Se ninguém chega a 99 em 5 minutos: quem tem mais lbs vence
- Exibição: peso total de cada jogador no HUD superior

### Game State (synced via DataChannel)
- Line 1: position (x, y), hooked fish (nil/fish_id), reel state
- Line 2: position (x, y), hooked fish (nil/fish_id), reel state
- Fish grid: array of {row, position_x, alive flag, hooked_by}
- Shark: position (x), direction, speed state (normal/hunting)
- Scores (lbs) + reel priority holder
- Game phase: `waiting` → `countdown` → `fishing` → `finished`

### Authority Model
- **Host** é autoritativo para: fish hooking, shark collision, scoring, reel priority
- Fish positions são determinísticas (seed compartilhado, spawn patterns)
- Cada jogador envia: line position, reel events
- Host valida: hook proximity, shark collision, reel priority
- Host broadcast: fish states, shark position, scores, line positions
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Background: gradiente azul (claro na superfície → escuro no fundo)
- Superfície: ondas animadas (azul-claro, reflexos brancos)
- Docas: marrom/madeira nos cantos superiores
- Pescadores: sprites laterais com chapéu e vara
- Player 1: verde (chapéu verde, vara verde)
- Player 2: ciano (chapéu azul, vara azul)
- Linhas de pesca: fio fino branco conectando vara à isca
- Isca: ponto brilhante (amarelo)
- Peixes superfície (2 lbs): amarelo/verde-claro, pequenos
- Peixes meio (4 lbs): laranja, médios
- Peixes fundo (6 lbs): vermelho/dourado, grandes, brilhantes
- Tubarão: cinza escuro, olho vermelho, barbatana proeminente
- Peixe comido: flash vermelho + partículas de bolhas
- Peixe pescado: flash dourado + splash na superfície
- Bolhas decorativas subindo aleatoriamente
- Algas no fundo (decorativo, não afeta gameplay)
- CRT scanlines + glow (efeito subaquático)

### Sound Effects
- Isca descendo: bubble suave (bolhas)
- Peixe fisgado: "tug!" (puxada + vibração)
- Reel: som de molinete girando (loop enquanto segura Space)
- Peixe subindo: splash leve ritmado
- Tubarão se aproximando: heartbeat grave crescente (tensão!)
- Tubarão come peixe: CHOMP grave + splash violento
- Peixe pescado com sucesso: splash alegre + pling de pontos
- Peixe reposto na fileira: plop suave
- Água ambiente: loop suave de ondas
- Prioridade de reel ganho: click satisfatório
- Timer warning (30s): ticking suave
- Vitória: fanfarra pesqueira + splash triunfal

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low | Linhas verticais, peixes lineares, sem física complexa |
| Networking | Low-Medium | 2 linhas + fish grid + shark + priority state |
| Rendering | Medium | Ambiente subaquático, 6 fileiras de peixes, animações |
| Input | Low | 4 direções + 1 botão (reel) |
| Game logic | Medium | Priority system, shark AI, hook detection, scoring |
| **Overall** | **Low-Medium** | Lógica simples com visual rico e dinâmica estratégica |

## Fun Factor

- Risco vs recompensa é VISCERAL: ir pro fundo pelo peixe de 6 lbs com o tubarão rondando
- O tubarão comendo seu peixe é devastador — "NÃOOO ELE COMEU MEU PEIXE!"
- Ver o oponente pescando tranquilo enquanto você luta com o tubarão = frustração cômica
- Estratégia real: pescar rápido na superfície vs arriscar no fundo
- Regra de prioridade de reel adiciona corrida pra fisgar primeiro
- Esquivar o tubarão movendo a linha horizontalmente = tensão pura
- Partidas têm arco narrativo: começo calmo → meio tenso → final frenético
- Totalmente diferente de qualquer outro jogo no catálogo (zero ação, pura estratégia)
- O ambiente subaquático é visualmente único e relaxante (até o tubarão aparecer)
