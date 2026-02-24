# Game Discovery: Warlords

## Identity

| Field | Value |
|-------|-------|
| **Name** | Warlords |
| **Original** | Atari, 1980 (arcade) / 1981 (2600) |
| **Genre** | Action / Breakout variant |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_warlords` |

## Why This Game

Warlords takes the Breakout formula and turns it into a versus battle — each player
defends a castle made of bricks while trying to smash the opponent's castle with a
fireball. It combines the satisfying brick-breaking of Breakout with the reflexes of Pong
and adds a layer of strategic defense. The original supported 4 players, but our 2-player
adaptation makes it even more focused and intense. It's unique because you're simultaneously
playing offense AND defense.

## Original Mechanics

### Core Loop
1. Each player has a castle (wall of bricks) in their corner with a "king" behind it
2. A fireball bounces around the screen
3. Players control a shield (paddle) that deflects the fireball
4. Fireball destroys bricks on contact
5. If the fireball reaches and hits a player's king, that player is eliminated
6. Last king standing wins

### Shield/Paddle
- Rotates around the player's castle corner (arc movement)
- Can catch and hold the fireball (original arcade feature)
- Releasing a caught fireball lets you aim your shot
- Shield deflects fireball on contact (angle based on hit position)

### Fireball
- Bounces off walls and shields
- Destroys one brick per contact
- Speed increases gradually
- Additional fireballs can appear when a king is destroyed

### Castle
- Each castle is a wall of bricks arranged in an L-shape or quarter-circle
- Bricks are destroyed one at a time
- Once a gap opens, the king becomes vulnerable
- Bricks do NOT regenerate

## Our Adaptation (2-Player WebRTC)

### Screen Layout (adapted for 2 players — left vs right)

```
┌──────────────────────────────────────────────┐
│           WARLORDS          Round 2           │
│                                              │
│  ████                              ████      │
│  █  █                              █  █      │
│  █  █                              █  █      │
│  █ ♚█                              █♚ █      │
│  █  █         ◉                    █  █      │
│  █  █                              █  █      │
│  █  █                              █  █      │
│  ████         ═══                  ████      │
│        ═══                                   │
│                                              │
│  Player 1                      Player 2      │
│  Lives: ♥♥♥                    Lives: ♥♥     │
└──────────────────────────────────────────────┘
```

### Castle Layout (2-player variant)
- Player 1: castle on LEFT side (brick wall surrounding king)
- Player 2: castle on RIGHT side (brick wall surrounding king)
- Each castle is a rectangular fortress of bricks with the king inside
- Shield moves vertically along the OUTSIDE of the castle

### Controls
- **Up / Down arrow keys** — move shield vertically
- **Space** — catch/release fireball (hold to catch, release to throw)
- **W / S** — alternative movement

### Game State (synced via DataChannel)
- Fireball position (x, y) and velocity (vx, vy)
- Shield 1 position (y)
- Shield 2 position (y)
- Brick grid state (alive/destroyed per brick)
- King states (alive/dead)
- Catch state (which player holds the fireball, if any)
- Round scores / lives

### Authority Model
- **Host** is authoritative for fireball physics, brick destruction, king hits
- Each player sends shield position + catch/release events
- Host broadcasts full state each frame
- Guest renders from received state with interpolation

### Brick System
- Each castle has ~20-24 bricks arranged in a rectangle
- Fireball destroys one brick on contact
- Destroyed bricks leave gaps the fireball can pass through
- Bricks are color-coded by distance from king (outer = green, inner = yellow, king = red)

### Visual Style (Retro CRT)
- Dark background
- Castles: colored bricks (green outer wall, yellow inner, red king)
- Player 1 elements: green tones
- Player 2 elements: cyan tones
- Fireball: bright white with orange trail
- Shield: bright bar matching player color
- Brick destruction: pixel explosion particles
- King hit: larger explosion effect

### Scoring
- Best of 3 lives (each king hit = lose 1 life)
- Castle rebuilds between lives
- First to eliminate all opponent lives wins
- Brief pause after each king hit

### Catch Mechanic (key strategic element)
- When fireball touches your shield while holding Space, you CATCH it
- While caught, fireball orbits your shield position
- Releasing Space LAUNCHES the fireball in the direction your shield faces
- Catching costs nothing but requires timing
- This is what elevates the game from reactive to strategic

### Sound Effects
- Brick hit: crispy breaking sound
- Shield deflect: metallic ping
- King hit: explosion
- Catch: energy charge sound
- Release: whoosh
- Win: triumphant fanfare

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Medium | Ball physics + brick collision grid |
| Networking | Medium | Brick state sync, catch/release events |
| Rendering | Medium | Brick grid, particles, multiple elements |
| Input | Low | Vertical movement + 1 action button |
| Game logic | Medium | Brick destruction, catch mechanic, life system |
| **Overall** | **Medium** | Good second or third game to implement |

## Fun Factor

- Dual attack/defense creates constant tension
- Catch-and-aim mechanic adds satisfying skill ceiling
- Watching bricks crumble is inherently satisfying (Breakout DNA)
- Each round gets more intense as castles deteriorate
- Strategic depth: do you aim for a gap or create a new one?
- The "oh no my wall has a hole" panic is real
