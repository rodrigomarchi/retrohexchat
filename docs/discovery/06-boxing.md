# Game Discovery: Boxing

## Identity

| Field | Value |
|-------|-------|
| **Name** | Boxing |
| **Original** | Activision, 1980 |
| **Genre** | Sports / Fighting |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_boxing` |

## Why This Game

Boxing é um dos jogos mais icônicos da Activision para o Atari 2600. Vista top-down, dois
boxeadores, mecânica de distância que recompensa agressividade calculada. A genialidade está
na regra: socos de perto valem mais que socos de longe. Isso cria um push-and-pull constante
— você QUER chegar perto pro nocaute, mas chegar perto te expõe. Perfeito para duelos rápidos
no chat. O jogo original é consistentemente listado no top 10 de multiplayer do Atari 2600
pela comunidade retro.

## Original Mechanics

### Core Loop
1. Dois boxeadores se enfrentam numa arena vista de cima
2. Cada jogador move seu boxeador em 8 direções e soca
3. Socos que conectam marcam pontos baseados na distância
4. Socos de perto (corpo-a-corpo) valem mais pontos
5. Primeiro a 100 pontos derruba o oponente (KO!)
6. Se ninguém chega a 100, quem tem mais pontos ao fim do timer vence

### Movimento
- 8 direções (cima, baixo, esquerda, direita e diagonais)
- Ambos boxeadores se movem simultaneamente
- Velocidade constante — não há dash ou esquiva especial
- Arena é um retângulo fechado, não dá pra sair dos limites
- Boxeadores NÃO se atravessam — colisão corpo-a-corpo empurra ambos

### Sistema de Soco
- Cada boxeador tem dois braços (esquerdo e direito)
- Socos são rápidos e têm alcance curto
- Braço se estende na direção que o boxeador está mirando
- Um soco conecta quando o punho toca o corpo do oponente
- Após socar, há um breve cooldown antes do próximo soco
- Não há bloqueio nem defesa — a defesa é o MOVIMENTO

### Pontuação por Distância (mecânica central)
- **Soco de longe** (alcance máximo): 1 ponto
- **Soco médio**: 2 pontos
- **Soco de perto** (corpo-a-corpo): 3 pontos
- Isso incentiva jogo agressivo mas calculado

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 47       BOXING        P2: 32    1:23   │
│┌────────────────────────────────────────────┐│
││                                            ││
││                                            ││
││         ╔══╗                               ││
││         ║P1║──╸    ╺──║P2║                 ││
││         ╚══╝           ╚══╝                ││
││                                            ││
││                                            ││
││                                            ││
│└────────────────────────────────────────────┘│
│  ██████████░░░░░░░░  ██████░░░░░░░░░░░░░░░░ │
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘
```

Legenda do HUD inferior:
- Barras de score preenchidas proporcionalmente ao progresso até 100
- Quando um jogador chega a 100, a barra pisca e aparece "KO!"

### Arena
- Retângulo fechado com "cordas" (bordas) visíveis
- Sem obstáculos internos — arena limpa
- Tamanho proporcional para que travessia leve ~2 segundos
- Background escuro simulando ring de boxe visto de cima

### Boxeadores (sprites top-down)

```
Sprite de boxeador (vista de cima):

   ┌──┐
╺──┤  ├──╸    ← braços (esquerdo e direito)
   └──┘

Quando soca (braço direito estendido):

   ┌──┐
╺──┤  ├──────╸
   └──┘
```

- Corpo: retângulo pequeno (8x8 pixels equivalente)
- Braços: linhas que se estendem quando socam
- Player 1: verde (corpo) com braços verde-claro
- Player 2: ciano (corpo) com braços ciano-claro
- Hit flash: branco brilhante no impacto

### Controls
- **Arrow keys** — mover boxeador (8 direções)
- **Space** — socar
- **WASD** — movimento alternativo
- **Shift** — soco alternativo

### Mecânica de Soco Detalhada
- Soco se estende na direção do último movimento
- Se parado, soco vai pra frente (direção que o boxeador está "encarando")
- Hitbox do punho: pequeno ponto na ponta do braço estendido
- Duração do soco: ~150ms (braço estica e retrai)
- Cooldown entre socos: ~200ms
- Ambos podem socar simultaneamente (trocação!)
- Se ambos conectam ao mesmo tempo, ambos ganham pontos

### Game State (synced via DataChannel)
- Boxer 1: position (x, y), facing direction, punch state (idle/punching/cooldown), arm (left/right)
- Boxer 2: position (x, y), facing direction, punch state, arm
- Scores (0-100 cada)
- Timer
- Game phase: `waiting` → `countdown` → `fighting` → `ko` / `timeout` → `finished`

### Authority Model
- **Host** é autoritativo para detecção de colisão de socos e pontuação
- Cada jogador envia: posição, direção, eventos de soco
- Host valida hits, calcula distância, atribui pontos
- Host broadcast: posições, punch states, scores
- Guest renderiza com interpolação

### Mecânica de KO
- Quando um jogador atinge 100 pontos: KO!
- Animação de knockdown: boxeador perdedor "cai" (sprite muda)
- Câmera treme levemente
- Contagem de 10 aparece na tela (visual, não é mecânica — é celebração)
- Se timer acaba sem KO: vitória por pontos (decision)

### Rounds
- Best of 3 rounds
- Cada round: 2 minutos
- Entre rounds: breve tela de placar
- Reset de posições e scores a cada round

### Visual Style (Retro CRT)

- Background: marrom escuro/preto (ring de boxe)
- Bordas do ring: linhas brancas (cordas)
- Boxeadores: sprites minimalistas top-down
- Player 1: verde brilhante
- Player 2: ciano brilhante
- Socos: braços que se estendem com brilho
- Impacto: flash branco + partículas de "suor"
- KO: tela pisca, texto grande "KO!" no centro
- Score bars: barras de progresso até 100 no HUD inferior
- Scanlines e CRT glow consistentes com os outros jogos

### Sound Effects
- Movimento: passos suaves (taps ritmados)
- Soco no ar (miss): swoosh rápido
- Soco conectado (perto): THWACK grave e satisfatório
- Soco conectado (longe): tap leve
- KO: sino de boxe + crowd roar
- Contagem: "ding" a cada número
- Round start: sino de boxe (ding ding ding)
- Round end: sino longo
- Timer warning (15s): ticking acelerado

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low | Movimento 8-dir, colisão AABB simples |
| Networking | Low | 2 posições + punch states + scores |
| Rendering | Low-Medium | Sprites top-down simples, braços animados |
| Input | Low | Movimento + 1 botão de soco |
| Game logic | Medium | Distância de soco, KO system, rounds |
| **Overall** | **Low-Medium** | Mecânicas simples com profundidade emergente |

## Fun Factor

- Intensidade imediata — não tem tempo morto, é trocação pura
- Mecânica de distância cria mind games constantes (avançar ou recuar?)
- KO é incrivelmente satisfatório — 100 pontos de buildup até o momento
- Rounds curtos mantêm a energia (2 minutos = zero downtime)
- "Trocação" (ambos conectando simultaneamente) gera momentos hilários
- Skill ceiling surpreendente: jogadores bons usam spacing e timing
- Rivalidades naturais — perfeito pra "rematch!" no chat
