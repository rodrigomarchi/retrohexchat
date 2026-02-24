# Game Discovery: Demons to Diamonds

## Identity

| Field | Value |
|-------|-------|
| **Name** | Demons to Diamonds |
| **Original** | Atari, 1982 (Nick "Sandy" Sanderson & Alan J. Murphy) |
| **Genre** | Shooter / Action |
| **Players** | 2 (simultaneous, competitive) |
| **Our ID** | `hex_demons` |

## Why This Game

Demons to Diamonds é o shooter mais inteligente do Atari 2600. Dois jogadores atiram de
lados OPOSTOS da tela — P1 de baixo pra cima, P2 de cima pra baixo. Demônios da SUA cor
valem pontos, mas atirar no demônio da cor ERRADA cria um CRÂNIO que atira de volta em ambos.
Diamantes bônus podem ser roubados pelo oponente. É um shooter onde a PRECISÃO importa mais que
velocidade — atirar errado LITERALMENTE cria ameaças. Essa mecânica de "friendly fire gera
inimigos" é genial e não existe em nenhum outro jogo do catálogo. O modo 2-player é descrito
como "the superior mode" pela comunidade retro.

## Original Mechanics

### Core Loop
1. P1 controla um laser na BASE da tela (atira pra CIMA)
2. P2 controla um laser no TOPO da tela (atira pra BAIXO)
3. Demônios cruzam a tela horizontalmente em várias fileiras
4. Acertar demônio da SUA cor: demônio vira diamante (+pontos)
5. Acertar diamante: pontos bônus
6. Acertar demônio da cor ERRADA: demônio vira CRÂNIO (atira de volta!)
7. Crânio atinge jogador = perde vida
8. Quem tiver mais pontos quando o oponente perder todas as vidas vence

### Bases Laser
- P1: base na borda inferior, move horizontalmente, atira pra cima
- P2: base na borda superior, move horizontalmente, atira pra baixo
- Lasers viajam verticalmente na direção do oponente
- Segurar o botão: laser se ESTENDE mais longe
- Soltar o botão: laser para naquele ponto
- Laser desaparece ao atingir demônio, crânio ou borda

### Demônios
- Cruzam horizontalmente em 3-4 fileiras centrais
- Cada demônio tem uma COR (verde ou azul, matching com cada jogador)
- Demônios se movem em grupo, velocidade aumenta por wave
- Fileiras superiores são mais acessíveis para P2, inferiores para P1
- Fileiras centrais são disputadas

### Sistema de Cores (mecânica central)
- P1 tem cor verde → deve atirar em demônios VERDES
- P2 tem cor azul/ciano → deve atirar em demônios AZUIS
- Acertar demônio da SUA cor = sucesso → demônio vira DIAMANTE
- Acertar demônio da cor do OPONENTE = erro → demônio vira CRÂNIO
- Isso cria um dilema: atirar rápido e arriscar errar ou mirar com cuidado?

### Diamantes
- Aparecem quando um demônio é destruído corretamente
- Pulsam brevemente no lugar do demônio
- Valem 10-80 pontos (baseado na distância da fileira)
- AMBOS jogadores podem atirar no diamante (corrida pelo bônus!)
- Diamante desaparece após ~2 segundos se não for atingido

### Crânios
- Aparecem quando um jogador acerta demônio da cor ERRADA
- Crânio é HOSTIL: atira projéteis em AMBAS direções (cima E baixo)
- Projétil do crânio atinge jogador = perde 1 vida
- Crânio NÃO pode ser destruído — desaparece sozinho após ~3 segundos
- Crânios em waves avançadas se MOVEM horizontalmente
- É a punição por atirar errado — e pode afetar AMBOS jogadores!

### Pontuação por Distância
- Demônio na fileira mais próxima: 1 ponto
- Demônio na fileira mais longe: 8 pontos
- Diamante na fileira mais próxima: 10 pontos
- Diamante na fileira mais longe: 80 pontos
- Risco/recompensa: mirar longe vale mais, mas laser viaja mais tempo

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 230    DEMONS TO DIAMONDS    P2: 185    │
│┌────────────────────────────────────────────┐│
││      ◄════P2 LASER BASE════►               ││
││                                            ││
││         ↓         ↓                        ││  P2 atira pra baixo
││                                            ││
││   😈  💎  😈  😈  💀  😈  😈              ││  ← fileira 4 (longe de P1)
││                                            ││
││   😈  😈  😈  💎  😈  😈  😈              ││  ← fileira 3
││                                            ││
││   😈  😈  😈  😈  😈  💎  😈              ││  ← fileira 2
││                                            ││
││   😈  😈  💀  😈  😈  😈  😈              ││  ← fileira 1 (longe de P2)
││                                            ││
││         ↑         ↑                        ││  P1 atira pra cima
││                                            ││
││      ◄════P1 LASER BASE════►               ││
│└────────────────────────────────────────────┘│
│  ♥♥♥ Player 1 (green)  ♥♥♥ Player 2 (cyan)  │
└──────────────────────────────────────────────┘
```

Legenda:
- P1 LASER BASE = base inferior (move horizontalmente, atira pra cima)
- P2 LASER BASE = base superior (move horizontalmente, atira pra baixo)
- 😈 = demônios (cor varia: verde = alvo de P1, ciano = alvo de P2)
- 💎 = diamantes (bônus, ambos podem pegar)
- 💀 = crânios (ameaça, atiram em ambas direções)
- ↑↓ = direção dos lasers

### Arena
- Campo de batalha retangular vertical
- P1 na borda inferior
- P2 na borda superior
- 4 fileiras de demônios no centro (cruzando horizontalmente)
- Fileiras espaçadas uniformemente entre as duas bases
- Distância da fileira ao jogador determina pontuação

### Bases Laser (sprites)

```
P1 Base (inferior, atira pra cima):

         ╱╲
    ╔═══╡  ╞═══╗     ← canhão apontando pra cima
    ╚═══════════╝     ← base deslizante
    ▔▔▔▔▔▔▔▔▔▔▔▔     ← borda inferior

