# Game Discovery: Space War

## Identity

| Field | Value |
|-------|-------|
| **Name** | Space War |
| **Original** | Atari, 1978 (based on Spacewar!, MIT 1962) |
| **Genre** | Action / Space Combat |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_spacewar` |

## Why This Game

Spacewar! is literally the first video game ever made for entertainment (MIT, 1962).
Atari's Space War (1978) brought it to the 2600 and it remains one of the most elegant
2-player action games. Two ships in space with thrust-based movement, wraparound edges,
and optional gravity from a central star. The physics feel incredible — you drift, spin,
and boost in zero-g, making every dogfight feel epic. It's the most "skill expressive"
game on this list because mastering momentum is deeply rewarding.

## Original Mechanics

### Core Loop
1. Two spaceships spawn on opposite sides of the screen
2. Each player rotates their ship and applies thrust
3. Ships drift with momentum (Newton's laws in 2D)
4. Fire missiles to hit the opponent
5. Hit = 1 point (or life lost)
6. Most points/last alive wins

### Ship Movement (Newtonian physics)
- **Rotate**: left/right spins the ship
- **Thrust**: accelerates in the direction the ship faces
- No friction — ships DRIFT indefinitely
- Velocity is additive (thrust adds to current velocity)
- Max speed cap (prevents infinite acceleration)
- Ships wrap around screen edges (appear on opposite side)

### Gravity (optional)
- Central star exerts gravitational pull on both ships
- Ships are pulled toward the center
- Crashing into the star = death
- Creates orbital mechanics — skilled players use gravity slingshots
- The gravity well adds immense strategic depth

### Shooting
- Fire missiles in the direction the ship faces
- Missiles travel in straight line (not affected by gravity in most modes)
- Limited missiles (reload after a few seconds)
- Missiles wrap around screen edges too

### Game Variations
- **Space War**: no central star, pure dogfight
- **Space War + Star**: central gravity star
- **Star Castle variant**: star pulls missiles too (hardest mode)
- **Warp**: hyperspace teleport to random position (emergency escape)

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 3       SPACE WAR       P2: 2           │
│                                              │
│           ·  ·    ·                          │
│      ·         ·       ·    ·               │
│                                  ▸           │
│    ·    ·              ·                     │
│               ✦                              │
│          ·        ·                          │
│  ◂                          ·               │
│       ·     ·    ·      ·                   │
│                    ·          ·              │
│           ·              ·                   │
│                                              │
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘

  ◂ ▸ = ships (pointing in movement direction)
  ✦ = gravity star (optional)
  · = background stars (decorative)
```

### Controls
- **Left / Right arrow** — rotate ship
- **Up arrow** — thrust (accelerate forward)
- **Space** — fire missile
- **Down arrow** — hyperspace warp (random teleport, risky)
- **WASD** — alternative (A/D rotate, W thrust, Shift fire)

### Game Modes (selectable in lobby)
1. **Open Space**: no gravity, pure dogfight
2. **Star Field**: central gravity star, orbital combat
3. **Asteroid Belt**: floating obstacles that block missiles and kill on contact

### Game State (synced via DataChannel)
- Ship 1: position (x, y), velocity (vx, vy), rotation, thrust-active, alive
- Ship 2: position (x, y), velocity (vx, vy), rotation, thrust-active, alive
- Missiles: array of {x, y, vx, vy, owner, active}
- Star position (fixed center) + gravity constant
- Scores + round state

### Authority Model
- **Host** runs physics simulation (gravity, collisions, wraparound)
- Each player sends: rotation input, thrust on/off, fire event, warp event
- Host simulates everything at fixed timestep
- Host broadcasts full state at 20-30Hz
- Guest applies state with interpolation
- Client-side prediction for own ship (reconcile with host state)

### Physics System
- **Thrust**: adds acceleration vector in ship's facing direction
- **Gravity** (if star active): F = G * m / r² toward star center
- **Velocity**: updated each tick by thrust + gravity
- **Position**: updated by velocity each tick
- **Wraparound**: position modulo screen dimensions
- **Drag**: very slight drag coefficient (prevents infinite speed realistically)
- **Collision**: circle-based hitboxes for ships, point-based for missiles

### Hyperspace Warp
- Emergency escape: teleport to random position
- Ship is invulnerable for 0.5s after warp
- 20% chance of exploding on re-entry (risk/reward)
- 3-second cooldown between warps
- Visual: ship fades out → flash → appears elsewhere

### Visual Style (Retro CRT)
- Deep black background with scattered decorative stars
- Ships: small vector-style triangles (like Asteroids)
- Player 1: green ship with green thrust flame
- Player 2: cyan ship with cyan thrust flame
- Thrust flame: flickering particles behind ship
- Missiles: small bright dots with fading trail
- Gravity star: pulsing white/yellow point with glow
- Explosions: expanding ring of particles
- Hyperspace: screen flash + static noise effect
- Star field slowly scrolls (parallax for depth feel)

### Scoring
- Hit opponent = 1 point
- Crashing into star = -1 point (self)
- First to 7 points wins
- After death: respawn at random position (opposite half from opponent)
- 2-second invulnerability after respawn

### Sound Effects
- Thrust: white noise whoosh (louder with more thrust)
- Rotate: subtle click
- Fire: laser pew sound
- Missile hit: explosion
- Star proximity: ominous deep hum (louder when closer)
- Hyperspace: warble/teleport sound
- Death: extended explosion
- Ambient: quiet space drone

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | High | Newtonian mechanics, gravity, wraparound |
| Networking | High | Continuous physics state, client prediction needed |
| Rendering | Medium | Vector-style ships, particles, star glow |
| Input | Medium | Rotation + thrust + fire + warp (4 inputs) |
| Game logic | Medium | Gravity modes, hyperspace risk, scoring |
| **Overall** | **High** | Most complex game — save for later |

## Fun Factor

- Mastering momentum is deeply satisfying — you feel like a pilot
- Gravity slingshots around the star are pure joy
- Drifting while rotating to fire backwards = peak skill expression
- Hyperspace warp creates amazing clutch moments ("warp or die!")
- The star creates natural map zones — safe orbits vs danger zones
- Physics-based combat feels endlessly creative (no two fights are the same)
- "I meant to do that" moments when gravity assists your missile
