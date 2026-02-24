# Game Discovery: Pong

## Identity

| Field | Value |
|-------|-------|
| **Name** | Pong |
| **Original** | Atari, 1972 |
| **Genre** | Sports / Action |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_pong` |

## Why This Game

Pong is *the* game that started the video game industry. It's the most recognizable game
in history — two paddles, one ball, pure skill. Everyone knows what Pong is, everyone can
play it in 5 seconds, and it never gets old. It's the perfect first game for our platform:
zero learning curve, infinite replayability, and immediate competitive tension.

## Original Mechanics

### Core Loop
1. Ball spawns at center, launched toward a random player
2. Each player controls a vertical paddle on their side of the screen
3. Ball bounces off top/bottom walls and off paddles
4. If ball passes a paddle, the opposing player scores a point
5. First to 11 points wins

### Ball Physics
- Ball speed increases slightly with each paddle hit
- Ball angle changes based on where it hits the paddle:
  - Center hit → shallow angle (nearly horizontal)
  - Edge hit → steep angle (nearly vertical)
- Ball always moves at a constant speed (magnitude), only direction changes

### Paddle
- Moves vertically only (up/down)
- Fixed horizontal position (left side or right side)
- Has a fixed height (~1/6 of the screen)
- Movement speed is capped

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  3          PONG           7                 │
│                                              │
│  ║                              ║            │
│  ║                              ║            │
│  ║            ●                 ║            │
│  ║                              ║            │
│  ║                              ║            │
│                                              │
│──────────────────────────────────────────────│
│  Player 1 (Host)     Player 2 (Guest)        │
└──────────────────────────────────────────────┘
```

### Controls
- **Up / Down arrow keys** — move paddle
- **W / S keys** — alternative controls

### Game State (synced via DataChannel)
- Ball position (x, y) and velocity (vx, vy)
- Paddle 1 position (y)
- Paddle 2 position (y)
- Score (player1, player2)
- Game phase: `waiting` → `playing` → `scored` → `playing` → `finished`

### Authority Model
- **Host** is authoritative for ball physics and scoring
- Each player sends their paddle position to the other
- Host runs physics simulation, broadcasts ball state
- Guest interpolates ball position for smooth rendering

### Visual Style (Retro CRT)
- Black background with scanline effect
- Bright green (#00ff00) elements on dark canvas
- Dashed center line
- Blocky score numbers at top (retro bitmap font)
- Ball leaves a brief trail for visual flair
- CRT glow/bloom on ball and paddles

### Scoring
- Side wall miss = 1 point to opponent
- First to 11 wins (must win by 2 after 10-10)
- Brief pause after each score (ball reset to center)
- Victory screen with winner announcement

### Sound Effects (via Web Audio API)
- Paddle hit: short blip (higher pitch)
- Wall bounce: short blip (lower pitch)
- Score: descending tone
- Win: ascending arpeggio

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Low | Simple AABB collision, reflection angles |
| Networking | Low | Small state: 2 positions + ball + score |
| Rendering | Low | Rectangles + circle, no sprites |
| Input | Low | Single axis movement |
| Game logic | Low | Trivial scoring rules |
| **Overall** | **Low** | Perfect first game to implement |

## Fun Factor

- Instant gratification — games are fast (2-3 minutes)
- Skill ceiling is higher than it looks (paddle edge shots, speed management)
- Competitive tension builds naturally as score approaches 11
- "Just one more game" loop is strong
- Everyone has nostalgia for Pong