P2 Base (superior, atira pra baixo):

    ▁▁▁▁▁▁▁▁▁▁▁▁     ← borda superior
    ╔═══════════╗     ← base deslizante
    ╚═══╡  ╞═══╝     ← canhão apontando pra baixo
         ╲╱
```

- Base P1: verde, desliza na borda inferior
- Base P2: ciano, desliza na borda superior
- Largura da base: ~10% da tela (hitbox para projéteis de crânio)
- Canhão: aponta na direção do disparo
- Animação de tiro: flash + recuo do canhão

### Laser (projétil)

```
Laser curto (tap rápido):      Laser longo (segurar botão):

         │                              │
         │                              │
         ▲                              │
                                        │
                                        │
                                        │
                                        ▲
```

- Laser é uma linha vertical brilhante
- Tap rápido: laser curto (alcança 1-2 fileiras)
- Segurar botão: laser se estende progressivamente
- Soltar botão: laser para de estender e desaparece
- Um laser na tela por jogador de cada vez
- Laser desaparece ao atingir: demônio, crânio, diamante ou borda
- Cor do laser = cor do jogador (verde P1, ciano P2)

### Demônios (sprites)

```
Demônio verde (alvo P1):    Demônio ciano (alvo P2):
    ╭───╮                      ╭───╮
    │ ◕◕│                      │ ◕◕│
    │ ▽ │                      │ ▽ │
    ╰─┬─╯                      ╰─┬─╯
     ╱│╲                        ╱│╲
    ~ verde ~                  ~ ciano ~
```

- Sprites ~12x14 px
- Cor clara e distinta (verde vs ciano)
- Animação: flutuam suavemente, braços/asas ondulando
- Movem-se horizontalmente em grupo (cada fileira é um grupo)
- Velocidade aumenta a cada wave
- Wrap horizontal (saem de um lado, entram do outro)

### Diamantes (sprites)

```
Diamante:
    ◇
   ◇◆◇     ← brilhando e pulsando
    ◇
```

- Brancos/amarelos, brilhantes, pulsando
- Aparecem onde o demônio foi destruído
- Duram ~2.5 segundos antes de desaparecer
- Ambos jogadores podem atirar nele (corrida!)

### Crânios (sprites)

```
Crânio:                    Crânio atirando:
   ╭───╮                     ╭───╮
   │ X X│                    │ X X│
   │ ▽▽▽│                    │ ▽▽▽│
   ╰───╯                     ╰─┬─╯
                               ●↑  ← projétil pra cima
                               ●↓  ← projétil pra baixo
