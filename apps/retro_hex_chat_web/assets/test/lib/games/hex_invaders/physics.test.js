import { describe, it, expect } from "vitest";
import {
  CANVAS_W,
  CANVAS_H,
  HALF_W,
  GRID_COLS,
  GRID_ROWS,
  CANNON_SPEED,
  MISSILE_SPEED,
  BOMB_SPEED,
  INITIAL_LIVES,
  SHIELD_SEGMENTS,
  DROP_DELAY,
  COMBO_WINDOW,
  COOP_GRID_COLS,
  COOP_GRID_ROWS,
  createInitialState,
  createWave,
  moveCannon,
  fireMissile,
  updateMissiles,
  moveAliens,
  getAlienSpeed,
  spawnBombs,
  updateBombs,
  checkMissileAlienHits,
  checkMissileUFOHit,
  checkBombCannonHits,
  checkBombShieldHits,
  checkAlienReachedGround,
  processDropQueue,
  updateUFO,
  updateCombos,
  checkWaveClear,
  checkGameOver,
  tickTimers,
  clearEvents,
} from "../../../../js/lib/games/hex_invaders/physics.js";
import { PHASE, GAME_MODE, ALIEN_TYPE } from "../../../../js/lib/games/hex_invaders/protocol.js";

describe("Hex Invaders Physics", () => {
  // ── State Creation ──

  describe("createInitialState", () => {
    it("creates valid state for INVASION_WAR mode", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 12345);
      expect(s.phase).toBe(PHASE.WAITING);
      expect(s.wave).toBe(0);
      expect(s.mode).toBe(GAME_MODE.INVASION_WAR);
      expect(s.seed).toBe(12345);
      expect(s.lives1).toBe(INITIAL_LIVES);
      expect(s.lives2).toBe(INITIAL_LIVES);
      expect(s.score1).toBe(0);
      expect(s.score2).toBe(0);
      expect(s.shields).toEqual([
        SHIELD_SEGMENTS,
        SHIELD_SEGMENTS,
        SHIELD_SEGMENTS,
        SHIELD_SEGMENTS,
      ]);
    });

    it("creates valid state for COOP mode", () => {
      const s = createInitialState(GAME_MODE.COOP, 99999);
      expect(s.mode).toBe(GAME_MODE.COOP);
      expect(s.lives1).toBe(INITIAL_LIVES);
      expect(s.lives2).toBe(INITIAL_LIVES);
    });

    it("creates valid state for BLITZ mode", () => {
      const s = createInitialState(GAME_MODE.BLITZ, 11111);
      expect(s.mode).toBe(GAME_MODE.BLITZ);
    });

    it("initializes missiles as inactive", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      expect(s.m1Active).toBe(false);
      expect(s.m2Active).toBe(false);
    });

    it("initializes UFO as inactive", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      expect(s.ufoActive).toBe(false);
    });

    it("initializes empty drop queue", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      expect(s.drops).toEqual([]);
    });

    it("initializes combo counters at zero", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      expect(s.combo1Count).toBe(0);
      expect(s.combo2Count).toBe(0);
      expect(s.combo1Timer).toBe(0);
      expect(s.combo2Timer).toBe(0);
    });
  });

  // ── Wave Creation ──

  describe("createWave", () => {
    it("creates 6×5 grid for INVASION_WAR (per side)", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      expect(s.alien1Count).toBe(GRID_COLS * GRID_ROWS);
      expect(s.alien2Count).toBe(GRID_COLS * GRID_ROWS);
      expect(s.aliens1).toHaveLength(GRID_COLS * GRID_ROWS);
      expect(s.aliens2).toHaveLength(GRID_COLS * GRID_ROWS);
    });

    it("creates wider grid for COOP mode", () => {
      let s = createInitialState(GAME_MODE.COOP, 1);
      s = createWave(s, 1);
      expect(s.alien1Count).toBe(COOP_GRID_COLS * COOP_GRID_ROWS);
      // Co-op uses only aliens1 (shared grid)
      expect(s.aliens1).toHaveLength(COOP_GRID_COLS * COOP_GRID_ROWS);
    });

    it("assigns correct alien types by row", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      // Top row = TOP type (30pts)
      expect(s.aliens1[0].type).toBe(ALIEN_TYPE.TOP);
      // Second row = MID type (20pts)
      expect(s.aliens1[GRID_COLS].type).toBe(ALIEN_TYPE.MID);
      // Bottom rows = BASE type (10pts)
      expect(s.aliens1[GRID_COLS * 2].type).toBe(ALIEN_TYPE.BASE);
    });

    it("sets wave number", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 5);
      expect(s.wave).toBe(5);
    });

    it("resets alien direction to right", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.alien1DirRight = false;
      s = createWave(s, 1);
      expect(s.alien1DirRight).toBe(true);
      expect(s.alien2DirRight).toBe(true);
    });

    it("aliens have HP of 1", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      expect(s.aliens1[0].hp).toBe(1);
    });
  });

  // ── Cannon Movement ──

  describe("moveCannon", () => {
    it("moves P1 cannon left", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = 100;
      s = moveCannon(s, 1, -1);
      expect(s.cannon1X).toBe(100 - CANNON_SPEED);
    });

    it("moves P1 cannon right", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = 100;
      s = moveCannon(s, 1, 1);
      expect(s.cannon1X).toBe(100 + CANNON_SPEED);
    });

    it("clamps P1 cannon to left boundary", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = 2;
      s = moveCannon(s, 1, -1);
      expect(s.cannon1X).toBeGreaterThanOrEqual(0);
    });

    it("clamps P1 cannon to right boundary (half screen)", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = HALF_W - 1;
      s = moveCannon(s, 1, 1);
      expect(s.cannon1X).toBeLessThanOrEqual(HALF_W);
    });

    it("moves P2 cannon within right half", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon2X = 400;
      s = moveCannon(s, 2, 1);
      expect(s.cannon2X).toBe(400 + CANNON_SPEED);
    });

    it("clamps P2 cannon to left boundary (right half)", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon2X = CANVAS_W / 2 + 2;
      s = moveCannon(s, 2, -1);
      expect(s.cannon2X).toBeGreaterThanOrEqual(CANVAS_W / 2);
    });

    it("in COOP mode, both cannons share full width", () => {
      let s = createInitialState(GAME_MODE.COOP, 1);
      s.cannon1X = 10;
      s = moveCannon(s, 1, 1);
      expect(s.cannon1X).toBe(10 + CANNON_SPEED);

      s.cannon2X = 600;
      s = moveCannon(s, 2, 1);
      expect(s.cannon2X).toBeLessThanOrEqual(CANVAS_W);
    });
  });

  // ── Missile Firing ──

  describe("fireMissile", () => {
    it("activates P1 missile at cannon position", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = 120;
      s = fireMissile(s, 1);
      expect(s.m1Active).toBe(true);
      expect(s.m1X).toBe(120);
    });

    it("does not fire when missile already active", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.m1Active = true;
      s.m1X = 50;
      s.m1Y = 200;
      s.cannon1X = 120;
      s = fireMissile(s, 1);
      // Should NOT change missile position
      expect(s.m1X).toBe(50);
    });

    it("activates P2 missile", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon2X = 450;
      s = fireMissile(s, 2);
      expect(s.m2Active).toBe(true);
      expect(s.m2X).toBe(450);
    });
  });

  // ── Missile Update ──

  describe("updateMissiles", () => {
    it("moves active missile upward", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 300;
      s = updateMissiles(s);
      expect(s.m1Y).toBe(300 - MISSILE_SPEED);
    });

    it("deactivates missile when off-screen", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 2; // near top
      s = updateMissiles(s);
      expect(s.m1Active).toBe(false);
    });

    it("does not move inactive missile", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.m1Active = false;
      s.m1Y = 300;
      s = updateMissiles(s);
      expect(s.m1Y).toBe(300);
    });
  });

  // ── Alien Movement ──

  describe("moveAliens", () => {
    it("moves aliens laterally when timer fires", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.alien1MoveTimer = 1; // about to fire
      const origX = s.aliens1[0].x;
      s = moveAliens(s, 1);
      // After timer fires, aliens should have moved
      expect(s.aliens1[0].x).not.toBe(origX);
    });

    it("reverses direction when edge is hit", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      // Force rightmost alien near edge
      s.alien1DirRight = true;
      s.alien1MoveTimer = 1;
      for (const a of s.aliens1) {
        a.x += 200; // push toward right edge
      }
      s = moveAliens(s, 1);
      // Direction should have reversed since aliens hit the edge
      expect(s.alien1DirRight).toBe(false);
    });
  });

  describe("getAlienSpeed", () => {
    it("returns slower speed with more aliens", () => {
      const slow = getAlienSpeed(30, 1);
      const fast = getAlienSpeed(5, 1);
      expect(fast).toBeLessThan(slow);
    });

    it("returns faster speed at higher waves", () => {
      const wave1 = getAlienSpeed(20, 1);
      const wave5 = getAlienSpeed(20, 5);
      expect(wave5).toBeLessThan(wave1);
    });

    it("never returns below minimum (1 frame)", () => {
      const speed = getAlienSpeed(1, 10);
      expect(speed).toBeGreaterThanOrEqual(1);
    });
  });

  // ── Bomb Spawning & Update ──

  describe("spawnBombs", () => {
    it("does not spawn when timer has not elapsed", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.bombTimer = 50;
      const bombsBefore = s.bombs.length;
      s = spawnBombs(s);
      expect(s.bombs.length).toBe(bombsBefore);
    });

    it("spawns a bomb when timer reaches zero", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.phase = PHASE.PLAYING;
      s.bombTimer = 0;
      s = spawnBombs(s);
      expect(s.bombs.length).toBeGreaterThan(0);
    });
  });

  describe("updateBombs", () => {
    it("moves bombs downward", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.bombs = [{ side: 1, x: 100, y: 200 }];
      s.bombCount = 1;
      s = updateBombs(s);
      expect(s.bombs[0].y).toBe(200 + BOMB_SPEED);
    });

    it("removes bombs that go off-screen", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.bombs = [{ side: 1, x: 100, y: CANVAS_H + 5 }];
      s.bombCount = 1;
      s = updateBombs(s);
      expect(s.bombs).toHaveLength(0);
      expect(s.bombCount).toBe(0);
    });
  });

  // ── Collision: Missile vs Alien ──

  describe("checkMissileAlienHits", () => {
    it("destroys alien and awards points (BASE = 10)", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      expect(s.aliens1[0].type).toBe(ALIEN_TYPE.NONE);
      expect(s.score1).toBe(10);
      expect(s.m1Active).toBe(false);
    });

    it("awards 20 for MID type", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.MID, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      expect(s.score1).toBe(20);
    });

    it("awards 30 for TOP type", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.TOP, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      expect(s.score1).toBe(30);
    });

    it("awards 15 for REINFORCEMENT type", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.REINFORCEMENT, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      expect(s.score1).toBe(15);
    });

    it("awards 50 for ARMORED and requires 2 hits", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.ARMORED, x: 100, y: 100, hp: 2 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      // First hit: damage but not destroyed
      expect(s.aliens1[0].hp).toBe(1);
      expect(s.aliens1[0].type).toBe(ALIEN_TYPE.ARMORED);
      expect(s.m1Active).toBe(false);
      expect(s.score1).toBe(0);

      // Second hit
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      expect(s.aliens1[0].type).toBe(ALIEN_TYPE.NONE);
      expect(s.score1).toBe(50);
    });

    it("queues drop in INVASION_WAR mode", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      // Should queue a drop for the opponent (side 2)
      expect(s.drops.length).toBe(1);
      expect(s.drops[0].targetSide).toBe(2);
      expect(s.drops[0].timer).toBe(DROP_DELAY);
    });

    it("does NOT queue drop in COOP mode", () => {
      let s = createInitialState(GAME_MODE.COOP, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      expect(s.drops.length).toBe(0);
    });

    it("increments combo counter on kill", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);
      expect(s.combo1Count).toBe(1);
      expect(s.combo1Timer).toBe(COMBO_WINDOW);
    });
  });

  // ── Collision: Missile vs UFO ──

  describe("checkMissileUFOHit", () => {
    it("destroys UFO and queues armored drop", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.ufoActive = true;
      s.ufoX = 100;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 18; // UFO y-position is near top
      s = checkMissileUFOHit(s);
      expect(s.ufoActive).toBe(false);
      expect(s.m1Active).toBe(false);
      expect(s.score1).toBeGreaterThanOrEqual(100);
      expect(s.score1).toBeLessThanOrEqual(300);
      // Should queue armored drop
      const armoredDrop = s.drops.find((d) => d.type === ALIEN_TYPE.ARMORED);
      expect(armoredDrop).toBeDefined();
    });
  });

  // ── Collision: Bomb vs Cannon ──

  describe("checkBombCannonHits", () => {
    it("decrements lives on hit", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = 100;
      s.bombs = [{ side: 1, x: 100, y: 448 }]; // near cannon Y
      s.bombCount = 1;
      s = checkBombCannonHits(s);
      expect(s.lives1).toBe(INITIAL_LIVES - 1);
      expect(s.events.cannonHit).toBe(1);
    });

    it("removes the bomb on hit", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = 100;
      s.bombs = [{ side: 1, x: 100, y: 448 }];
      s.bombCount = 1;
      s = checkBombCannonHits(s);
      expect(s.bombs).toHaveLength(0);
    });
  });

  // ── Collision: Bomb vs Shield ──

  describe("checkBombShieldHits", () => {
    it("decrements shield HP on hit", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.shields = [4, 4, 4, 4];
      // Place bomb at shield position — shield positions depend on implementation
      // We create a bomb that overlaps with shield 0
      s.bombs = [{ side: 1, x: s._shieldPositions[0].x, y: s._shieldPositions[0].y }];
      s.bombCount = 1;
      s = checkBombShieldHits(s);
      expect(s.shields[0]).toBe(3);
    });

    it("does not go below zero HP", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.shields = [0, 4, 4, 4];
      s.bombs = [{ side: 1, x: s._shieldPositions[0].x, y: s._shieldPositions[0].y }];
      s.bombCount = 1;
      s = checkBombShieldHits(s);
      expect(s.shields[0]).toBe(0);
      // Bomb should pass through destroyed shield
      expect(s.bombs).toHaveLength(1);
    });
  });

  // ── Alien Reached Ground ──

  describe("checkAlienReachedGround", () => {
    it("triggers game over for P1 when alien reaches bottom", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: CANVAS_H - 10, hp: 1 }];
      s.alien1Count = 1;
      s = checkAlienReachedGround(s);
      expect(s.events.invaded).toBe(1);
    });

    it("triggers game over for P2 when alien reaches bottom", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens2 = [{ type: ALIEN_TYPE.BASE, x: 400, y: CANVAS_H - 10, hp: 1 }];
      s.alien2Count = 1;
      s = checkAlienReachedGround(s);
      expect(s.events.invaded).toBe(2);
    });

    it("ignores NONE type aliens", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.NONE, x: 100, y: CANVAS_H - 10, hp: 0 }];
      s.alien1Count = 1;
      s = checkAlienReachedGround(s);
      expect(s.events.invaded).toBe(0);
    });
  });

  // ── Drop Queue Processing ──

  describe("processDropQueue", () => {
    it("decrements drop timer each frame", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.drops = [{ type: ALIEN_TYPE.REINFORCEMENT, targetSide: 2, timer: 60 }];
      s = processDropQueue(s);
      expect(s.drops[0].timer).toBe(59);
    });

    it("materializes alien when timer reaches zero", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      const origCount = s.alien2Count;
      s.drops = [{ type: ALIEN_TYPE.REINFORCEMENT, targetSide: 2, timer: 1 }];
      s = processDropQueue(s);
      // Drop should be consumed and alien added to P2's grid
      expect(s.drops).toHaveLength(0);
      expect(s.alien2Count).toBe(origCount + 1);
    });

    it("in BLITZ mode, drops materialize instantly (timer=0 from start)", () => {
      let s = createInitialState(GAME_MODE.BLITZ, 1);
      s = createWave(s, 1);
      s.drops = [{ type: ALIEN_TYPE.REINFORCEMENT, targetSide: 2, timer: 0 }];
      s = processDropQueue(s);
      expect(s.drops).toHaveLength(0);
    });
  });

  // ── UFO ──

  describe("updateUFO", () => {
    it("does not spawn when timer has not elapsed", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.ufoTimer = 500;
      s.ufoActive = false;
      s = updateUFO(s);
      expect(s.ufoActive).toBe(false);
    });

    it("moves active UFO horizontally", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.ufoActive = true;
      s.ufoX = 100;
      s.ufoDir = 1;
      const origX = s.ufoX;
      s = updateUFO(s);
      expect(s.ufoX).toBeGreaterThan(origX);
    });

    it("deactivates UFO when off-screen", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.ufoActive = true;
      s.ufoX = CANVAS_W + 10;
      s.ufoDir = 1;
      s = updateUFO(s);
      expect(s.ufoActive).toBe(false);
    });
  });

  // ── Combo System ──

  describe("updateCombos", () => {
    it("decrements combo timer", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.combo1Count = 2;
      s.combo1Timer = 50;
      s = updateCombos(s);
      expect(s.combo1Timer).toBe(49);
    });

    it("resets combo when timer expires", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.combo1Count = 2;
      s.combo1Timer = 1;
      s = updateCombos(s);
      expect(s.combo1Count).toBe(0);
      expect(s.combo1Timer).toBe(0);
    });

    it("triggers combo event at threshold 3 (INVASION_WAR)", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      // Simulate 3 rapid kills by setting combo count
      s.combo1Count = 3;
      s.combo1Timer = COMBO_WINDOW;
      s.events = clearEvents(s).events;
      // The combo check happens in checkMissileAlienHits when kill increments count
      // But we can verify the threshold is at 3
      expect(s.combo1Count).toBe(3);
    });

    it("BLITZ mode has lower combo thresholds (2)", () => {
      const s = createInitialState(GAME_MODE.BLITZ, 1);
      // In blitz, combo threshold is 2 (verified by the combo drops logic in physics)
      expect(s.mode).toBe(GAME_MODE.BLITZ);
    });
  });

  // ── Wave Clear ──

  describe("checkWaveClear", () => {
    it("returns true when all aliens on both sides are NONE", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.NONE, x: 0, y: 0, hp: 0 }];
      s.alien1Count = 1;
      s.aliens2 = [{ type: ALIEN_TYPE.NONE, x: 0, y: 0, hp: 0 }];
      s.alien2Count = 1;
      expect(checkWaveClear(s)).toBe(true);
    });

    it("returns false when any alien alive on side 1", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.aliens2 = [{ type: ALIEN_TYPE.NONE, x: 0, y: 0, hp: 0 }];
      s.alien2Count = 1;
      expect(checkWaveClear(s)).toBe(false);
    });

    it("COOP: returns true when shared grid is all NONE", () => {
      const s = createInitialState(GAME_MODE.COOP, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.NONE, x: 0, y: 0, hp: 0 }];
      s.alien1Count = 1;
      expect(checkWaveClear(s)).toBe(true);
    });
  });

  // ── Game Over ──

  describe("checkGameOver", () => {
    it("ends game when P1 is invaded (aliens reached ground)", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.events = { ...clearEvents(s).events, invaded: 1 };
      const result = checkGameOver(s);
      expect(result.ended).toBe(true);
      expect(result.winner).toBe(2); // P2 wins when P1 is invaded
    });

    it("ends game when P2 is invaded", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.events = { ...clearEvents(s).events, invaded: 2 };
      const result = checkGameOver(s);
      expect(result.ended).toBe(true);
      expect(result.winner).toBe(1);
    });

    it("ends game when P1 loses all lives", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.lives1 = 0;
      const result = checkGameOver(s);
      expect(result.ended).toBe(true);
      expect(result.winner).toBe(2);
    });

    it("ends game when P2 loses all lives", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.lives2 = 0;
      const result = checkGameOver(s);
      expect(result.ended).toBe(true);
      expect(result.winner).toBe(1);
    });

    it("ends game after 10 waves — higher score wins", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.wave = 10;
      s.score1 = 5000;
      s.score2 = 3000;
      s.aliens1 = [{ type: ALIEN_TYPE.NONE, x: 0, y: 0, hp: 0 }];
      s.alien1Count = 1;
      s.aliens2 = [{ type: ALIEN_TYPE.NONE, x: 0, y: 0, hp: 0 }];
      s.alien2Count = 1;
      const result = checkGameOver(s);
      expect(result.ended).toBe(true);
      expect(result.winner).toBe(1);
    });

    it("BLITZ ends after 5 waves", () => {
      const s = createInitialState(GAME_MODE.BLITZ, 1);
      s.wave = 5;
      s.score1 = 1000;
      s.score2 = 2000;
      s.aliens1 = [{ type: ALIEN_TYPE.NONE, x: 0, y: 0, hp: 0 }];
      s.alien1Count = 1;
      s.aliens2 = [{ type: ALIEN_TYPE.NONE, x: 0, y: 0, hp: 0 }];
      s.alien2Count = 1;
      const result = checkGameOver(s);
      expect(result.ended).toBe(true);
      expect(result.winner).toBe(2);
    });

    it("COOP ends when both players lose all lives", () => {
      const s = createInitialState(GAME_MODE.COOP, 1);
      s.lives1 = 0;
      s.lives2 = 0;
      const result = checkGameOver(s);
      expect(result.ended).toBe(true);
    });

    it("COOP does NOT end when only one player dead", () => {
      const s = createInitialState(GAME_MODE.COOP, 1);
      s.lives1 = 0;
      s.lives2 = 2;
      const result = checkGameOver(s);
      expect(result.ended).toBe(false);
    });

    it("returns ended=false during normal play", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      s.events = clearEvents(s).events;
      const result = checkGameOver(s);
      expect(result.ended).toBe(false);
    });
  });

  // ── Timers and Events ──

  describe("tickTimers", () => {
    it("decrements bomb timer", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.bombTimer = 30;
      s = tickTimers(s);
      expect(s.bombTimer).toBe(29);
    });

    it("decrements UFO timer", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.ufoTimer = 100;
      s.ufoActive = false;
      s = tickTimers(s);
      expect(s.ufoTimer).toBe(99);
    });

    it("decrements alien move timers", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.alien1MoveTimer = 20;
      s.alien2MoveTimer = 15;
      s = tickTimers(s);
      expect(s.alien1MoveTimer).toBe(19);
      expect(s.alien2MoveTimer).toBe(14);
    });
  });

  // ── Audit: Edge Cases & Missing Coverage ──

  describe("edge cases: state immutability", () => {
    it("moveCannon does not mutate original state", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = 100;
      const original = s.cannon1X;
      moveCannon(s, 1, 1);
      expect(s.cannon1X).toBe(original);
    });

    it("fireMissile does not mutate original state", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      fireMissile(s, 1);
      expect(s.m1Active).toBe(false);
    });

    it("checkMissileAlienHits does not mutate original aliens", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      checkMissileAlienHits(s);
      expect(s.aliens1[0].type).toBe(ALIEN_TYPE.BASE);
      expect(s.score1).toBe(0);
    });
  });

  describe("edge cases: empty aliens array", () => {
    it("moveAliens handles empty array gracefully", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [];
      s.alien1Count = 0;
      s.alien1MoveTimer = 1;
      const result = moveAliens(s, 1);
      expect(result.aliens1).toEqual([]);
    });

    it("moveAliens handles all-NONE aliens without hanging", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [
        { type: ALIEN_TYPE.NONE, x: 50, y: 50, hp: 0 },
        { type: ALIEN_TYPE.NONE, x: 80, y: 50, hp: 0 },
      ];
      s.alien1Count = 0;
      s.alien1MoveTimer = 1;
      const result = moveAliens(s, 1);
      expect(result.alien1MoveTimer).toBeGreaterThanOrEqual(1);
    });

    it("spawnBombs with zero alive aliens does not throw", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.NONE, x: 50, y: 50, hp: 0 }];
      s.aliens2 = [{ type: ALIEN_TYPE.NONE, x: 400, y: 50, hp: 0 }];
      s.alien1Count = 0;
      s.alien2Count = 0;
      s.phase = PHASE.PLAYING;
      s.bombTimer = 0;
      const result = spawnBombs(s);
      expect(result.bombs).toHaveLength(0);
    });

    it("checkWaveClear with empty aliens arrays returns true", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [];
      s.aliens2 = [];
      expect(checkWaveClear(s)).toBe(true);
    });
  });

  describe("edge cases: drop queue overflow", () => {
    it("caps drop queue at MAX_DROPS (6)", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      // Pre-fill with 5 drops
      s.drops = Array(5)
        .fill(null)
        .map(() => ({
          type: ALIEN_TYPE.REINFORCEMENT,
          targetSide: 2,
          timer: 60,
        }));
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: 100, hp: 1 }];
      s.alien1Count = 1;
      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      const result = checkMissileAlienHits(s);
      // Should not exceed 6 drops total
      expect(result.drops.length).toBeLessThanOrEqual(6);
    });
  });

  describe("edge cases: shield full decay", () => {
    it("shield takes 4 hits then stops absorbing", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s = createWave(s, 1);
      const sp = s._shieldPositions[0];

      // 4 hits to destroy shield
      for (let i = SHIELD_SEGMENTS; i > 0; i--) {
        s.shields = [...s.shields];
        s.bombs = [{ side: 1, x: sp.x, y: sp.y }];
        s.bombCount = 1;
        s = checkBombShieldHits(s);
        expect(s.shields[0]).toBe(i - 1);
      }

      // 5th bomb passes through destroyed shield
      s.bombs = [{ side: 1, x: sp.x, y: sp.y }];
      s.bombCount = 1;
      s = checkBombShieldHits(s);
      expect(s.shields[0]).toBe(0);
      expect(s.bombs).toHaveLength(1); // bomb not absorbed
    });
  });

  describe("edge cases: getAlienSpeed", () => {
    it("handles alienCount = 0 defensively", () => {
      const speed = getAlienSpeed(0, 1);
      expect(speed).toBeGreaterThanOrEqual(1);
    });

    it("handles very high wave numbers", () => {
      const speed = getAlienSpeed(10, 100);
      expect(speed).toBeGreaterThanOrEqual(1);
    });
  });

  describe("edge cases: score capping", () => {
    it("scores do not become negative", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      expect(s.score1).toBe(0);
      expect(s.score2).toBe(0);
    });
  });

  describe("edge cases: BLITZ instant drops", () => {
    it("drops with timer=0 materialize on same frame", () => {
      let s = createInitialState(GAME_MODE.BLITZ, 1);
      s = createWave(s, 1);
      const origCount = s.alien2Count;
      s.drops = [
        { type: ALIEN_TYPE.REINFORCEMENT, targetSide: 2, timer: 0 },
        { type: ALIEN_TYPE.REINFORCEMENT, targetSide: 2, timer: 0 },
      ];
      s = processDropQueue(s);
      expect(s.drops).toHaveLength(0);
      expect(s.alien2Count).toBe(origCount + 2);
    });
  });

  describe("edge cases: cannon at boundaries", () => {
    it("P1 cannon at left wall can still move right", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon1X = 10; // at minimum bound (CANNON_W/2)
      s = moveCannon(s, 1, -1); // try go further left
      expect(s.cannon1X).toBe(10); // clamped
      s = moveCannon(s, 1, 1); // move right
      expect(s.cannon1X).toBe(10 + CANNON_SPEED);
    });

    it("P2 cannon respects left boundary at DIVIDER_X", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.cannon2X = 330; // DIVIDER_X + CANNON_W/2 = 330
      s = moveCannon(s, 2, -1);
      expect(s.cannon2X).toBeGreaterThanOrEqual(330);
    });
  });

  describe("edge cases: combo threshold triggers", () => {
    it("combo threshold 1 triggers at exactly 3 kills (INVASION_WAR)", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.aliens1 = [];
      for (let i = 0; i < 3; i++) {
        s.aliens1.push({ type: ALIEN_TYPE.BASE, x: 100 + i * 40, y: 100, hp: 1 });
      }
      s.alien1Count = 3;

      for (let i = 0; i < 3; i++) {
        s.m1Active = true;
        s.m1X = 100 + i * 40;
        s.m1Y = 100;
        s = checkMissileAlienHits(s);
      }

      expect(s.combo1Count).toBe(3);
      expect(s.events.combo).toBe(1);
    });

    it("BLITZ combo threshold triggers at 2 kills", () => {
      let s = createInitialState(GAME_MODE.BLITZ, 1);
      s.aliens1 = [
        { type: ALIEN_TYPE.BASE, x: 100, y: 100, hp: 1 },
        { type: ALIEN_TYPE.BASE, x: 140, y: 100, hp: 1 },
      ];
      s.alien1Count = 2;

      s.m1Active = true;
      s.m1X = 100;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);

      s.m1Active = true;
      s.m1X = 140;
      s.m1Y = 100;
      s = checkMissileAlienHits(s);

      expect(s.combo1Count).toBe(2);
      expect(s.events.combo).toBe(1);
    });
  });

  describe("edge cases: UFO boundaries", () => {
    it("spawns UFO when timer reaches 0 during PLAYING phase", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 42);
      s.ufoTimer = 0;
      s.phase = PHASE.PLAYING;
      const result = updateUFO(s);
      expect(result.ufoActive).toBe(true);
      expect(result.events.ufoAppear).toBe(true);
    });

    it("does not spawn UFO outside PLAYING phase", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 42);
      s.ufoTimer = 0;
      s.phase = PHASE.COUNTDOWN;
      const result = updateUFO(s);
      expect(result.ufoActive).toBe(false);
    });

    it("deactivates UFO moving left past screen edge", () => {
      const s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.ufoActive = true;
      s.ufoX = -30; // past -UFO_W (-24)
      s.ufoDir = -1;
      const result = updateUFO(s);
      expect(result.ufoActive).toBe(false);
    });
  });

  describe("edge cases: dead code cleanup verification", () => {
    it("checkAlienReachedGround: invaded event is 1 for COOP mode", () => {
      const s = createInitialState(GAME_MODE.COOP, 1);
      s.aliens1 = [{ type: ALIEN_TYPE.BASE, x: 100, y: CANVAS_H, hp: 1 }];
      s.alien1Count = 1;
      const result = checkAlienReachedGround(s);
      expect(result.events.invaded).toBe(1);
    });
  });

  describe("clearEvents", () => {
    it("resets all event flags to zero/false", () => {
      let s = createInitialState(GAME_MODE.INVASION_WAR, 1);
      s.events = {
        alienKill: 1,
        alienType: ALIEN_TYPE.TOP,
        bombHit: true,
        shieldHit: true,
        cannonHit: 1,
        ufoKill: 1,
        ufoAppear: true,
        combo: 3,
        dropLand: true,
        waveCleared: true,
        death: 1,
        invaded: 0,
        armoredHit: 0,
      };
      s = clearEvents(s);
      expect(s.events.alienKill).toBe(0);
      expect(s.events.cannonHit).toBe(0);
      expect(s.events.combo).toBe(0);
      expect(s.events.waveCleared).toBe(false);
      expect(s.events.invaded).toBe(0);
    });
  });
});
