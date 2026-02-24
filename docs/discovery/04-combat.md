# Game Discovery: Combat

## Identity

| Field | Value |
|-------|-------|
| **Name** | Combat (Tank mode) |
| **Original** | Atari, 1977 (pack-in title with every Atari 2600) |
| **Genre** | Action / Shooter |
| **Players** | 2 (simultaneous, versus) |
| **Our ID** | `hex_combat` |

## Why This Game

Combat was THE game that shipped with every Atari 2600. It's the quintessential 2-player
Atari experience — two tanks in a maze, each trying to shoot the other. The brilliance is
in the simplicity: move, rotate, shoot. But the maze layouts and ricochet mechanics create
surprising depth. Tank battles have a timeless appeal, and the "rotation + forward movement"
control scheme is uniquely satisfying when you master it.

## Original Mechanics

### Core Loop
1. Two tanks spawn on opposite sides of a maze
2. Each player rotates their tank and drives forward
3. Fire a missile to hit the opponent's tank
4. Hit = 1 point to the shooter
5. Most points when the timer runs out wins (2:16 round)

### Tank Movement
- **Rotate**: left/right turns the tank (like a real tank)
- **Forward**: push up to move in the direction the tank faces
- Tanks CANNOT move backward
- Tanks collide with walls (stop, don't bounce)
- Tanks collide with each other (both stop, bump effect)

### Shooting
- One missile on screen at a time per player
- Missile travels in a straight line from tank's barrel
- Missile disappears after a fixed distance or wall hit
- In some modes: missiles RICOCHET off walls (1-2 bounces)
- In some modes: missiles are GUIDED (curve with tank rotation after firing)

### Game Variations (original had 27!)
Key variations for tank mode:
- **Open field**: no maze, pure aim duels
- **Simple maze**: few walls, medium cover
- **Complex maze**: many walls, tactical navigation
- **Ricochet mode**: missiles bounce off walls (billiards-style)
- **Guided missiles**: missiles curve when you rotate after firing
- **Invisible tanks**: tanks only visible when firing or hitting walls

## Our Adaptation (2-Player WebRTC)

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  P1: 5       COMBAT        P2: 3    1:42     │
│┌────────────────────────────────────────────┐│
││                                            ││
││    ▲    ████████████    ████████           ││
││         █          █    █                  ││
││         █    ██    █    █    ████          ││
││              ██         █       █          ││
││                                 █    ▼    ││
││         ████    █████████████            ││
││              █                            ││
││    ██████    █    ████████████████        ││
││                                            ││
│└────────────────────────────────────────────┘│
│  Player 1 (green)         Player 2 (cyan)    │
└──────────────────────────────────────────────┘
```

### Controls
- **Left / Right arrow** — rotate tank
- **Up arrow** — move forward
- **Space** — fire missile
- **WASD** — alternative (A/D rotate, W forward, Shift fire)

### Game Modes (selectable in lobby)
1. **Classic**: open field, straight missiles
2. **Maze Battle**: maze layout, straight missiles
3. **Ricochet**: maze layout, missiles bounce off walls (1 bounce)
4. **Guided Missiles**: open field, missiles curve with your rotation

### Game State (synced via DataChannel)
- Tank 1: position (x, y), rotation angle, alive flag
- Tank 2: position (x, y), rotation angle, alive flag
- Missile 1: position (x, y), velocity (vx, vy), active flag
- Missile 2: position (x, y), velocity (vx, vy), active flag
- Maze layout (static, shared at game start)
- Scores + timer

### Authority Model
- **Host** is authoritative for collision detection (missile hits, wall collisions)
- Each player sends: rotation input, forward input, fire event
- Host simulates both tanks and both missiles
- Host broadcasts positions + scores each frame
- Guest renders from received state with dead reckoning

### Tank Physics
- Rotation: discrete rotation speed (e.g., 180°/sec)
- Movement: constant speed when holding forward, no inertia
- Wall collision: stop at wall edge, can rotate out
- Tank hitbox: small rectangle/circle centered on tank

### Missile System
- Fires from barrel tip in tank's facing direction
- Travels at 2-3x tank speed
- Max range: ~60% of screen width (disappears after)
- Cooldown: 0.5s after missile expires/hits before firing again
- **Ricochet mode**: missile bounces once off walls
- **Guided mode**: missile curves based on player rotation AFTER firing

### Maze Generation
- Pre-designed maze layouts (4-6 layouts, randomly selected)
- Symmetrical (fair for both players)
- Walls are thick blocks on a grid
- Spawn points are on opposite sides

### Visual Style (Retro CRT)
- Dark background with subtle grid
- Tanks: small retro sprites (top-down view, triangular)
- Player 1: green tank
- Player 2: cyan tank
- Missiles: bright yellow/white dots with trail
- Walls: dark gray/brown blocks
- Hit effect: explosion particles + flash
- Ricochet: spark effect on wall bounce

### Scoring
- Hit opponent = 1 point
- Timer: 2-minute rounds
- Most points when timer expires wins
- After hit: brief invincibility + respawn at starting position
- Best of 3 rounds for match

### Sound Effects
- Engine: subtle hum while moving
- Rotate: mechanical click
- Fire: cannon shot
- Missile travel: faint whistle
- Hit: explosion
- Ricochet: metallic ping
- Timer warning: ticking at 15 seconds

## Complexity Assessment

| Aspect | Difficulty | Notes |
|--------|-----------|-------|
| Physics | Medium | Rotation-based movement, missile trajectories |
| Networking | Medium | 2 tanks + 2 missiles, frequent updates |
| Rendering | Medium | Tank sprites with rotation, maze, particles |
| Input | Medium | Rotation + forward + fire (3 simultaneous inputs) |
| Game logic | Medium | Multiple game modes, respawn, timer |
| **Overall** | **Medium** | Good complexity — engaging to implement |

## Fun Factor

- Tank rotation creates a skill gap — good players maneuver elegantly
- Maze battles feel like cat-and-mouse hunting
- Ricochet shots are incredibly satisfying (billiards with missiles!)
- Guided missiles create hilarious moments (curves chasing opponents)
- The "one missile at a time" rule creates tension — miss and you're vulnerable
- Short rounds keep energy high