```

- Vermelho escuro, ameaçadores
- Aparecem onde o demônio errado foi atingido
- Ficam estacionários (waves iniciais) ou se movem (waves avançadas)
- Atiram projéteis em AMBAS direções a cada ~1.5s
- Projéteis do crânio são vermelho brilhante
- Desaparecem após ~3 segundos
- NÃO podem ser destruídos por lasers

### Controls
- **Left / Right arrows** — mover base horizontalmente
- **Space** — atirar laser (segurar = laser mais longo)
- **A / D** — movimento alternativo
- **Shift** — tiro alternativo

### Mecânica de Laser Detalhada

#### Disparo
- Apertar Space: laser começa a se estender na direção do oponente
- Enquanto segura Space: laser cresce progressivamente
- Velocidade de extensão: moderada (~tela completa em 1s)
- Soltar Space: laser para e desaparece imediatamente
- Impacto com demônio/crânio/diamante: laser para e desaparece

#### Alcance Estratégico
- Fileiras próximas: fácil acertar, poucos pontos
- Fileiras distantes: mais pontos, mas laser demora mais pra chegar
- Enquanto o laser está estendendo, a base NÃO pode atirar de novo
- Isso cria janelas de vulnerabilidade (sem laser = sem defesa contra crânios)

#### Precisão Horizontal
- Laser é fino verticalmente (~2px de largura)
- Demônios estão se movendo horizontalmente
- Precisa alinhar a base com o demônio E manter o laser estendendo até alcançá-lo
- Leading shots: atirar um pouco à frente do demônio em movimento

### Waves
- Cada wave traz um novo grupo de demônios
- Wave 1: demônios lentos, proporção equilibrada de cores
- Wave 2+: demônios mais rápidos
- Wave 5+: crânios espontâneos aparecem nas bordas
- Wave 7+: crânios se movem horizontalmente
- Waves continuam até um jogador perder todas as vidas
- Entre waves: breve pausa (~2s) com contagem de wave

### Vidas e Game Over
- Cada jogador começa com 3 vidas
- Projétil de crânio atinge base = -1 vida
- Em algumas variações: laser do oponente pode atingir SUA base = -1 vida
- Jogador perde todas as vidas = game over pra ele
- Vencedor: jogador sobrevivente OU maior pontuação se ambos sobrevivem após 10 waves
- Vidas restantes no final: cada vida = bônus de pontos

### Game Modes (selectable in lobby)

1. **Classic** (padrão)
   - Lasers NÃO atingem a base do oponente
   - Ameaça vem apenas dos crânios
   - Foco em precisão e velocidade de coleta

2. **Crossfire**
   - Lasers PODEM atingir a base do oponente (tira vida!)
   - Demônios se tornam escudos naturais (bloqueiam lasers)
   - Atirar se torna arriscado — seu laser pode atingir o oponente E vice-versa
   - Muito mais agressivo e estratégico

3. **Diamond Rush**
   - Diamantes valem 3x pontos
   - Demônios valem metade dos pontos
   - Foco em criar diamantes (precisão) e coletá-los antes do oponente

### Game State (synced via DataChannel)
- Base 1: position_x, lives, laser state (active, length, position)
- Base 2: position_x, lives, laser state
- Demons: array of {row, position_x, color, state (alive/diamond/skull), timer}
- Skull projectiles: array of {position_x, position_y, direction}
- Scores + wave number
- Game phase: `waiting` → `countdown` → `wave_start` → `playing` → `wave_clear` → ... → `finished`

### Authority Model
- **Host** é autoritativo para: laser-demon collision, scoring, skull behavior, wave progression
- Demon positions são determinísticas (seed + wave number)
- Cada jogador envia: base position, laser events (fire/release)
- Host valida: hits, color matching, diamond collection, skull hits
- Host broadcast: demon states, scores, lives, skull projectiles
- Guest renderiza com interpolação

### Visual Style (Retro CRT)

- Background: preto profundo com estrelas sutis (vibe espacial)
- Bases: brilhantes nas cores dos jogadores (verde P1, ciano P2)
- Lasers: linhas brilhantes na cor do jogador com glow
- Demônios verdes: verde brilhante, animados
- Demônios cianos: ciano brilhante, animados
- Diamantes: branco/amarelo, brilho pulsante forte
- Crânios: vermelho escuro, olhos piscando, ameaçadores
- Projéteis de crânio: pontos vermelhos brilhantes
- Hit em demônio certo: explosão colorida → diamante aparece com flash
- Hit em demônio errado: distorção visual → crânio aparece com efeito sinistro
- Diamante coletado: burst dourado + estrelas
- Base atingida: flash vermelho + shake
- Wave clear: todos os elementos fazem "pop" sequencial
- CRT scanlines + glow intenso

### Sound Effects
- Laser disparando: zap crescente (pitch sobe conforme estende)
- Laser retraindo: zap descendente rápido
- Hit em demônio correto: shatter satisfatório + pling
- Hit em demônio errado: buzz grave + som sinistro (erro!)
- Diamante aparecendo: chime cristalino
- Diamante coletado: pling brilhante + coins
- Crânio aparecendo: riso maligno curto
- Crânio atirando: pew-pew duplo (pra cima e pra baixo)
- Projétil de crânio atingindo base: explosion + alarm
- Wave clear: cascata ascendente de notes
- Perda de vida: descending tone + alarm
- Game over: requiem curto
- Vitória: fanfarra triunfal

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low | Lasers lineares, projéteis retos |
| Networking | Medium | Demons + skulls + projectiles + 2 lasers = muitas entities |
| Rendering | Medium | Sprites variados, lasers extensíveis, partículas abundantes |
| Input | Low | Horizontal movement + fire/hold |
| Game logic | Medium-High | Color matching, demônio→diamante/crânio, waves, vidas, 3 modos |
| **Overall** | **Medium** | Logic-heavy mas physics-light |

## Fun Factor

- "Atirar errado cria ameaças" é mecânica GENIAL — punição por imprecisão é imediata e visível
- Corrida pelos diamantes: ambos viram a base pra tentar acertar primeiro = momentos épicos
- Crânios são aterrorizantes: atiram em AMBOS, então erro de um afeta os dois
- Modo Crossfire transforma o jogo em guerra total (lasers cruzando a tela toda)
- O controle de laser por duração (segurar) adiciona skill layer inesperada
- Waves progressivas mantêm a dificuldade crescendo naturalmente
- Visual de "demônio virando diamante" é satisfatório; "demônio virando crânio" é apavorante
- Cada tiro é uma DECISÃO: vale a pena arriscar atingir a cor errada?
- A dinâmica de lados opostos da tela é visualmente única e espacialmente interessante
- "Eu criei o crânio que te matou" = trashtalk natural no chat
