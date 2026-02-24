# Game Discovery: Surround (Tron Light Cycles)

## Identity

| Field | Value |
|-------|-------|
| **Name** | Surround (a.k.a. Tron Light Cycles / Snake Battle) |
| **Original** | Atari, 1977 (arcade: Blockade by Gremlin, 1976) |
| **Genre** | Action / Strategy |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_surround` |

## Why This Game

Surround is the original "light cycles" game — two players leave trails behind them as
they move, and the first to crash into any trail (theirs or the opponent's) loses. It's
one of the most tense real-time action games ever designed. Every move matters, the arena
shrinks with each second, and the psychological game of cornering your opponent is
incredibly satisfying. Later popularized by Tron (1982), this mechanic is timeless.

## Original Mechanics

### Core Loop
1. Both players start on opposite sides of the arena
2. Each player is a dot that moves continuously in one direction
3. As the dot moves, it leaves a permanent wall/trail behind
4. Players can change direction (4 directions: up, down, left, right)
5. If a player hits ANY wall (trail, border, or opponent), they lose
6. Last player alive wins the round

### Movement
- Players are always moving — you cannot stop
- Direction changes take effect immediately
- You CANNOT reverse direction (instant 180° is death)
- Speed is constant (same for both players)

### Arena
- Fixed rectangular grid
- Bordered walls on all sides
- No obstacles initially — trails ARE the obstacles

### Game Variations (original Atari)
- **Speed-up**: movement gets faster over time
- **Diagonal**: allow 8-direction movement
- **Wrap-around**: screen edges connect to opposite side
- **Erase**: trails disappear after a delay

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  Round 3        SURROUND         P1: 2  P2: 1│
│┌────────────────────────────────────────────┐│
││                                            ││
││  ████                                      ││
││     █                                      ││
││     █                                      ││
││     █►                                     ││
││                                            ││
││                            ◄█              ││
││                             █              ││
││                             █              ││
││                             ████████       ││
││                                            ││
│└────────────────────────────────────────────┘│
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘
```

### Controls
- **Arrow keys** — change direction (up/down/left/right)
- **WASD** — alternative controls
- Cannot reverse into own trail (180° blocked)

### Game State (synced via DataChannel)
- Grid cells (occupied by: empty, player1-trail, player2-trail, player1-head, player2-head)
- Player 1 position + direction
- Player 2 position + direction
- Round scores
- Game phase: `countdown` → `playing` → `round_over` → `match_over`

### Authority Model
- **Tick-based simulation** on host (e.g., 10 ticks/second)
- Each player sends direction changes immediately
- Host advances both players simultaneously each tick
- Host detects collisions and announces results
- Guest receives authoritative state each tick

### Grid System
- Arena divided into discrete cells (e.g., 60x40 grid)
- Each cell is either empty or occupied
- Players move one cell per tick
- Collision = moving into an occupied cell or border

### Visual Style (Retro CRT)
- Dark background with subtle grid lines
- Player 1: bright green trail with glowing head
- Player 2: bright cyan trail with glowing head
- Collision explosion effect (pixel burst)
- Trail has slight glow/bloom effect
- Direction indicator on player head (arrow or triangle)

### Scoring
- Best of 5 rounds (first to 3 wins)
- Mutual collision = draw (both lose the round, no points)
- 3-second countdown between rounds
- Players swap starting positions each round

### Sound Effects
- Movement: subtle continuous tone (pitch changes with direction)
- Collision: crash/explosion sound
- Round win: victory jingle
- Countdown: tick sounds (3... 2... 1... GO!)

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Very Low | Grid movement, no continuous physics |
| Networking | Low | Direction changes only, tick-based sync |
| Rendering | Low | Grid cells, no sprites needed |
| Input | Low | 4 directional keys |
| Game logic | Low | Collision = death, simple grid check |
| **Overall** | **Low** | Excellent candidate for early implementation |

## Fun Factor

- Extreme tension — arena gets smaller every second
- Mind games — feint one direction, cut the other way
- Games are very fast (30-60 seconds per round)
- "Just one more round" addictiveness
- Moment of inevitable doom when you realize you're trapped is delicious
- Skill expression through spatial awareness and prediction
